# Tok dat (ETL pipeline) — DWH

## Přehled: od zdroje k cíli

```
ZDROJOVÁ DB / API / SOUBOR
  ↓ [manuální trigger nebo cron]
Data Source (SQL query definice)
  ↓ RabbitMQ: dataSourceQueue
DataSourceConsumer — spustí query na zdrojové DB
  ↓ RabbitMQ: dataToValuesQueue
DataToValuesConsumer — parsuje výsledek → dataset_values
  ↓ RabbitMQ: transformationQueue
TransformationConsumer — aplikuje transformační pravidla
  ↓ RabbitMQ: enrichmentQueue
EnrichmentConsumer — lookup join (enrich hodnoty z jiných datasetů)
  ↓ RabbitMQ: validationQueue
ValidationConsumer — kontrola formátů, povinnosti, regex
  ↓ RabbitMQ: dataQualityQueue
DataQualityConsumer — detekce anomálií, statistické kontroly
  ↓ RabbitMQ: publicationQueue
PublicationConsumer — export do cíle
  ↓
CÍL (materialized view, Kafka topic, XLSX, API)
```

---

## Detail každého kroku

### 1. Trigger (spuštění)

Import se spouští třemi způsoby:

| Způsob | Kdo | Jak |
|---|---|---|
| Manuálně z UI | Uživatel | Tlačítko „Načíst data" v Admin UI |
| Cron job | Server cron → `app:job-queue` | Dle `cron_expression` v DB |
| REST API | Externe systém | `POST /api/rest/v1/actions/get-data/{dataset_entity_name}` |

---

### 2. Data Source (query na zdrojové DB)

- Definice SQL query uložena v tabulce `data_source`
- Obsahuje: connection ID, SQL query, schedule, priorita, typ (DB / file / API)
- `DataSourceConsumer` připojí se na zdrojovou DB (přes `source_connection`) a spustí query
- Výsledek (raw řádky) se pošle do `dataToValuesQueue`

---

### 3. Import → DatasetValues

- `DataToValuesConsumer` přijme raw data
- Pro každý řádek: namapuje sloupce na `def_id` (dle `DatasetPartDefinition`)
- Vytvoří nebo aktualizuje `dataset_entity` (jeden řádek = jedna entita)
- Uloží hodnoty do `dataset_values`: `(entity_id, def_id)` → `value`
- Stav entity: `new` nebo `updated`

---

### 4. Transformace

- `TransformationConsumer` načte `data_transformation` pravidla pro daný dataset
- Každé pravidlo: `before_value` → `after_value` (mapování, výpočet, podmínka)
- Upravené hodnoty se uloží zpět do `dataset_values`
- Může měnit i stav entity

---

### 5. Obohacení (Enrichment)

- `EnrichmentConsumer` načte `data_enrichment` pravidla
- Lookup join: hodnota z entity X se hledá v jiném datasetu Y → přidá hodnotu z Y
- Příklad: z `tournament_uid` najde `tournament_name` v jiném datasetu
- Nové hodnoty se přidají do `dataset_values` jako nové def_id

---

### 6. Validace

- `ValidationConsumer` načte `data_validation` pravidla (required, regex, format, ...)
- Pro každé pravidlo zkontroluje hodnoty entity
- Pokud selhání: entita dostane stav `invalid`, zaznamenají se chyby
- Pokud vše OK: entita dostane stav `valid`

---

### 7. Data Quality

- `DataQualityConsumer` načte `data_quality_rule` pravidla
- Detekce anomálií: statistické odchylky, duplicity, chybějící data
- Výsledky se zaznamenají (nespoléhá na jeden stav entity, ale generuje reporty)

---

### 8. Publikace (export do cíle)

- `PublicationConsumer` načte `publication` definice pro daný dataset
- Pro každou destinaci spustí export:

| Typ destinace | Co se stane |
|---|---|
| PostgreSQL materialized view | Refresh `export.mv_dataset_export_*` (SELECT → INSERT) |
| Oracle view | Totéž pro Oracle |
| Kafka | Pošle zprávu na Kafka topic (JSON) |
| XLSX soubor | Vygeneruje Excel soubor do `www/send_to_file/` |
| REST API (outbound) | HTTP POST na externí endpoint |

---

## Tok webového requestu (UI)

```
Browser
  → GET /data/dataset/detail/{id}
  → www/index.php (entry point)
  → Bootstrap.php (DI kontejner)
  → Nette Application router
  → DataModule\Presenters\DatasetPresenter::renderDetail($id)
      → DatasetManagerService::getDataset($id)
          → BaseRepository → EDA → PostgreSQL SELECT
      → render('DataModule/templates/Dataset/detail.latte', [...])
          → Latte engine
          → Komponenty (Datagrids, Forms, ...)
  ← HTML response
```

## Tok REST API requestu

```
External systém
  → POST /api/rest/v1/actions/get-data/tournament_match
    Header: apiToken: <token>
  → www/index.php
  → Bootstrap.php → detekuje 'api/rest' v URL
  → Apitte Middlewares:
      ApiKeyAuthenticationMiddleware (ověří token)
      LogApiMiddleware (loguje)
  → ActionController::getDataAction($datasetEntityName)
      → ActionService::triggerImport(...)
          → RabbitMQ: masterQueue → message publish
  ← JsonResponse { status: "queued", job_id: "..." }
```

## Tok CLI commandu (cron)

```
Linux cron: * * * * * php /var/www/evo/bin/console.php app:job-queue
  → JobQueueCommand::execute()
      → Načte z DB: job_definition kde enabled=true AND cron vyšel
      → Pro každý job:
          → RabbitMQ: jobProcessQueue → message publish
  → (asynchronně) JobProcessConsumer zpracuje job
      → MasterConsumer → dataSourceQueue → ... → publicationQueue
```

## Stavy dataset_entity

```
new
  → (import) → valid / invalid
      valid → (transformace) → transformed
          transformed → (enrichment) → enriched
              enriched → (validace) → validated / invalid
                  validated → (publikace) → published
  
  invalid → (oprava) → new (recycle)
  locked → nelze editovat
  archived → historický záznam
```

## Cache strategie

- Nette Cache (file-based nebo vlastní backend)
- Cachuje se: konfigurace datasetů, lookup tabulky
- Invalidace: při změně definice datasetu nebo validačních pravidel
- CLI commands cachují do jiného adresáře (`temp/cli/`)

## Typy HTTP responses (Web)

| Typ | Kdy |
|---|---|
| HTML (Latte) | Všechny UI stránky |
| JsonResponse | AJAX requesty z UI (Naja) |
| FileResponse | Stažení exportních souborů |
| RedirectResponse | Po formulářovém submitu |

## Typy responses (REST API)

| Typ | Kdy |
|---|---|
| `200 OK` + JSON | Úspěšný dotaz |
| `201 Created` | Nově vytvořený záznam |
| `202 Accepted` | Asynchronní job zařazen do fronty |
| `400 Bad Request` | Chybný vstup |
| `401 Unauthorized` | Chybný nebo chybějící API token |
| `404 Not Found` | Záznam nenalezen |
| `500 Internal Error` | Chyba serveru |
