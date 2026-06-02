# Datový model — DWH

## Přehled databáze

- **Engine:** PostgreSQL 17 (alternativně Oracle 18c XE)
- **Schéma:** `public` (core tabulky), `export` (materializované pohledy)
- **Migrace:** Liquibase (Hyperdrive), soubory v `resources/hyperdrive/structure/`
- **Aplikace nepíše** do `export.*` — to dělá PublicationConsumer

---

## Klíčové tabulky

### Konfigurace a připojení

| Tabulka | Obsah |
|---|---|
| `lookup_language` | Jazyky aplikace (cs, en, de, ...) |
| `source_connection` | Připojení na zdrojové databáze (host, port, db, user, encrypted pwd) |
| `data_source` | SQL query na zdrojové DB (name, connection_id, sql, schedule, priorita) |
| `appuser` | Uživatelé aplikace (login, password hash, role) |
| `application` | API tokeny pro REST API |

### Dataset a jeho definice

| Tabulka | Obsah |
|---|---|
| `dataset` | Definice datové sady (name, description, dataset_part_id) |
| `dataset_part` | Fyzická část datasetu (odpovídá jedné tabulce/struktuře) |
| `dataset_part_definition` | Sloupec/pole datasetu (name, data_type, required, order, ...) |

### Data (hodnoty)

| Tabulka | Obsah |
|---|---|
| `dataset_entity` | Jeden datový záznam (= řádek v datasetu). Status, historization flag. |
| `dataset_values` | Konkrétní hodnoty: `(entity_id, def_id)` → `value` (TEXT, vždy string) |

Tabulka `dataset_values` je nejrozsáhlejší — může obsahovat miliony řádků.

### Procesní pravidla

| Tabulka | Obsah |
|---|---|
| `data_transformation` | Transformační pravidla (before_value → after_value) |
| `data_enrichment` | Enrichment mapování (lookup z jiného datasetu) |
| `data_validation` | Validační pravidla (required, regex, format, min/max) |
| `data_quality_rule` | Pravidla pro detekci anomálií |

### Publikace

| Tabulka | Obsah |
|---|---|
| `publication` | Definice cílového exportu (typ: view, Kafka, file, ...) |

### Organizace dat

| Tabulka | Obsah |
|---|---|
| `entity_group` | Skupina entit (logická kategorie) |
| `entity_group_category` | Kategorie skupin (hierarchie) |

### Joby a procesy

| Tabulka | Obsah |
|---|---|
| `job_definition` | Definice naplánovaného jobu (cron_expression, enabled, dataset_id) |

---

## Vztahy

```
source_connection (1) ──── (N) data_source
                                    │
                                    ↓
dataset_part (1) ──── (N) dataset_part_definition ──── (1) DataType
      │
      ↓
dataset_entity (N) ──── (N) dataset_values
      │                          (entity_id, def_id) → value
      ↓
dataset_entity_history (archiv)

dataset_part ──── (N) data_transformation
dataset_part ──── (N) data_enrichment
dataset_part ──── (N) data_validation
dataset_part ──── (N) data_quality_rule
dataset_part ──── (N) publication

entity_group_category (1) ──── (N) entity_group
entity_group (N) ──── (N) dataset_entity  (přiřazení entit do skupin)
```

---

## DataType (9 datových typů)

Každý `dataset_part_definition` má datový typ, který určuje:
- Validaci hodnoty
- Zobrazení v UI
- Formát při exportu

| Typ | PHP třída | Validace |
|---|---|---|
| String | DataType\String | max délka, regex |
| Integer | DataType\Integer | celé číslo, min/max |
| Float | DataType\Float | desetinné číslo, min/max |
| Date | DataType\Date | formát data (Y-m-d) |
| DateTime | DataType\DateTime | formát datetime |
| Time | DataType\Time | formát času |
| Bool | DataType\Bool | true/false |
| Email | DataType\Email | formát emailu |
| ArrayInt | DataType\ArrayInt | JSON pole celých čísel |

---

## dataset_entity — stavy

```
new        → čerstvě importovaný záznam
valid      → prošel základní validací
invalid    → selhal validaci (má chybové záznamy)
transformed → prošel transformacemi
enriched   → prošel enrichmentem
validated  → prošel kompletní validací
published  → publikován do cílového systému
locked     → zamčen (nelze editovat)
archived   → historický záznam (po historizaci)
```

---

## Materializované pohledy (výstupy DWH)

Schéma `export.*` — čtou je ostatní aplikace (portály, reporty, ...).

Naming konvence:
```
export.mv_dataset_export_{dataset_name}_{part_name}
```

Příklady:
```
export.mv_dataset_export_tournaments_tournaments_main
export.mv_dataset_export_members_members_main
export.mv_dataset_export_clubs_clubs_main
export.mv_dataset_export_tournament_match_tournament_match_main
export.mv_dataset_export_tournament_results_tournament_results_main
```

Refresh materializovaných pohledů spouští `PublicationConsumer` nebo příkaz `app:database-views-rebuild`.

---

## Databázové migrace (Liquibase / Hyperdrive)

**Lokace:** `resources/hyperdrive/`

```
structure/              # Core schéma changesets
  2022-01-01-init.xml   # Iniciální schéma (všechny core tabulky)
  2023-*.xml
  2024-*.xml
  2025-*.xml
  2026-*.xml

basic-data/             # Lookup seedy (jazyky, typy, ...)
customer-data/c{N}/     # Per-customer rozšíření datasetu
  2025-*.xml            # Customer-specific changesets

playbook.xml            # Orchestrace — pořadí migration groups
```

**Spuštění migrací:**
```bash
php bin/console.php hyperdrive:start postgre
```

**Migration groups (v pořadí):**
1. extension-base, extension-configuration, extension-log, extension-lookup, ...
2. structure (core DWH schéma)
3. basic-data (lookups)
4. customer-data/c{N} (customer-specific)
5. dummy-data (jen v debug módu)

---

## Šifrování citlivých dat

- Hesla v `source_connection` jsou šifrována (AES, IV + secret z konfigurace)
- Parametry: `iv` a `secret` v `config/local.neon`
- Dešifrování provádí `DataSourceService` za runtime
