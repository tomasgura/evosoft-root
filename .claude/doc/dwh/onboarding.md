# Onboarding pro nového developera — DWH

## Přehled projektu

DWH (Data Warehouse) je ETL platforma. Přijímá data z externích zdrojů (zdrojové databáze, API, soubory), zpracovává je asynchronně přes RabbitMQ pipeline (transformace, validace, enrichment) a publikuje do cílových systémů (materialized views, Kafka, XLSX, API).

Ostatní aplikace Evosoft (např. Judo výsledkový portál) čtou data z materializovaných pohledů, které DWH spravuje.

---

## Technologický stack (TL;DR)

| Co | Kde hledat |
|---|---|
| PHP 8.3, Nette Framework 3.2+ | `composer.json`, `app/` |
| PostgreSQL / Oracle | `config/database/`, `config/local.neon` |
| ORM: EDA + Dibi | `app/DataModule/Repository/` |
| RabbitMQ (AMQP) | `config/rabbitmq.neon`, `app/DataModule/RabbitMq/` |
| Kafka | `config/local.neon` → sekce `publications` |
| Liquibase (DB migrace) | `resources/hyperdrive/` |
| REST API (Apitte) | `app/Rest/` |
| CLI | `bin/console.php` |

---

## Kde začít čtení kódu

1. **`www/index.php`** — entry point (web i REST API)
2. **`app/Bootstrap.php`** — DI kontejner, konfigurace
3. **`config/common.neon`** — hlavní konfigurace (extensions, parameters)
4. **`config/rabbitmq.neon`** — topologie RabbitMQ front a consumerů
5. **`app/DataModule/Presenters/DatasetPresenter.php`** — hlavní UI presenter
6. **`app/DataModule/RabbitMq/Consumer/MasterConsumer.php`** — vstupní bod ETL pipeline
7. **`app/DataModule/Service/DataSourceService/`** — jak se volá zdrojová DB
8. **`app/DataModule/Service/PublicationService/`** — jak se publikují data
9. **`resources/hyperdrive/structure/2022-01-01-init.xml`** — iniciální DB schéma

---

## Klíčové koncepty

### 1. ETL Pipeline přes RabbitMQ
Celý datový tok (import → transformace → validace → publikace) běží asynchronně přes RabbitMQ fronty. Žádný step nevolá další step přímo — vždy přes publish zprávy do další fronty. Consumery běží jako background procesy (24/7).

### 2. EAV datový model
`dataset_values` má Entity-Attribute-Value strukturu: pro každý záznam je N řádků kde N = počet sloupců datasetu. Výhoda: flexibilní schéma. Nevýhoda: JOINy jsou nákladné.

### 3. Per-customer konfigurace
Každý zákazník (customer) má svůj adresář v `resources/hyperdrive/customer-data/c{N}/` s vlastními XML changesets. Customer ID je v `config/common.neon` → `parameters.customer`.

### 4. Nette Framework vs. Symfony
DWH používá **Nette**, ne Symfony. Hlavní rozdíly:
- Presenters místo Controllers
- Latte šablony místo Twig
- NEON konfigurace místo YAML
- Nette DI místo Symfony DI

### 5. RabbitMQ autoCreate problem
Aktuálně je `autoCreate: true` — každý HTTP request otevírá TCP spojení s RabbitMQ. Výpadek RabbitMQ = 500 na všech stránkách. Toto je known issue.

---

## Kde jsou co soubory

| Hledám | Kde najdu |
|---|---|
| HTTP handlery (web) | `app/DataModule/Presenters/`, `app/AdminModule/Presenters/` |
| HTTP handlery (API) | `app/Rest/V1/Controllers/` |
| Business logiku | `app/DataModule/Service/` |
| ETL consumery | `app/DataModule/RabbitMq/Consumer/` |
| DB dotazy | `app/DataModule/Repository/` |
| Datové entity | `app/DataModule/Entity/` |
| Šablony | `app/DataModule/templates/`, `app/AdminModule/templates/` |
| Frontend JS | `www/js/` |
| Konfigurace | `config/*.neon` |
| DB migrace | `resources/hyperdrive/structure/` |
| Customer data | `resources/hyperdrive/customer-data/c{N}/` |
| CLI entry point | `bin/console.php` |

---

## Časté otázky

**Q: Jak přidat nový sloupec do datasetu?**  
A: Přidat `dataset_part_definition` přes Admin UI nebo XML changeset v `customer-data/c{N}/`. Pak rebuild materializovaného pohledu.

**Q: Jak spustit import ručně?**  
A: V Admin UI tlačítko „Načíst data" u daného datasetu, nebo `POST /api/rest/v1/actions/get-data/{name}` přes REST API.

**Q: Jak spustit consumery lokálně?**  
A: `make rabbitmq` (spustí 9 consumerů v background) nebo jednotlivě:
```bash
php bin/console.php rabbitmq:staticConsumer masterConsumer 5000
```

**Q: Jak spustit DB migrace?**  
A: `php bin/console.php hyperdrive:start postgre`  
Pro reset celé DB (DESTRUCTIVNÍ!): `make reload-postgre`

**Q: Kde se logují chyby?**  
A: `log/exception.log` a Tracy HTML dumpy v `log/exception*.html`

**Q: Jak přidat nový typ publikace?**  
A: Rozšířit `PublicationService` o nový handler, přidat typ do `publication` tabulky.

**Q: Co je Hyperdrive?**  
A: Evosoft wrapper nad Liquibase (Java). Spouští XML changesets na DB. Nutné mít Java runtime.

**Q: Jak funguje per-customer konfigurace?**  
A: `config/customer/customer-{N}.neon` přepisuje parametry z `common.neon`. Customer-specific DB schéma je v `resources/hyperdrive/customer-data/c{N}/`.

---

## Doporučený postup pro první týden

1. Přečti tuto dokumentaci (architektura, datový tok, datový model)
2. Spusť aplikaci lokálně (`doc/README-lokalni-spusteni.md`)
3. Projdi Admin UI — podívej se na konfiguraci datasetu
4. Přečti `MasterConsumer` a sleduj chain consumerů
5. Spusť ručně import jednoho datasetu a sleduj logy
6. Přečti XML changeset v `resources/hyperdrive/structure/2022-01-01-init.xml`
7. Spusť PHPStan: `make phpstan`
8. Přečti soubor `analýza.md` v rootu — obsahuje case study `tournament_match` datasetu
