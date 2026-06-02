# Onboarding pro nového developera — Judo Výsledkový portál

## Přehled projektu

Judo výsledkový portál je webová aplikace pro zobrazování výsledků judistických turnajů, profilů zápasnických členů a klubů v rámci ČSJÚ (Český svaz juda). Aplikace je read-only — nezapisuje data, jen je čte z DWH a externích API.

---

## Technologický stack (TL;DR)

| Co | Kde hledat |
|---|---|
| PHP 8.3, Symfony 7.1 | `composer.json`, `src/` |
| PostgreSQL read-only | `config/packages/eda.yaml`, `src/Repository/Database/DWH.php` |
| ORM: EDA (proprietární Evosoft) | `src/Repository/Base/BaseRepository.php` |
| Frontend: Bootstrap + Stimulus | `assets/`, `templates/` |
| Cache: APCu / file-based | `src/Service/Cache/` |
| Flexii API | `src/Repository/External/FlexiiRepository.php` |
| Hajime live API | `src/Repository/External/HajimeEndpoint.php` |

---

## Kde začít čtení kódu

1. **`public/index.php`** — entry point
2. **`src/Controller/TournamentsController.php`** — nejdůležitější controller, pochopíš celý tok
3. **`src/Service/TournamentService.php`** — business logika, vzor pro ostatní services
4. **`src/Repository/TournamentsRepository.php`** — jak se čtou data z DWH přes EDA
5. **`src/Repository/External/HajimeEndpoint.php`** — jak se volá live API
6. **`src/Entity/Tournament/Tournament.php`** — hlavní entita, vidíš všechna pole
7. **`src/Twig/Components/Datagrid/Datagrid.php`** — jak funguje dynamická tabulka

---

## Klíčové koncepty

### 1. ITournamentDetailRepository
Rozhraní s dvěma implementacemi:
- `TournamentDetailHajimeRepository` — pro live turnaje (je_hajime = true)
- `TournamentDetailDWHRepository` — pro archivní turnaje

Přepínání závisí na stavu turnaje, ne na env proměnné.

### 2. Datagrid
Dynamická tabulka načítaná přes AJAX. Konfigurace sloupce se dělá PHP atributem `#[DatagridColumn(...)]` na DTO třídě. JavaScript na frontendu volá `/api/*` endpointy s `QueryParams` (page, sort, filter).

### 3. Cache
Všechna data jsou cachována v `AppCacheService`. Cache klíče jsou generovány z parametrů requestu. Při vývoji cache vypni přes `.env`:
```
EVO_CACHE_ENABLED=false
```

### 4. DWH tabulky
Nejsou to klasické tabulky — jsou to materializované pohledy se jmény jako `export.mv_dataset_export_tournaments_tournaments_main`. Aplikace do nich nepíše, jen čte. Názvy tabulek jsou konstanty v `src/Repository/Database/DWH.php`.

### 5. Cron joby
Dva CLI commandi se spouštějí periodicky:
- `php bin/console app:get-tournaments` — sync turnajů a jejich souborů z Flexii
- `php bin/console app:get-clubs` — sync klubů a jejich log z Flexii

---

## Lokální spuštění

Viz `README.md` v root adresáři projektu, nebo soubor `doc/README-lokalni-spusteni.md`.

---

## Kde jsou co soubory

| Hledám | Kde najdu |
|---|---|
| HTTP handlery | `src/Controller/*.php` |
| Business logiku | `src/Service/*.php` |
| DB dotazy | `src/Repository/*.php` |
| Live API volání | `src/Repository/External/*.php` |
| Datové modely | `src/Entity/**/*.php` |
| Šablony stránek | `templates/**/*.html.twig` |
| Reusable komponenty | `src/Twig/Components/*.php` + `templates/components/*.html.twig` |
| Frontend JS | `assets/controllers/*.js` |
| Překlady | `translations/*.cs.yaml` |
| Konfigurace | `config/packages/*.yaml` |
| Env proměnné | `.env`, `.env.local` |
| DWH konstanty | `src/Repository/Database/DWH.php` |
| Cache nastavení | `src/Service/Cache/CacheRecord.php` |

---

## Časté otázky

**Q: Kde se berou data pro turnaje?**  
A: Z DWH přes `TournamentsRepository`. Pro live turnaje (`is_hajime = true`) se živé zápasy/výsledky berou z Hajime API přes `HajimeEndpoint`.

**Q: Jak přidat nový sloupec do datagridu?**  
A: Přidej vlastnost do příslušného RowDTO a oznachu ji atributem `#[DatagridColumn(title: 'klic.prekladu', type: 'text', ...)]`. Pak přidej překlad do `translations/*.cs.yaml`.

**Q: Jak funguje vyhledávání?**  
A: `SearchService` → `*Repository::search*ByName()` → EDA dotaz s LIKE/ILIKE. Výsledky jsou JSON (autocomplete dropdown).

**Q: Cache stará data — jak resetovat?**  
A: `php bin/console cache:pool:clear cache.app` nebo nastav `EVO_CACHE_ENABLED=false` v `.env.local`.

**Q: Jak spustit Flexii sync ručně?**  
A: `php bin/console app:get-tournaments` nebo `php bin/console app:get-clubs`

**Q: Kde jsou loga klubů fyzicky uložena?**  
A: `public/files/clubsLogo/{club_uid}.*`

**Q: Kde jsou výsledkové soubory od pořadatelů?**  
A: `public/files/tournaments/{tournament_uid}/`

---

## Doporučený postup pro první týden

1. Přečti tuto dokumentaci
2. Spusť aplikaci lokálně (`doc/README-lokalni-spusteni.md`)
3. Proklikej aplikaci — turnaje, detail, zápasy, výsledky, export
4. Přečti `TournamentsController` celý od shora
5. Sleduj request v debugbaru (Symfony Profiler) — uvidíš DB dotazy, cache hity
6. Zkus přidat sloupec do datagridu (na sandbox branch)
7. Spusť PHPStan: `composer phpstan`
