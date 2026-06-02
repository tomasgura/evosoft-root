# Datový model — Judo Výsledkový portál

## Zdroje dat

Aplikace pracuje se dvěma datovými zdroji:

1. **DWH (Data Warehouse)** — PostgreSQL, schéma `export`, materializované pohledy s příponou `mv_dataset_export_*`
2. **Hajime live API** — REST API pro živé výsledky turnaje (json)

Data z DWH jsou archivní a přepočítávaná externě. Aplikace do DWH nepíše.

---

## DWH tabulky (materializované pohledy)

| Konstanta | Tabulka v DB | Obsah |
|---|---|---|
| `DWH::TOURNAMENTS` | `export.mv_dataset_export_tournaments_tournaments_main` | Turnaje |
| `DWH::TOURNAMENT_MEMBERS` | `export.mv_dataset_export_tournament_members_tournament_members_main` | Přihlášení členové turnaje |
| `DWH::MEMBERS` | `export.mv_dataset_export_members_members_main` | Členové ČSJÚ |
| `DWH::CLUBS` | `export.mv_dataset_export_clubs_clubs_main` | Kluby |
| `DWH::MATCHES` | `export.mv_dataset_export_tournament_match_tournament_match_main` | Zápasy |
| `DWH::TOURNAMENT_SUBCATEGORIES` | `export.mv_dataset_export_tournament_subcategory_tournament_subcategory` | Podkategorie turnaje |
| `DWH::RESULTS` | `export.mv_dataset_export_tournament_results_tournament_results_main` | Výsledky |

Tabulky jsou definovány jako konstanty v `src/Repository/Database/DWH.php`.

---

## Entity

### Tournament
Hlavní entita turnaje. Čte se z `DWH::TOURNAMENTS`.

| Vlastnost | Typ | Popis |
|---|---|---|
| uid | string | Unikátní identifikátor |
| name | string | Název turnaje |
| description | string|null | Popis |
| type | string | Typ (MČR, pohár, ...) |
| status_name | string | Stav (plánovaný, probíhající, ukončený) |
| dt_start | DateTimeImmutable | Datum začátku |
| dt_end | DateTimeImmutable | Datum konce |
| club_name | string | Pořádající klub |
| address | string | Místo konání |
| director | string | Ředitel turnaje |
| is_hajime | bool | Probíhá live přes Hajime |
| is_international | bool | Mezinárodní turnaj |
| is_ranking_list | bool | Je v žebříčku |

Klíčové metody: `getState()`, `isStarted()`, `isFinished()`, `getYear()`

---

### Member
Člen ČSJÚ. Čte se z `DWH::MEMBERS`.

| Vlastnost | Typ | Popis |
|---|---|---|
| uid | string | Unikátní identifikátor |
| csju_id | string | ID v ČSJÚ systému |
| firstname | string | Jméno |
| surname | string | Příjmení |
| fullname | string | Celé jméno |
| birthyear | int | Rok narození |
| club_name | string | Název klubu |
| club_uid | string | UID klubu |
| kyu | int|null | Stupeň kyu |
| dan | int|null | Stupeň dan |
| dt_kyu_granted | DateTimeImmutable|null | Datum udělení kyu |
| dt_dan_granted | DateTimeImmutable|null | Datum udělení dan |

Metoda: `getAge()` — vypočítá věk z birthyear

---

### Club
Judistický klub. Čte se z `DWH::CLUBS`.

| Vlastnost | Typ | Popis |
|---|---|---|
| uid | string | Unikátní identifikátor |
| name | string | Název klubu |
| csju_name | string | Název v ČSJÚ |
| hajime_acronym | string | Zkratka (pro Hajime) |
| id_number | string | IČO |
| webpage | string|null | Webová stránka |
| email | string|null | Email |
| telephone | string|null | Telefon |
| country | Country | Stát (entita) |
| address_main | Address | Hlavní adresa |
| address_correspondence | Address | Korespondenční adresa |
| member_count | int | Počet členů |
| logo_url | string|null | URL loga |
| dt_upd | DateTimeImmutable | Datum poslední aktualizace |

---

### AgeCategory
Věková kategorie turnaje. Data z Hajime API nebo DWH.

| Vlastnost | Typ | Popis |
|---|---|---|
| id | int | ID kategorie |
| name | string | Název |
| description | string | Popis |
| description_short | string | Krátký popis |

Metody: `isMale()`, `isFemale()`, `isKids()`, `getMaxAge()`, `getPriority()`  
Relace: `SubCategory[]` (podkategorie)

---

### SubCategory
Podkategorie turnaje (váhová kategorie). Součást AgeCategory.

| Vlastnost | Typ | Popis |
|---|---|---|
| id | int | ID podkategorie |
| name | string | Název (např. -66 kg) |
| gender | string | Pohlaví |
| max_age | int|null | Max. věk |
| weight_limit | float|null | Váhový limit |

---

### Address
Hodnot-objekt adresy. Součást Club entity.

| Vlastnost | Popis |
|---|---|
| street | Ulice a číslo |
| city | Město |
| zip | PSČ |

---

### Country
Hodnot-objekt státu.

| Vlastnost | Popis |
|---|---|
| code | ISO kód (CZ, SK, ...) |
| name | Název státu |

---

## DTO (Data Transfer Objects)

### Pro datagrid (seznam dat v tabulce)

| DTO | Odpovídá entitě | Použití |
|---|---|---|
| TournamentRowDTO | Tournament | Řádek v seznamu turnajů |
| MemberRowDTO | Member | Řádek v seznamu členů |
| ClubRowDTO | Club | Řádek v seznamu klubů |
| TournamentMemberRowDTO | Member v turnaji | Přihlášení na turnaj |
| TournamentCategoryRowDTO | SubCategory | Kategorie turnaje |
| DatagridTournamentParticipationDTO | Tournament | Účast člena na turnajích |
| ClubMemberRowDTO | Member | Člen v detailu klubu |

### Pro vyhledávání (autocomplete)

| DTO | Pole |
|---|---|
| MemberSearchResultDTO | firstname, surname, club_uid, flag_url |
| TournamentSearchResultDTO | name, location, date |
| ClubSearchResultDTO | name, csju_name |

### Pro zápasy

| DTO | Obsah |
|---|---|
| TournamentMatchesDTO | Kolekce zápasů + statistiky turnaje |
| TournamentMatchDTO | Jeden zápas (oba zápasnící, výsledek, tatami) |
| MemberMatchesDTO | Zápasy konkrétního člena |
| MatchContestantDTO | Zápasnický záznam (jméno, klub, výsledek) |

### Pro výsledky

| DTO | Obsah |
|---|---|
| CategoryResultsDTO | Výsledky celé věkové kategorie |
| CategoryResultsMemberDTO | Výsledek konkrétního člena (pořadí, medaile) |

### Pro statistiky

| DTO | Obsah |
|---|---|
| TournamentBasicStatisticsDTO | Počty zápasnících, zápasů, kategorií |
| TournamentTatamiStatisticsDTO | Statistiky per tatami |
| TournamentAdditionalStatisticsDTO | Doplňkové metriky |

### Query objekty

| Třída | Účel |
|---|---|
| QueryParams | Parametry datagridu: page, pageSize, filters[], sortField, sortAsc |
| QueryFilter | Jeden filtr: column, filterValue |
| EntitySetDTO | Výsledek datagridu: data[], itemsCount (pro stránkování) |

---

## Shuffle entity (losování)

Pavoukový diagram nebo tabulka vylosování.

| Entita | Typ |
|---|---|
| SpiderShuffle | Pavoukový systém (spider draw) |
| TableShuffle | Tabulkový systém (round robin) |

Obě dědí z `BaseShuffleDetail`. Data přichází výhradně z Hajime live API.

---

## Vztahy mezi entitami

```
Tournament
  └── AgeCategory[]
        └── SubCategory[]
              ├── SpiderShuffle nebo TableShuffle  (live, z Hajime)
              ├── TournamentMatchDTO[]              (zápasy)
              └── CategoryResultsDTO               (výsledky)

Member
  ├── Club (přes club_uid)
  └── TournamentMatchDTO[] (jako contestant)

Club
  ├── Address (main + correspondence)
  ├── Country
  └── Member[] (přes DWH)
```

---

## Poznámky k datovému modelu

- Aplikace **nepíše** do databáze — veškerá data jsou read-only z DWH a externích API
- DWH tabulky jsou materializované pohledy — aktualizuje je externí ETL process, ne tato aplikace
- Loga klubů a výsledkové soubory jsou fyzicky na filesystému (`public/files/`), do DWH jde jen metadata
- Živá data (Hajime) nejsou v DWH — pro živé turnaje se data berou přímo z Hajime API
