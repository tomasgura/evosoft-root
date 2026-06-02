# Integrace — DWH

## Přehled

| Integrace | Typ | Směr | Účel |
|---|---|---|---|
| Zdrojové DB (PostgreSQL, Oracle, MySQL, MSSQL) | JDBC / PDO | Pull | Import dat do DWH |
| RabbitMQ | AMQP | Interní | ETL pipeline (fronty) |
| Kafka | TCP | Push | Streaming výstupu |
| PostgreSQL / Oracle (DWH) | DB | Read/Write | Uložení a materializace dat |
| REST API (inbound) | HTTP | Push z externích systémů | Trigger importu |
| REST API (outbound) | HTTP | Push do externích systémů | Výstup dat |
| SMTP | Email | Push | Notifikace |
| Liquibase / Hyperdrive | CLI | — | DB migrace |

---

## 1. Zdrojové databáze (Data Sources)

**Třída:** `DataSourceService`, `DataSourceManager`  
**Konfigurace:** Tabulka `source_connection` + `data_source`

### Podporované zdroje
- PostgreSQL
- Oracle
- MySQL
- Microsoft SQL Server
- Soubory (CSV, XLSX)
- External API (HTTP GET/POST)

### Jak funguje připojení
1. `source_connection` tabulka obsahuje: driver, host, port, database, username, **šifrované heslo**
2. Hesla jsou šifrována AES (klíče `iv` + `secret` v `config/local.neon`)
3. `DataSourceService` dešifruje heslo za runtime a otevře JDBC/PDO spojení
4. Spustí SQL query z `data_source.sql`
5. Výsledek (raw řádky) pošle do RabbitMQ

---

## 2. RabbitMQ (interní pipeline)

**Protokol:** AMQP 0.9.1  
**Balíček:** `contributte/rabbitmq` + `bunny/bunny`  
**Konfigurace:** `config/rabbitmq.neon`

### Topologie
```
masterQueue             → MasterConsumer
dataSourceQueue         → DataSourceConsumer
dataToValuesQueue       → DataToValuesConsumer
transformationQueue     → TransformationConsumer
enrichmentQueue         → EnrichmentConsumer
validationQueue         → ValidationConsumer         (prefetchCount=1)
dataQualityQueue        → DataQualityConsumer         (prefetchCount=1)
publicationQueue        → PublicationConsumer
systemProcessQueue      → SystemProcessConsumer
jobProcessQueue         → JobProcessConsumer
```

### Message formát
- Zprávy jsou JSON objekty
- Každá obsahuje `job_id`, typ operace, ID entity/datasetu
- Delivery mode: **persistent** (zprávy přežijí restart RabbitMQ)

### Failure handling
- Zprávy se při chybě requeue (vrátí do fronty)
- Po N pokusech → Dead Letter Queue (DLQ)
- Consumery logují chyby přes Tracy + BunnyLog

### Důležité upozornění
- `autoCreate: true` v konfiguraci = RabbitMQ TCP spojení při **každém requestu**
- Výpadek RabbitMQ → 500 error na všech stránkách
- Doporučení: změnit na `autoCreate: false` (viz rizika)

---

## 3. Kafka (streaming výstup)

**Balíček:** `evosoftcz/kafka`  
**Konfigurace:** sekce `publications.dev_kafka` v `config/local.neon`

```yaml
publications:
  dev_kafka:
    brokers: kafka-host
    port: 9092
    group: dwh-group
```

- Publikace se konfiguruje v tabulce `publication` (typ: kafka, topic: ...)
- `PublicationConsumer` při exportu pošle JSON zprávu na definovaný topic
- Downstream systémy konzumují topic a reagují na změny dat

---

## 4. REST API — příjem (inbound)

**Framework:** Contributte Apitte  
**Prefix:** `/api/rest/v1/`  
**Auth:** API token v hlavičce `apiToken`  
**Tokeny:** Tabulka `application`

### Klíčové endpointy pro triggery

```
POST /api/rest/v1/actions/get-data/{dataset_entity_name}
  → Spustí import pro daný dataset (zařadí job do RabbitMQ)

POST /api/rest/v1/publications/{id}/run
  → Spustí publikaci

GET /api/rest/v1/datasets/{id}
  → Vrátí metadata datasetu
```

---

## 5. REST API — výstup (outbound)

- Aplikace může posílat data na externí HTTP endpointy jako typ publikace
- Konfigurace v tabulce `publication` (typ: api, url: ...)
- `PublicationConsumer` spustí HTTP POST s JSON tělem

---

## 6. SMTP (email)

**Balíček:** Nette\Mail  
**Service:** `MailService`  
**Konfigurace:** `config/local.neon` → sekce `mailer`

```yaml
mailer:
  mailFrom: xxx@xxx.cz
  host: smtp.host
  username: user
  password: pass
  secure: ssl
```

- Emaily se odesílají při:
  - Chybě v ETL pipeline (notifikace administrátorovi)
  - Dokončení importu (volitelně)
  - Systémových alertech

---

## 7. Liquibase / Hyperdrive (DB migrace)

**Balíček:** `evosoftcz/hyperdrive`  
**Konfigurace:** `config/common.neon` → sekce `hyperdrive`  
**CLI:** `php bin/console.php hyperdrive:start postgre`

- Hyperdrive je wrapper nad Liquibase (Java)
- Spouští changeset XML soubory v definovaném pořadí
- Tracking změn: tabulka `DATABASECHANGELOG`
- Podporuje PostgreSQL i Oracle přes různé JDBC drivery

---

## 8. Kafka Reader / Test (debug)

- `bin/kafkaReader.php` — debug čtení z Kafka topiku
- `bin/kafkaTest.php` — test publikace do Kafka
- Pouze pro vývojové účely

---

## Bezpečnostní poznámky

| Oblast | Opatření |
|---|---|
| Hesla k zdrojovým DB | Šifrována AES (IV + secret v local.neon) |
| API autentizace | Token v hlavičce, uložen v tabulce `application` |
| RBAC | evosoftcz/rights, role per uživatel |
| 2FA | OTP (spomky-labs/otphp) — volitelně |
| SQL injection | Dibi/EDA parametrizované dotazy |
| RabbitMQ | Dedikované credentials v local.neon (odlišné od dev/prod) |
| Kafka | Žádná autentizace ve výchozím nastavení (interní síť) |
