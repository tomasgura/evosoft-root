# Hlavní moduly — Judo Výsledkový portál

## Controllers (entry pointy)

### TournamentsController
Hlavní controller pro turnaje. Zpracovává seznam, detail i live výsledky.

| Metoda | Route | Popis |
|---|---|---|
| index | `/tournaments/{state}` | Seznam turnajů (archive/active/current) |
| detail | `/tournaments/uid/{uid}` | Detail turnaje |
| matches | `/tournaments/uid/{uid}/matches` | Live zápasy |
| tables | `/tournaments/uid/{uid}/tables` | Shuffle tabulky |
| results | `/tournaments/uid/{uid}/results` | Výsledky |
| statistics | `/tournaments/uid/{uid}/statistics` | Statistiky turnaje |
| videos | `/tournaments/uid/{uid}/videos` | Videa |
| export_results | — | Export výsledků (PDF/XLSX) |
| download_result_file | — | Stažení výsledkového souboru |
| datagridData | `/api/tournament` | JSON data pro datagrid |
| signedUpMembersData | `/api/tournament/{uid}/members` | Přihlášení členové |
| categoriesData | `/api/tournament/{uid}/categories` | Kategorie turnaje |
| searchByName | `/api/search/tournament` | Fulltext vyhledávání |

### MembersController
Správa a zobrazení členů.

| Metoda | Route | Popis |
|---|---|---|
| index | `/members` | Seznam členů |
| detail | `/members/{uid}` | Detail člena |
| memberMatches | — | Zápasy člena |
| datagridData | `/api/member` | JSON data pro datagrid |
| tournamentParticipationData | `/api/member/{uid}/tournaments` | Historie turnajů |
| searchByName | `/api/search/member` | Vyhledávání členů |
| searchByNameAndTournament | `/api/search/memberbytournament` | Filtrované vyhledávání |

### ClubsController
Správa a zobrazení klubů.

| Metoda | Route | Popis |
|---|---|---|
| index | `/clubs` | Seznam klubů |
| detail | `/clubs/{uid}` | Detail klubu |
| datagridData | `/api/clubs` | JSON data pro datagrid |
| datagridMemberData | `/api/clubs/{uid}/members` | Členové klubu |
| searchByName | `/api/search/club` | Vyhledávání klubů |

### StatisticsController
Globální statistiky.

| Metoda | Route | Popis |
|---|---|---|
| index | `/statistics` | Stránka se statistikami |

### ErrorController
Zpracování HTTP chyb. Metody `show` (obecná chyba) a `error_500` (vlastní 500 stránka).

---

## Services (business logika)

### TournamentService
Centrální service pro turnaje. Cachuje většinu dat.

- `getTournamentsDatagridData()` — data pro seznam turnajů
- `getTournamentByUID()` — detail turnaje
- `getTournamentAgeCategories()`, `getSubcategories()` — kategorie
- `getTournamentMatches()`, `getTatamiMatches()` — zápasy (live nebo DWH)
- `getResultsForAgeCategory()`, `getResultsForSubcategory()` — výsledky
- `getTournamentVideos()` — videa
- `getResultFiles()` — soubory výsledků

### MemberService
- `getMembersDatagridData()` — seznam členů s filtrací
- `getMemberByUID()` — detail člena
- `getMemberParticipationStatistics()` — statistiky účasti
- `getMemberParticipatedTournamentsData()` — seznam odehraných turnajů

### ClubService
- `getClubsDatagridData()` — seznam klubů
- `getClubByUID()` — detail klubu

### MatchService
- `getTournamentMatches()` — zápasy turnaje
- `getMemberMatches()` — zápasy konkrétního člena
- Statistiky matchů

### HajimeService
- `getTournamentSubcategoryShuffle()` — live data z Hajime API (pavoukové/tabulkové pairing)

### SearchService
- `searchMembersByName()` — fulltext přes členy
- `searchTournamentsByName()` — fulltext přes turnaje
- `searchClubsByName()` — fulltext přes kluby

### StatisticsService
- `getTournamentStatistics()` — agregované statistiky

### ExportService
- `exportResultsToPdf()` — generuje PDF přes mPDF
- `exportResultsToXlsx()` — generuje XLSX přes PhpSpreadsheet
- Tmp soubory ukládá do `var/tmp/`

---

## Repositories (přístup k datům)

### Interní (DWH / PostgreSQL)

| Repository | Tabulka DWH | Klíčové metody |
|---|---|---|
| TournamentsRepository | `export.mv_dataset_export_tournaments_tournaments_main` | getDatagridData, getTournament, searchTournamentsByName |
| MemberRepository | `export.mv_dataset_export_members_members_main` | getMember, getDatagridData, searchMembersByName |
| ClubRepository | `export.mv_dataset_export_clubs_clubs_main` | getClub, getDatagridData, searchClubsByName |
| MatchRepository | `export.mv_dataset_export_tournament_match_tournament_match_main` | getTournamentMatches, getMemberMatches |
| CountryRepository | — | getCountries, getCountryByCode |

### Externí API

| Repository | API | Klíčové metody |
|---|---|---|
| FlexiiRepository | Flexii API | getTournamentsFromFlexii, getClubsFromFlexii, saveClubLogoFile, saveTournamentResultFile |
| HajimeEndpoint | Hajime live API | getSubcategoryJSON, getShuffleJSON, getMatchesJSON, getResultsJSON |
| TournamentDetailHajimeRepository | Hajime (impl. ITournamentDetailRepository) | getAgeCategories, getSubcategories, getMatches, getResultsForAgeCategory |
| TournamentDetailDWHRepository | DWH (impl. ITournamentDetailRepository) | stejné rozhraní, ale čte z databáze |

**Interface `ITournamentDetailRepository`** umožňuje přepínání mezi live (Hajime) a archivními (DWH) daty bez změny v Service vrstvě.

---

## CLI Commands (cron joby)

### `app:get-tournaments`
- Stáhne seznam turnajů z Flexii API
- Pro každý turnaj zkontroluje `dt_upd_attributes` oproti lokálnímu stavu
- Pokud se turnaj změnil → stáhne nové výsledkové soubory
- Soubory uloží do `public/files/tournaments/{tournament_uid}/`

### `app:get-clubs`
- Stáhne seznam klubů z Flexii API
- Pro každý klub zkontroluje logo (dt_upd_attributes vs. čas souboru)
- Pokud se logo změnilo → stáhne nové logo
- Loga uloží do `public/files/clubsLogo/`

---

## Twig komponenty (30+)

### Datagrid
- `Datagrid` — dynamický grid s lazy-loading dat přes API, filtrací, řazením, stránkováním

### Navigace
- `Navbar`, `NavTabButton`, `NavTabPane`

### Layout
- `Card`, `Breadcrumb`, `Bread`

### Turnajové komponenty
- `BasicInfoComponent` — základní info o turnaji
- `AgeCategoryPicker`, `SubCategoryPicker`, `TatamiCategoryPicker` — výběr kategorie
- `CategoryResults` — výsledky kategorie
- `BasicStatisticsTableDisplay` — statistická tabulka
- `YoutubeVideoEmbed` — embed YouTube videa

### Členské komponenty
- `RankDisplay` — zobrazení kyu/dan
- `StatisticsCard` — karta se statistikami
- `MemberMatchSearch` — vyhledávání zápasnících

### Klubové komponenty
- `ClubLink` — odkaz na klub

### Utility
- `CountryFlag` — vlajka státu
- `MatchDisplay` — zobrazení zápasu
- `TableShuffleRenderer`, `SpiderShuffleRenderer` — render pavouka/tabulky
- `BarChart` — sloupcový graf pro statistiky

---

## Entity / DTO

### Hlavní entity
- **Tournament** — 53 properties, metody `getState()`, `isStarted()`, `isFinished()`, `getYear()`
- **Member** — uid, jméno, rok narození, klub, kyu/dan, metoda `getAge()`
- **Club** — uid, název, IČO, web, email, telefon, logo, adresa
- **AgeCategory** — věková kategorie, metody `isMale()`, `isFemale()`, `isKids()`, `getPriority()`
- **SubCategory** — podkategorie (váha, pohlaví, věk)

### DTO pro datagrid
- `TournamentRowDTO`, `MemberRowDTO`, `ClubRowDTO`
- `TournamentMemberRowDTO`, `TournamentCategoryRowDTO`
- `DatagridTournamentParticipationDTO`, `ClubMemberRowDTO`

### DTO pro vyhledávání
- `MemberSearchResultDTO`, `TournamentSearchResultDTO`, `ClubSearchResultDTO`

### DTO pro zápasy a výsledky
- `TournamentMatchesDTO`, `TournamentMatchDTO`, `MemberMatchesDTO`
- `MatchContestantDTO`, `CategoryResultsDTO`, `CategoryResultsMemberDTO`

### DTO pro statistiky
- `TournamentBasicStatisticsDTO`, `TournamentTatamiStatisticsDTO`, `TournamentAdditionalStatisticsDTO`

### Shuffle entity
- `SpiderShuffle` — pavoukový systém
- `TableShuffle` — tabulkový systém

### Query objekty
- `QueryParams` — page, pageSize, filters, sortField, sortAsc
- `QueryFilter` — column, filterValue
- `EntitySetDTO` — data + itemsCount (pro stránkování)

### Vlastní atribut
- `DatagridColumn` — deklarace sloupce v datagridu (typ, šířka, nadpis, řazení, filtrování, hyperlink)
