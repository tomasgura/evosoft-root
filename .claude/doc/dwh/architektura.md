# Architektura — DWH (Data Warehouse)

## Přehled

| Položka | Hodnota |
|---|---|
| Framework | Nette Framework 3.2+ |
| PHP | 8.3+ |
| Databáze | PostgreSQL 17 (alternativně Oracle 18c XE) |
| Šablony | Latte 3.x |
| Frontend | Bootstrap 5 + Naja AJAX + Chart.js |
| Message Queue | RabbitMQ (AMQP 0.9.1) |
| Streaming | Kafka (volitelně, pro publikace) |
| Migrace | Liquibase (via Hyperdrive) |
| Verze | v3.0.4.7 |

## Co DWH dělá

DWH je ETL platforma — centrální systém pro příjem, transformaci, validaci a publikaci dat. Data se načítají z externích zdrojů (zdrojové DB, API), zpracovávají se asynchronně přes RabbitMQ pipeline a publikují do cílových systémů (materialized views, Kafka, soubory).

Ostatní aplikace (např. Judo výsledkový portál) čtou data z materializovaných pohledů, které DWH spravuje.

## Datový tok (ETL pipeline)

```
ZDROJ (zdrojová DB / API / soubor)
  ↓
[1] Data Source — SQL query na zdroji
  ↓ RabbitMQ: dataSourceQueue
[2] Import — parsování raw dat → dataset_values
  ↓ RabbitMQ: dataToValuesQueue
[3] Transformace — editace, mapování, výpočty
  ↓ RabbitMQ: transformationQueue
[4] Obohacení (Enrichment) — lookup join z jiných datasetů
  ↓ RabbitMQ: enrichmentQueue
[5] Validace — kontrola formátů, povinnosti, regex
  ↓ RabbitMQ: validationQueue
[6] Data Quality — detekce anomálií
  ↓ RabbitMQ: dataQualityQueue
[7] Publikace — export do externích systémů
  ↓ RabbitMQ: publicationQueue
VÝSTUP (materialized views, Kafka, Excel, API)
```

## Architekturní vrstvy

```
┌─────────────────────────────────────────────────┐
│  WEB FRONTEND                                   │
│  Bootstrap + Naja AJAX + Chart.js + Tom-Select  │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  NETTE MVC LAYER                                │
│  Presenters: DataModule, AdminModule,           │
│  SuperAdminModule, REST API (Apitte)            │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  SERVICE LAYER & MANAGERS                       │
│  DatasetActionService, DataSourceService,       │
│  ValidationService, PublicationService, ...     │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  REPOSITORY / DATA ACCESS LAYER                 │
│  BaseRepository, EDA ORM, Dibi                  │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  MESSAGE QUEUE WORKER LAYER                     │
│  9 RabbitMQ consumers (background procesy)      │
│  MasterConsumer → pipeline → PublicationConsumer│
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  DATABASE LAYER                                 │
│  PostgreSQL / Oracle                            │
│  Core tables + materialized views (export.*)    │
│  Migrace: Liquibase (Hyperdrive)                │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│  EXTERNAL INTEGRATIONS                          │
│  Zdrojové DB, Kafka, Portal API, SMTP           │
└─────────────────────────────────────────────────┘
```

## Framework & technologie

### Nette Framework 3.2+
- Presenter-based MVC (ne controller, ale Presenter)
- Dependency Injection přes Nette DI kontejner
- Konfigurace v NEON formátu (`.neon` soubory)
- Šablony: Latte (bezpečné, typované)

### ORM: EDA + Dibi
- **EDA** (Evosoft Data Access) — proprietární ORM
- **Dibi** — databázový abstrakční layer (fallback / raw queries)
- Podpora PostgreSQL i Oracle přes stejné rozhraní

### RabbitMQ (AMQP 0.9.1)
- 9 front + 9 consumerů
- Contributte/RabbitMQ balíček
- Consumers běží jako background procesy (24/7)
- QoS: prefetchCount 1–5 (podle kritičnosti)

### Liquibase (Hyperdrive)
- Správa databázových migrací
- XML changesets s verzováním
- Podpora PostgreSQL i Oracle
- Wrapper: `evosoftcz/hyperdrive`

### REST API (Apitte)
- Framework: `contributte/apitte`
- Verzování: `/api/rest/v1/`
- Autentizace: API token (header `apiToken`)
- OpenAPI schéma generováno automaticky

## Adresářová struktura

```
dwh/
├── app/
│   ├── AdminModule/         # Admin UI (konfigurace DS, datasetů, pravidel)
│   ├── DataModule/          # Core ETL logika
│   │   ├── Entity/          # Datový model (Dataset, DatasetPart, DataType, ...)
│   │   ├── Manager/         # Orchestrace business logiky
│   │   ├── RabbitMq/        # Consumers + Queues (7 datových)
│   │   ├── Repository/      # Data access
│   │   ├── Service/         # Business servisy (8 service adresářů)
│   │   └── Presenters/      # UI handlery (7 presenterů)
│   ├── SuperAdminModule/    # Systémová konfigurace, uživatelé
│   ├── Commands/            # CLI příkazy (5 commandů)
│   ├── Manager/             # Globální managery (10 tříd)
│   ├── RabbitMq/            # Systémové consumery (2)
│   ├── Rest/                # REST API (Apitte, V1 controllers)
│   ├── Service/             # Globální servisy (export, import, mail, ...)
│   └── Bootstrap.php        # DI kontejner bootstrap
├── bin/
│   ├── console.php          # CLI entry point
│   ├── kafkaReader.php      # Kafka debug reader
│   └── kafkaTest.php        # Kafka test publisher
├── config/
│   ├── common.neon          # Hlavní konfigurace (extensions, parameters)
│   ├── services.neon        # Service registrace
│   ├── rabbitmq.neon        # RabbitMQ topologie (9 front)
│   ├── database/            # DB-specific konfigurace
│   └── customer/            # Per-customer overrides
├── resources/
│   ├── hyperdrive/          # Liquibase migrace & SQL skripty
│   │   ├── structure/       # Core schéma (2022–2026)
│   │   ├── basic-data/      # Lookup seedy
│   │   ├── customer-data/   # Per-customer rozšíření
│   │   └── playbook.xml     # Liquibase orchestrace
│   └── scripts/             # Utility skripty
├── www/                     # Web root
│   ├── index.php            # Entry point
│   └── ...
├── tests/                   # Nette Tester
├── Makefile                 # Dev příkazy
└── docker-compose.yaml
```

## Design patterns

| Pattern | Použití |
|---|---|
| Message-Driven Architecture | RabbitMQ pipeline pro ETL |
| Domain-Driven Design | DataModule, AdminModule, SuperAdminModule |
| Service Locator | Nette DI container |
| Factory Pattern | DatasetEntityFactory, DatasetActionServiceFactory |
| Repository Pattern | BaseRepository |
| Strategy Pattern | DataType strategie (String, Integer, Date, ...) |
| Observer Pattern | Photon notifikace |

## Statistiky

| Metrika | Hodnota |
|---|---|
| PHP kódu | ~50 000+ řádků |
| DB tabulky | 20+ |
| RabbitMQ fronty | 9 |
| REST API endpointy | 15+ |
| Nette Presenters | 30+ |
| Composer závislosti | 90+ |
| npm závislosti | 47+ |
| Liquibase changesets | 20+ (2022–2026) |
