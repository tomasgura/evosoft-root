# Externí integrace — Judo Výsledkový portál

## Přehled integrací

| Integrace | Typ | Směr | Účel |
|---|---|---|---|
| Flexii API | REST HTTP | Pull (příchozí data) | Turnaje, kluby, loga, výsledkové soubory |
| Hajime API | REST HTTP | Pull (live data) | Live výsledky, losování, zápasy |
| PostgreSQL DWH | DB | Pull (read-only) | Archivní data (členové, turnaje, zápasy, výsledky) |
| mPDF | Knihovna | Generování | Export výsledků do PDF |
| PhpSpreadsheet | Knihovna | Generování | Export výsledků do XLSX |
| Mailer | Symfony | (připraveno) | Emaily — zatím nevyužito |

---

## 1. Flexii API

**Typ:** REST HTTP (GET)  
**Třída:** `src/Repository/External/FlexiiRepository.php`  
**Konfigurace:** `config/packages/flexii_connector.yaml`  
**Driver:** `FlexiiConnector\Driver`

### Environment proměnné

```
FLX_CONNECT_API_URL=https://...
FLX_CONNECT_API_TOKEN=...
FLX_CONNECT_API_DEBUG=0
FLX_CONNECT_API_LAZY=1
FLX_CONNECT_CRYPTO_ENABLED=1
FLX_CONNECT_CRYPTO_IV=...
FLX_CONNECT_CRYPTO_SECRET=...
FLX_CONNECT_LOG_ENABLED=0
```

### Co se stahuje

| Metoda | Popis |
|---|---|
| `getTournamentsFromFlexii()` | Seznam všech turnajů |
| `getClubsFromFlexii()` | Seznam všech klubů |
| `getClubLogoFromFlexiiIfUpdated($uid)` | Logo klubu (jen pokud se změnilo dle dt_upd_attributes) |
| `saveClubLogoFile($uid, $data)` | Uložení loga do `public/files/clubsLogo/` |
| `getTournamentResultFilesFromFlexiiIfUpdated($uid)` | Výsledkové soubory turnaje (jen při změně) |
| `saveTournamentResultFile($uid, $filename, $data)` | Uložení souboru do `public/files/tournaments/{uid}/` |

### Synchronizační logika

- Porovnávají se `dt_upd_attributes` z API vs. timestamp lokálního souboru
- Pokud je soubor novější na serveru → stáhne se aktualizovaná verze
- Synchronizace se spouští přes CLI command (cron job), ne za runtime requestu

---

## 2. Hajime API

**Typ:** REST HTTP (GET)  
**Třída:** `src/Repository/External/HajimeEndpoint.php`  
**Service:** `src/Service/HajimeService.php`  
**Konfigurace:** environment proměnná `HAJIME_URL`

### Environment proměnné

```
HAJIME_URL=https://hajime-api.url
CACHE_EXPIRATION_SECONDS_LIVE_RESULTS=60
```

### Endpointy

| Endpoint | Metoda | Popis |
|---|---|---|
| `/api/open/tournament/{uid}/subcategory` | `getSubcategoryJSON()` | Věkové kategorie a podkategorie |
| `/api/open/tournament/{uid}/subcategory-shuffle/{id}` | `getShuffleJSON()` | Losovací tabulka/pavouk |
| `/api/open/tournament/{uid}/subcategory-matches/{id}` | `getMatchesJSON()` | Live zápasy v kategorii |
| `/api/open/tournament/{uid}/subcategory-results/{id}` | `getResultsJSON()` | Výsledky podkategorie |
| `/api/open/tournament/{uid}/results/{agecategory_id}` | `getAgeCategoryResultsJSON()` | Výsledky věkové kategorie |

### Poznámky

- SSL verifikace je **vypnuta** (`setSslVerifyHost(false)`, `setSslVerifyPeer(false)`) — interní prostředí
- Cachování s krátkým TTL (`CACHE_EXPIRATION_SECONDS_LIVE_RESULTS`, default ~60 s) pro live data
- Hajime data jsou dostupná pouze pro turnaje s příznakem `is_hajime = true`
- Interface `ITournamentDetailRepository` má dvě implementace:
  - `TournamentDetailHajimeRepository` — pro live turnaje (čte z Hajime)
  - `TournamentDetailDWHRepository` — pro archivní turnaje (čte z DWH)

---

## 3. PostgreSQL DWH

**Typ:** Přímé DB připojení  
**ORM:** EDA (Evosoft Data Access)  
**Konfigurace:** `config/packages/eda.yaml`

### Environment proměnné

```
DATABASE_NAME=...
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=...
DATABASE_PASSWORD=...
```

### Přístup k datům

- Pouze **čtení** (SELECT)
- Schéma: `export.*`
- Tabulky jsou materializované pohledy — refresh zajišťuje ETL (externí)
- BaseRepository implementuje `applyFilters()`, `applySort()`, `pagination` přes EDA Flow builder

---

## 4. Export (mPDF + PhpSpreadsheet)

**Třída:** `src/Service/ExportService.php`

### PDF export
- Knihovna: `mpdf/mpdf`
- Metoda: `exportResultsToPdf($results)`
- Formátování: zlatá/stříbrná/bronzová barva, borders, header řádky
- Tmp soubory: `var/tmp/`

### XLSX export
- Knihovna: `phpoffice/phpspreadsheet`
- Metoda: `exportResultsToXlsx($results)`
- Více listů — jeden list per věková kategorie
- Sdílená logika: `resultsToSpreadsheet()`

### Životní cyklus souboru
```
1. ExportService vygeneruje soubor do var/tmp/{filename}
2. Controller vrátí BinaryFileResponse (stream do browseru)
3. Soubor zůstane v tmp — není automaticky mazán (cleanup by měl být cron)
```

---

## 5. Flexii výsledkové soubory (stahované PDF/XLSX)

- Výsledkové soubory turnajů (PDF, XLSX od pořadatelů) se stahují z Flexii API
- Ukládají se do `public/files/tournaments/{tournament_uid}/`
- Aplikace je nabízí ke stažení přes `download_result_file` endpoint
- Jsou to soubory **od pořadatelů**, ne generované touto aplikací

---

## 6. Mailer (připraveno, nevyužito)

- Konfigurace: `config/packages/mailer.yaml`
- Symfony Mailer je zaregistrován, ale není aktuálně využíván v žádné service
- Připraveno pro budoucí notifikace

---

## 7. Google Analytics

- GA ID konfigurovatelné přes env: `GOOGLE_ANALYTICS_ID`
- Načítáno v base Twig šabloně

---

## Bezpečnostní poznámky k integracím

| Integrace | Poznámka |
|---|---|
| Hajime API | SSL verifikace vypnuta — použití jen v interní síti |
| Flexii API | Token autentizace + volitelné šifrování (crypto IV/secret) |
| DWH | Přístup přes dedikovaného read-only DB uživatele |
| Export tmp soubory | `var/tmp/` není web-přístupný (mimo `public/`) |
