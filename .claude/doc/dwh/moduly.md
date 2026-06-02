# Hlavní moduly — DWH

## Nette moduly (UI)

### DataModule — jádro ETL logiky

Hlavní modul aplikace. Obsahuje veškerou business logiku pro správu datasetů, import dat, transformace, validace a export.

**Presenters:**

| Presenter | URL prefix | Popis |
|---|---|---|
| HomepagePresenter | `/data/` | Dashboard |
| DatasetPresenter | `/data/dataset/` | Správa datasetů a entit |
| ActionPresenter | `/data/action/` | Spouštění ETL akcí |
| ReportingPresenter | `/data/reporting/` | Reporting a grafy |
| ExportPresenter | `/data/export/` | Export dat (XLSX, soubory) |
| QueuesPresenter | `/data/queues/` | Přehled RabbitMQ front |

**Services:**

| Service | Popis |
|---|---|
| DatasetActionService | Orchestrace ETL akcí (spouštění importů, transformací) |
| DatasetDataService | Čtení a manipulace s hodnotami (dataset_values) |
| DatasetHistorizingService | Archivace starých záznamů dataset_entity |
| DatasetManagerService | Lifecycle management entity (create, update, delete, lock) |
| DataSourceService | Spuštění SQL query na zdrojové DB, parsování výsledku |
| PublicationService | Export do cílových systémů (materialized views, Kafka) |
| ValidationService | Validace formátů, povinných polí, regex |
| ValueInfoService | Metadata o hodnotách (typ, stav, zdroj) |

**RabbitMQ Consumers (DataModule):**

| Consumer | Queue | Popis |
|---|---|---|
| MasterConsumer | masterQueue | Orchestrace — spouští celý import job |
| DataSourceConsumer | dataSourceQueue | Spustí SQL query na zdrojové DB |
| DataToValuesConsumer | dataToValuesQueue | Parsuje raw data → dataset_values |
| TransformationConsumer | transformationQueue | Aplikuje transformační pravidla |
| EnrichmentConsumer | enrichmentQueue | Lookup join z jiných datasetů |
| ValidationConsumer | validationQueue | Kontrola dat (prefetchCount=1) |
| DataQualityConsumer | dataQualityQueue | Detekce anomálií (prefetchCount=1) |
| PublicationConsumer | publicationQueue | Export do externích systémů |

---

### AdminModule — konfigurace

UI pro nastavení datasetů, datových zdrojů, pravidel.

**Presenters:**
- `DatasetPresenter` — vytvoření a konfigurace datasetů (sloupce, typy, ...)
- `DataSourcePresenter` — správa připojení na zdrojové DB a SQL queries
- `EnrichmentPresenter` — nastavení lookup enrichmentů
- `ValidationPresenter` — definice validačních pravidel
- `TransformationPresenter` — nastavení transformačních pravidel

**Formuláře (Components/Forms):**
- `DatasetSettingsForm` — nastavení datasetu
- `DataSourceForm` — definice SQL source
- `EnrichmentForm` — lookup mapping
- `ValidationForm` — validační pravidla (required, regex, format)
- `TransformationForm` — transformace hodnot

---

### SuperAdminModule — systémová správa

Systémová konfigurace, správa uživatelů, připojení, globálních nastavení.

**Presenters (7):**
- Uživatelé a role (RBAC)
- Připojení na zdrojové DB (`source_connection`)
- Globální konfigurace aplikace
- API tokeny

---

### REST API (Apitte, `/api/rest/v1/`)

Programmatický přístup k datům a operacím.

**Autentizace:** API token v hlavičce `apiToken`

| Controller | Prefix | Popis |
|---|---|---|
| DatasetController | `/datasets/` | CRUD nad datasety |
| PublicationController | `/publications/` | Spuštění publikace |
| EntityGroupController | `/entity-groups/` | Skupiny entit |
| ActionController | `/actions/` | Spouštění ETL akcí |
| SchemaRegistryController | `/schema-registry/` | Schema informace |
| DocController | `/doc/` | OpenAPI dokumentace |

**Middlewares:**
- `ApiKeyAuthenticationMiddleware` — ověření API tokenu
- `LogApiMiddleware` — logování API volání

---

## CLI Commands

| Command | Popis |
|---|---|
| `app:job-queue` | Zpracování background jobů (spouštět cronem) |
| `app:index-rebuild` | Rebuild DB indexů |
| `app:dataset-entity-historization` | Archivace starých záznamů |
| `app:database-views-rebuild` | Rebuild materializovaných pohledů |
| `app:migrations` | Export datových migrací (WIP) |
| `rabbitmq:staticConsumer <name> <timeout>` | Spuštění jednoho consumera |
| `rabbitmq:declareQueuesAndExchanges` | Inicializace RabbitMQ topologie |
| `hyperdrive:start <database>` | Spuštění Liquibase migrací |
| `hyperdrive:procedure <name>` | Spuštění SQL procedury |

---

## Globální Managery

| Manager | Popis |
|---|---|
| AdminManager | Správa systémových procesů, RabbitMQ monitoring |
| ApiManager | Orchestrace REST API volání |
| ConfigManager | Čtení konfigurace z DB |
| DataSourceManager | Připojení na zdrojové DB, spuštění query |
| EnrichmentManager | Orchestrace enrichment procesu |
| TransformationManager | Orchestrace transformačního procesu |
| ValidationManager | Orchestrace validace |
| ServiceManager | Health check RabbitMQ |

---

## Globální Services

| Service | Popis |
|---|---|
| ExportService | Generování XLSX souborů (evosoftcz/php_xlsxwriter) |
| ImportService | Import dat ze souborů a externích API |
| JobService | Správa background jobů (JobFactory) |
| MailService | Odesílání emailů (Nette\Mail) |
| DatabaseDriverService | Abstrakce přes PostgreSQL/Oracle |
| BunnyLog | Logování RabbitMQ operací |
| GeneratorFactory | Factory pro generátory |

---

## Systémové RabbitMQ Consumers (globální)

| Consumer | Queue | Popis |
|---|---|---|
| SystemProcessConsumer | systemProcessQueue | DB procedury, index rebuildy |
| JobProcessConsumer | jobProcessQueue | Naplánované joby (cron) |

---

## RabbitMQ topologie (9 front)

```
systemProcessQueue      prefetchCount: default
jobProcessQueue         prefetchCount: 5, priority: 10
masterQueue             prefetchCount: 5
dataSourceQueue         prefetchCount: default
dataToValuesQueue       prefetchCount: default
transformationQueue     prefetchCount: default
enrichmentQueue         prefetchCount: default
validationQueue         prefetchCount: 1  (kritické)
dataQualityQueue        prefetchCount: 1  (kritické)
publicationQueue        prefetchCount: default
```

---

## Entity (DataModule)

### Dataset
Definice datové sady. Obsahuje DatasetPart → DatasetPartDefinition → DataType.

### DatasetPart
Fyzická část datasetu (tabulka/struktura). Obsahuje definice sloupců.

### DatasetPartDefinition
Definice jednoho sloupce/pole v DatasetPart. Obsahuje DataType a pravidla.

### DataType (9 typů)
Strategy pattern — každý typ má svou validaci a reprezentaci:

| Typ | Popis |
|---|---|
| String | Textová hodnota |
| Integer | Celé číslo |
| Float | Desetinné číslo |
| Date | Datum |
| DateTime | Datum a čas |
| Time | Čas |
| Bool | Pravda/nepravda |
| Email | Email adresa |
| ArrayInt | Pole celých čísel |

### DatasetEntity
Jeden datový záznam v datasetu (jako řádek v tabulce). Má status, historii.

**Stavy entity:** new, valid, invalid, locked, archived, ...

### DatasetValues
Konkrétní hodnoty entity. Key-value struktura: `(dataset_entity_id, def_id)` → `value`.

### EntityGroup / EntityGroupCategory
Hierarchická organizace entit (skupiny a kategorie skupin).

### LookupItem
Položka lookup tabulky pro enrichment (mapování hodnot).
