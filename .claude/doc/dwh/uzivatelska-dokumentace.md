# Uživatelská dokumentace — DWH

## K čemu DWH slouží

DWH (Data Warehouse) je administrativní nástroj pro správu datových toků. Umožňuje:

- Definovat **datasety** — co jsou data, jaká mají strukturu
- Konfigurovat **datové zdroje** — odkud se data načítají (zdrojové DB, API)
- Nastavit **pravidla zpracování** — transformace, obohacení, validace
- Spustit **import dat** — načtení dat ze zdrojů a jejich zpracování
- **Publikovat data** — export do cílových systémů (materialized views, Kafka, XLSX)
- Monitorovat **stav zpracování** a řešit chyby

---

## Moduly aplikace

### Data (hlavní sekce)

Přehled datasetů a správa datových entit.

**Dataset** — definuje strukturu dat (jaká pole, jaké typy, pravidla).  
**Dataset entity** — konkrétní datové záznamy (řádky dat).

### Admin

Konfigurace datových zdrojů, transformací, validací a obohacení.

### Super Admin

Systémová konfigurace, správa uživatelů a přístupů.

---

## Workflow — jak naimportovat data

1. **Nadefinuj datový zdroj** (Admin → Data Sources)
   - Vyber připojení na zdrojovou DB
   - Zadej SQL query, která vrátí data
   - Nastav prioritu a plán (cron nebo manuálně)

2. **Nadefinuj pravidla** (Admin → Transformace / Validace / Enrichment)
   - Transformace: jak upravit hodnoty (přepisy, výpočty)
   - Enrichment: doplnění dat z jiných datasetů (lookup join)
   - Validace: kontrola formátů, povinných polí

3. **Spusť import** (Data → Dataset → tlačítko „Načíst data")
   - Data se zařadí do fronty zpracování
   - Systém asynchronně projde celou pipeline

4. **Zkontroluj výsledky** (Data → Dataset → přehled entit)
   - Stav každé entity: valid / invalid / published
   - Chybové hlášky u neplatných entit

5. **Spusť publikaci** (Data → Dataset → tlačítko „Publikovat")
   - Data se exportují do cílového systému

---

## Stavy datových entit

| Stav | Popis |
|---|---|
| new | Čerstvě importovaný záznam |
| valid | Prošel základní validací |
| invalid | Selhal validaci — obsahuje chybové záznamy |
| transformed | Prošel transformacemi |
| enriched | Prošel obohacením |
| validated | Prošel kompletní validací |
| published | Publikován do cílového systému |
| locked | Zamčen — nelze editovat |
| archived | Historický záznam |

---

## Validace

Systém validuje každou entitu dle nakonfigurovaných pravidel:

- **Povinné pole** — hodnota nesmí být prázdná
- **Formát** — regex, email formát, číslo, datum
- **Min / Max** — rozsah číselné hodnoty
- **Unikátnost** — hodnota nesmí existovat duplicitně

Pokud entita selže validaci, dostane stav `invalid` a obsahuje seznam chybových hlášek. Tyto chyby jsou viditelné v detailu entity.

---

## Export dat

**XLSX export:**
- Data → Dataset → tlačítko „Export"
- Vygeneruje Excel soubor ke stažení
- Soubor obsahuje aktuální stav všech entit

**Materialized views:**
- Po publikaci jsou data dostupná v PostgreSQL schématu `export.*`
- Ostatní aplikace (portály, reporty) čtou přímo z těchto pohledů

**Kafka:**
- Po publikaci se zpráva pošle na nakonfigurovaný Kafka topic
- Downstream systémy konzumují topic a reagují na změny

---

## Monitoring RabbitMQ front

**Data → Queues** — přehled stavu RabbitMQ front:
- Počet zpráv ve frontách
- Stav consumerů (běží / neběží)
- Statistiky zpracování

Pokud je fronta nabitá nebo consumer neběží, je nutné zkontrolovat logy a restartovat consumery.

---

## Možné chyby a jejich řešení

| Chyba | Příčina | Co dělat |
|---|---|---|
| 500 error na všech stránkách | RabbitMQ není dostupné | Kontaktovat správce — restart RabbitMQ |
| Import se nespustí | Consumer neběží | Spustit consumery (`make rabbitmq`) |
| Entita je trvale `invalid` | Chyba validačního pravidla nebo špatná data | Zkontrolovat chyby v detailu entity |
| Publikace selže | Chyba připojení na cílový systém | Zkontrolovat konfiguraci publikace |
| Export soubor se nevygeneruje | Disk plný nebo práva | Kontaktovat správce |
| Data jsou stará | Cron job neproběhl | Spustit import ručně nebo zkontrolovat cron |

---

## Tlačítka a akce

| Prvek | Akce |
|---|---|
| „Načíst data" | Spustí import datasetu (zařadí do RabbitMQ) |
| „Publikovat" | Spustí publikaci do cílového systému |
| „Export" | Stáhne XLSX soubor s daty |
| „Zamknout entitu" | Uzamkne entitu (locked — nelze editovat) |
| „Archivovat" | Přesune staré entity do archivu |
| „Rebuild views" | Obnoví materialized views v DB |
| Filtr / řazení v tabulce | Filtruje a řadí záznamy |
| Detail entity | Otevře přehled hodnot a stav zpracování |

---

## Přístupová práva (RBAC)

| Role | Co může |
|---|---|
| Admin | Konfigurace datasetů, zdrojů, pravidel; správa importů |
| Uživatel | Zobrazení dat, spuštění importů, export |
| Super Admin | Vše + správa uživatelů, systémová konfigurace |

---

## Poznámky pro uživatele

- Import je **asynchronní** — po kliknutí „Načíst data" se data zpracovávají na pozadí, výsledek není okamžitý
- Materialized views se aktualizují **až po publikaci** — předtím vidí ostatní systémy stará data
- Export do XLSX se generuje za běhu — u velkých datasetů může trvat déle
- Locked entity nelze měnit — pro odemčení se obraťte na správce
