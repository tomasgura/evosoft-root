# Architektonická dokumentace – Hajime

> Judo Tournament Management System – PHP / Nette 3.1+

---

## Obsah

1. [Přehled architektury](#1-přehled-architektury)
2. [Popis modulů](#2-popis-modulů)
3. [Tok requestů](#3-tok-requestů)
4. [Služby a dependency injection](#4-služby-a-dependency-injection)
5. [Databázové entity a vztahy](#5-databázové-entity-a-vztahy)
6. [Onboarding pro developera](#6-onboarding-pro-developera)

---

## 1. Přehled architektury

**Hajime** je webová aplikace pro správu judo turnajů – přihlašování závodníků, vážení, generování pavouků, řízení zápasů na tatami a zobrazování výsledků.

### Technologický stack

| Vrstva | Technologie | Verze |
|--------|-------------|-------|
| Jazyk | PHP | 8.x |
| Framework | Nette Application | 3.1+ |
| DI Container | Nette DI | 3.x |
| ORM | Nextras ORM | 4.0.6 |
| DBAL | Nextras DBAL | 4.0.5 |
| Databáze | PostgreSQL | 15 |
| Šablony | Latte | 3.0 |
| REST API | Contributte/Apitte | 0.12 |
| Fronty | RabbitMQ (contributte/rabbitmq) | 9.1 |
| Migrace DB | Hyperdrive (Liquibase) | 3.0 |
| CLI | Contributte/Console | 0.9 |
| Ladění | Tracy | 2.10+ |
| PDF | mPDF | 8.2 |

### Vrstvový model

```
┌─────────────────────────────────────────────────────────────────┐
│                          www/index.php                          │
│                     (jediný vstupní bod)                        │
└───────────────────┬─────────────────────┬───────────────────────┘
                    │                     │
          /api/rest/...            ostatní URL
                    │                     │
        ┌───────────▼────────┐   ┌────────▼──────────┐
        │  REST API vrstva   │   │  MVC Presenters   │
        │  Apitte + 16 ctrl  │   │  Latte šablony    │
        └───────────┬────────┘   └────────┬──────────┘
                    │                     │
        ┌───────────▼─────────────────────▼───────────┐
        │              Business vrstva                │
        │  DataControllers │ LogicControllers         │
        │  Services │ Algorithms │ DataStructures      │
        └───────────────────────┬─────────────────────┘
                                │
        ┌───────────────────────▼─────────────────────┐
        │          Data vrstva – Nextras ORM           │
        │     Entities │ Repositories │ Mappers        │
        └───────────────────────┬─────────────────────┘
                                │
        ┌───────────────────────▼─────────────────────┐
        │         PostgreSQL (5 schémat)               │
        │  judo │ base │ configuration │ log │ public  │
        └─────────────────────────────────────────────┘
```

---

## 2. Popis modulů

### Prezentační moduly

| Modul | URL prefix | Účel | Uživatel |
|-------|-----------|------|----------|
| `TournamentModule` | `/tournament/` | Správa turnajů, kategorií, závodníků, zápasů | Admin |
| `ScaleModule` | `/scale/` | Přihlašování a vážení závodníků | Scale operátor |
| `ScoreboardModule` | `/scoreboard/` | Živé zobrazení výsledků a skóre | Scoreboard operátor |
| `InfopanelModule` | `/infopanel/` | Informační tabule průběhu turnaje | Infopanel operátor |
| `RestApi` | `/api/rest/` | REST API (16 controllerů, JSON) | Externí klienti |
| `ApiModule` | `/api/v2/`, `/api/open/` | Starší API vrstva | Legacy klienti |
| Globální | `/` | Login, homepage, chyby | Všichni |

### Business vrstva (`app/Business/`)

```
Business/
├── Controllers/
│   ├── DataControllers/          # CRUD nad entitami (1 controller = 1 doménový objekt)
│   │   ├── AdminController
│   │   ├── CategoryController
│   │   ├── CategoryAgeController
│   │   ├── ClubController
│   │   ├── MemberController
│   │   ├── MemberCategoryController
│   │   ├── ScaleController
│   │   ├── SubCategoryController
│   │   ├── TableController
│   │   ├── TatamiController
│   │   ├── TatamiMatchController
│   │   ├── TournamentController
│   │   ├── TournamentMatchController
│   │   └── TournamentMatchDataController
│   └── LogicControllers/         # Komplexní byznys operace
│       ├── CompetitorsController
│       ├── EventController
│       ├── ScoreboardController
│       ├── ShuffleController     # Generování párovacích pavouků
│       ├── StatusController
│       ├── TatamiShuffleController
│       ├── TournamentMatchController
│       └── UserController
├── Services/
│   ├── BasicAuthenticatorService
│   ├── FlexiiAuthenticatorService
│   ├── SuperadminAuthenticatorService
│   ├── ConfigurationService
│   ├── SessionService
│   ├── MailService/
│   ├── HtmlGeneratorService
│   ├── PasswordPrintService
│   └── ShuffleService/           # Algoritmy pro generování pavouka
├── Algorithms/                   # TopSort, DFS
├── Api/                          # ApiDataBuilder (DTO builder pro REST)
├── DataStructures/               # Komplexní datové objekty (MatchList, Tournament)
├── Enums/                        # GenderEnum, TournamentTypeEnum, DrawSystemEnum, …
├── Helpers/
├── Interfaces/
└── Traits/
```

### Data vrstva (`app/Data/`)

Každá doménová složka obsahuje trojici: **Entity** + **Repository** + **Mapper**.

```
Data/
├── Orm.php                       # Centrální registr všech repozitářů
├── Tournament/
├── Member/
├── Club/
├── Admin/
├── Scale/
├── Tatami/
├── TatamiMatch/
├── Category/
├── CategoryAge/
├── SubCategory/
├── MemberCategory/
├── TournamentMatch/
├── TournamentMatchData/
├── Table/
├── SubCategoryResults/
├── InfoPanel/
└── User/                         # Value objekty (AdminUser, ScaleUser, …)
```

---

## 3. Tok requestů

### A) Web request (MVC presenter)

```
Browser
  │
  ▼
www/index.php
  │  Bootstrap::boot() → DI Container z common.neon + services.neon + local.neon
  ▼
Nette\Application\Application::run()
  │  RouterFactory::createRouter() → párování URL
  ▼
[Modul]Presenter::startup()
  │  Ověření přihlášení + oprávnění (Nette\Security\User)
  ▼
Presenter::action*($params)
  │  Volání Business vrstvy (DataController / LogicController / Service)
  ▼
Presenter::render*()
  │  Příprava proměnných pro šablonu
  ▼
Latte::render([Presenter]/[action].latte)
  │
  ▼
HTML odpověď
```

### B) REST API request

```
HTTP klient
  │
  ▼
www/index.php  ← detekuje /api/rest/ v $_SERVER['REQUEST_URI']
  │
  ▼
Contributte\Middlewares pipeline (v pořadí):
  1. TracyMiddleware          – Tracy debug bar
  2. AutoBasePathMiddleware   – detekce base path
  3. MethodOverrideMiddleware – X-HTTP-Method-Override
  4. CorsMiddleware           – CORS hlavičky
  5. TokenMiddleware          – ověření X-Api-Token → 401 při neplatném tokenu
  6. VersionMiddleware        – X-Api-Version do odpovědi
  7. ApiMiddleware            – Apitte routing (anotace @Path, @Method)
  8. LogMiddleware            – logování request/response
  │
  ▼
RestApi\Controllers\[Doména]Controller::method()
  │  Parametry z anotací (@RequestParameters, @Path)
  ▼
Business\Controllers\DataController nebo LogicController
  │
  ▼
Nextras ORM (Repository → Entity → Mapper → DBAL)
  │
  ▼
JSON odpověď (Apitte Negotiation)
```

### C) CLI command

```
php bin/console.php [command]
  │
  ▼
Bootstrap::bootForConsole() → DI Container
  │
  ▼
Contributte\Console → konkrétní Command
  │
  ▼
Hyperdrive příkazy (migrace/drop DB)
```

---

## 4. Služby a dependency injection

### Jak funguje DI v projektu

Konfigurační soubory (`.neon`) se načítají v Bootstrap.php v tomto pořadí:
```
config/common.neon    ← hlavní konfigurace, extensions, parametry
config/services.neon  ← ruční registrace + autodiscovery pravidla
config/local.neon     ← lokální přepisy (není v gitu!)
```

### Ručně registrované služby (`services.neon`)

| Alias / třída | Typ | Poznámka |
|---------------|-----|----------|
| `router` | `RouterFactory::createRouter` | factory metoda |
| `authenticator` | `BasicAuthenticatorService` | výchozí autentizátor |
| `FlexiiAuthenticatorService` | `FlexiiAuthenticatorService` | autowired: self |
| `SuperadminAuthenticatorService` | `SuperadminAuthenticatorService` | autowired: self |
| `TournamentBuilder` | `Business\DataStructures\...\TournamentBuilder` | manuálně |
| `ApiDataBuilder` | `Business\Api\ApiDataBuilder` | manuálně |

### Autodiscovery (ResourceExtension)

Projekt používá `contributte/di` pro automatické registrování služeb podle vzoru:

| Zdroj | Vzor | Zahrnuty |
|-------|------|----------|
| `app/Adapter/` | `*Adapter`, `*Factory` | Adaptery + továrny |
| `app/Business/Controllers/` | `*Controller` | Business controllery |
| `app/Business/Services/` | `*Service` | Byznys služby |
| `app/Presentation/RestApi/Controllers/` | `*Controller` (bez `BaseController`) | REST controllery |
| `app/Presentation/*/Components/` | `*Factory` | UI komponenty |

### Registrované Nette extensions

| Extension klíč | Třída | Účel |
|----------------|-------|------|
| `orm` | `Nextras\Orm\Bridges\NetteDI\OrmExtension` | ORM |
| `dbal` | `Nextras\Dbal\Bridges\NetteDI\DbalExtension` | DBAL / PostgreSQL |
| `api` | `Apitte\Core\DI\ApiExtension` | REST API routing |
| `middlewares` | `Contributte\Middlewares\DI\MiddlewaresExtension` | Middleware stack |
| `console` | `Contributte\Console\DI\ConsoleExtension` | CLI příkazy |
| `translation` | `Contributte\Translation\DI\TranslationExtension` | i18n (cs_CZ) |
| `rabbitmq` | `Contributte\RabbitMQ\DI\RabbitMQExtension` | Message fronty |
| `eda` | `Eda\Bridges\Nette\DI\EdaExtension` | Event-driven workflow |
| `hyperdrive` | `Hyperdrive\Bridges\NetteDI\HyperdriveExtension` | DB migrace |
| `flexiiConnector` | `FlexiiConnector\Bridges\NetteDI\FlexiiConnectorExtension` | Flexii API |
| `lookup` | `Lookup\DI\LookupExtension` | Lookup/číselníky |
| `selectize` | `Selectize\Form\Control\SelectizeExtension` | Selectize formuláře |
| `caching` | `Cache\DI\CacheExtension` | Cache vrstva |
| `log` | `Log\DI\LogExtension` | Logování |
| `evosoftTools` | `EvosoftTools\DI\EvosoftToolsExtension` | Interní utility |
| `resource` | `Contributte\DI\Extension\ResourceExtension` | Autodiscovery |

### Autentizace – tři mechanismy

```
/sign/in (web)     → BasicAuthenticatorService   → ověřuje Admin entitu
/scale/sign/in     → BasicAuthenticatorService   → ověřuje Scale entitu
/api/rest/**       → TokenMiddleware             → ověřuje API token z parametrů
Flexii SSO         → FlexiiAuthenticatorService  → ověřuje přes Flexii API
Superadmin         → SuperadminAuthenticatorService
```

---

## 5. Databázové entity a vztahy

### ER diagram (zjednodušený)

```
Admin ──────────────────────────────────────────── Tournament
  │  (m:n přes admin_has_tournament)                    │
  │                                    ┌────────────────┼────────────────┐
  └──── TatamiMatch ←── Tatami ◄───────┘     Category   │   CategoryAge  │
              │                               │  │       │      │         │
              │                    SubCategory│  │       │   MemberCategory
              │                         │     │  └───────┘      │
              └──── TournamentMatch ────┘     │             Member ──── Club
                         │                   └──────────────────┘
                         └──── TournamentMatchData
```

### Entity a jejich vlastnosti

#### Tournament
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `id` | int PK | |
| `uid` | string | Externě sdílený identifikátor |
| `tournament_csju_id` | string | ID v systému ČSJÚ |
| `name` | string | Název turnaje |
| `dt_tournament_start/end` | DateTimeImmutable? | Datum konání |
| `dt_term_for_registration` | DateTimeImmutable? | Uzávěrka přihlášek |
| `location`, `city`, `region`, `country` | string | Místo konání |
| `tatami_count`, `scale_count` | int | Počty zápasiš/váh |
| `type` | TournamentTypeEnum | Typ turnaje |
| `is_approved`, `enabled` | bool | Stav |
| **Vazby** | | |
| `clubs` | OneHasMany → Club | |
| `admins` | ManyHasMany → Admin | |
| `members` | OneHasMany → Member | |
| `scales` | OneHasMany → Scale | |
| `tatami` | OneHasMany → Tatami | |
| `categories` | OneHasMany → Category | |
| `categoryAges` | OneHasMany → CategoryAge | |
| `infoPanels` | OneHasMany → InfoPanel | |

---

#### Member (závodník)
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `uid` | string | Externě sdílený identifikátor |
| `member_csju_id` | string | ID v systému ČSJÚ |
| `firstname`, `lastname` | string | |
| `gender` | GenderEnum | |
| `dt_birth` | DateTimeImmutable? | Datum narození |
| `kyu`, `dan` | string? | Technická úroveň |
| **Vazby** | | |
| `tournament` | ManyToOne → Tournament | |
| `club` | ManyToOne → Club | |
| `memberCategories` | OneHasMany → MemberCategory | Přihlášky do kategorií |

---

#### MemberCategory (přihláška závodníka do kategorie)
Spojovací entita – jeden závodník může být přihlášen do více kategorií.

| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `is_approved` | bool | Přihláška schválena |
| `is_dnf` | bool | Závodník nenastoupil |
| `starting_number` | int? | Startovní číslo |
| `weight` | float? | Změřená váha |
| `seeding` | int | Nasazení |
| **Vazby** | | |
| `member` | ManyToOne → Member | |
| `category` | ManyToOne → Category | Přihlášená kategorie |
| `categoryAge` | ManyToOne → CategoryAge | Věková kategorie |
| `subcategory` | ManyToOne → SubCategory | Párovací skupina |
| `scale` | ManyToOne → Scale | Kde byl zvážen |

---

#### Category (hmotnostní kategorie)
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `weight_name` | string | Název (např. "-60 kg") |
| `weight_from`, `weight_to` | int | Rozsah váhy |
| `status` | CategoryStatusEnum? | Stav kategorie |
| `priority` | int | Pořadí zobrazení |
| **Vazby** | | |
| `tournament` | ManyToOne → Tournament | |
| `categoryAge` | ManyToOne → CategoryAge | |
| `subcategories` | OneHasMany → SubCategory | |
| `members` | OneHasMany → MemberCategory | |

---

#### CategoryAge (věková kategorie)
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `gender` | GenderEnum | |
| `age_name`, `age_name_short` | string | Název (např. "Kadeti") |
| `age_from`, `age_to` | int | Rozsah věku |
| `match_time` | int | Délka zápasu (sekundy) |
| `is_golden_score` | bool | Prodloužení povoleno |
| `golden_score_time` | int? | Délka golden score |
| `weight_tolerance` | float | Tolerancia váhy |

---

#### SubCategory (párovací skupina / pavouk)
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `draw_system` | DrawSystemEnum | Typ pavouka (Table, Spider, …) |
| `gender_split` | bool | Rozdělení podle pohlaví |
| `status` | SubCategoryStatusEnum | Stav |
| `is_repechage` | bool? | Opravné kolo |
| `weight` | float? | Výsledná váha skupiny |
| **Vazby** | | |
| `category` | ManyToOne → Category | |
| `members` | OneHasMany → MemberCategory | |
| `tournamentMatches` | OneHasMany → TournamentMatch | |

---

#### TournamentMatch (zápas v pavouku)
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `subcategory_match_number` | string | Identifikátor v pavouku |
| `status` | MatchStatusEnum | Stav zápasu |
| `is_blue_winner` | bool? | Vítěz (true=modrý, false=bílý) |
| `round` | int? | Kolo pavouka |
| `round_name` | string? | Název kola (finále, …) |
| `blue_ippon`, `blue_wazari`, `blue_shido`, … | int/bool | Skóre modrého |
| `white_ippon`, `white_wazari`, `white_shido`, … | int/bool | Skóre bílého |
| **Vazby** | | |
| `subcategory` | ManyToOne → SubCategory | |
| `tatamiMatch` | OneToOne → TatamiMatch | Kde se zápas koná |
| `memberCategoryBlue` | ManyToOne → MemberCategory | |
| `memberCategoryWhite` | ManyToOne → MemberCategory | |
| `tournamentMatchData` | OneHasMany → TournamentMatchData | Historie stavu |

---

#### TatamiMatch (slot na tatami)
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `priority` | int | Pořadí na tatami |
| **Vazby** | | |
| `tatami` | ManyToOne → Tatami | Na kterém tatami |
| `admin` | ManyToOne → Admin | Odpovědný rozhodčí |
| `tournamentMatch` | OneToOne → TournamentMatch | |

---

#### Admin
| Vlastnost | Typ | Popis |
|-----------|-----|-------|
| `full_name` | string | |
| `password` | string | Hashované heslo |
| `flexii_account` | string? | Propojení s Flexii |
| `is_super_admin` | bool | Superadmin flag |
| **Vazby** | | |
| `tournaments` | ManyHasMany → Tournament | |
| `tatamiMatches` | OneHasMany → TatamiMatch | |

---

#### TournamentMatchData
Ukládá historii změn stavu zápasu (JSON snapshot při každé změně).

| Vlastnost | Typ |
|-----------|-----|
| `match_data` | array (JsonWrapper) |
| `timestamp` | DateTimeImmutable |

---

### Přehled tabulek (PostgreSQL schéma `judo`)

| Tabulka | Entita |
|---------|--------|
| `tournament` | Tournament |
| `tournament_has_member` | Member |
| `club` | Club |
| `tournament_has_scale` | Scale |
| `tatami` | Tatami |
| `tatami_match` | TatamiMatch |
| `tournament_has_category` | Category |
| `tournament_has_category_age` | CategoryAge |
| `tournament_has_subcategory` | SubCategory |
| `tournament_has_member_has_category` | MemberCategory |
| `tournament_has_match` | TournamentMatch |
| `tournament_has_match_data` | TournamentMatchData |
| `tournament_has_table` | Table |
| `tournament_has_infopanel` | InfoPanel |
| `tournament_has_subcategory_results` | SubCategoryResults |
| `admin` | Admin |

---

## 6. Onboarding pro developera

### Doménový model jednou větou

> Turnaj má hmotnostní kategorie, do nichž se přihlašují závodníci; závodníci se vážou a rozdělují do párovacích skupin (SubCategory), kde se generuje pavouk zápasů; zápasy probíhají na tatami a jejich výsledky tvoří výsledkovou listinu.

### Doménový tok (entity)

```
Tournament
  ├── CategoryAge (věk + pohlaví, např. "Kadeti muži")
  │     └── Category (hmotnostní třída, např. "-60 kg")
  │           └── SubCategory (párovací skupina s pavoukem)
  │                 ├── MemberCategory (přihláška závodníka)
  │                 │     └── Member ──── Club
  │                 └── TournamentMatch (zápas v pavouku)
  │                       ├── TatamiMatch → Tatami
  │                       └── TournamentMatchData (log změn)
  ├── Scale (váha – závodníci se přihlašují a váží)
  ├── Tatami (zápasiště – přidělení zápasů)
  └── Admin (správce – přiřazen přes m:n)
```

### Typická implementace nové funkce

```
1. Migrace DB     resources/hyperdrive/structure/XXXX_nazev.xml
2. Entita         app/Data/[Doména]/[Doména]Entity.php
3. Mapper         app/Data/[Doména]/[Doména]Mapper.php     (tabulka + schéma)
4. Repozitář      app/Data/[Doména]/[Doména]Repository.php
5. Registrace     app/Data/Orm.php                         (přidat property)
6. DataController app/Business/Controllers/DataControllers/
7. REST endpoint  app/Presentation/RestApi/Controllers/
                  nebo
   MVC Presenter  app/Presentation/[Modul]Module/Presenters/
```

### Rozhodovací strom: DataController vs LogicController

```
Potřebuji jen CRUD?
  ├── ANO → DataController
  └── NE (složitá logika, více entit, algoritmy)
        └── LogicController + volitelně Service
```

### Klíčové soubory k pochopení projektu (v pořadí)

1. `config/common.neon` – co aplikace potřebuje a jaké má parametry
2. `app/Bootstrap.php` – inicializace DI containeru
3. `app/RouterFactory.php` – URL routing
4. `app/Data/Orm.php` – přehled všech entit/repozitářů
5. `app/Presentation/RestApi/Controllers/TournamentController.php` – vzorový REST controller
6. `app/Business/Controllers/DataControllers/TournamentController.php` – vzorový data controller
7. `app/Business/Services/ShuffleService/ShuffleService.php` – nejsložitější část (algoritmy pavouka)

### Enums (doménové výčty)

| Enum | Hodnoty |
|------|---------|
| `GenderEnum` | MALE, FEMALE, BOTH |
| `TournamentTypeEnum` | různé typy turnajů |
| `DrawSystemEnum` | Table, Spider, … (typy pavouků) |
| `CategoryStatusEnum` | stav hmotnostní kategorie |
| `SubCategoryStatusEnum` | stav párovací skupiny |
| `MatchStatusEnum` | stav zápasu |

### Typy uživatelů a jejich přístupy

| Typ | Přihlášení | Přístup |
|-----|-----------|---------|
| `AdminUser` | `/sign/in` | `TournamentModule` – plná správa |
| `ScaleUser` | `/scale/sign/in` | `ScaleModule` – vážení |
| `ScoreboardUser` | URL s heslem | `ScoreboardModule` – jen čtení |
| `InfoPanelUser` | URL s heslem | `InfopanelModule` – jen čtení |
| `SuperAdminUser` | SuperAdmin login | Cross-tournament přístup |

### Časté chyby a jejich řešení

| Problém | Příčina | Řešení |
|---------|---------|--------|
| `ServiceNotFoundException` | Třída není autowired | Přidat do `services.neon` nebo splnit podmínky autodiscovery |
| Tracy 500 bez detailu | Debug vypnutý | Přidat `.debug` soubor do root nebo `tracy: debugMode: true` v `local.neon` |
| Nette routing 404 | Špatný název presenteru/akce | Zkontrolovat `RouterFactory.php` a název třídy/metody |
| ORM mapping error | Špatná tabulka/schéma | Zkontrolovat `Mapper.php` – metodu `getTableName()` |
| API 401 Unauthorized | Chybí token | Hlavička `X-Api-Token` nebo `?token=` parametr |
| PHPStan error v CI | Porušení Level 8 typů | Spustit `composer phpstan-app` lokálně před push |
| `local.neon` chybí | Není v gitu | Zkopírovat `config/local.example.neon` a vyplnit |

### Příkazy pro každodenní vývoj

```bash
composer phpstan-app          # statická analýza (musí projít před MR)
composer cs-app               # kontrola code style
composer cbf-app-extreme      # autofix code style

php bin/console.php hyperdrive:start postgre              # spustit migrace
php bin/console.php hyperdrive:procedure postgre dropPostgre  # drop DB (dev)

make reload                   # drop + znovu inicializovat DB
make phpstan                  # alias pro phpstan
```

---

*Vygenerováno: 2026-05-31*
je dně### Chci udělat uživatelskou dokumentaci
```prompt
Projdi celý projekt a vytvoř uživatelskou dokumentaci:
- k čemu slouží
- jaký je workflow
- jaké jsou validace
- co dělají tlačítka
- možné chyby
Piš česky a jednak do markdown a jednak do strukturovaného html
vše ulož do adresáře doc

```

### Chci udělat programátorskou dokumentaci
Potřebuju vědět:
Architekturu
- jaký framework
- dependency injection
- ORM
- routing
- cron joby
- messaging
- API

Moduly
- pokud jsou tak co dělá jaká část
- entry pointy
- services / služby
- repository
- DTO
- eventy

Datový model
- entity
- tabulky
- vazby

Integrace
- externí API
- webhooky
- emaily
- exporty/importy

Možná nechat vytvořit make file pro snazší správu projektu...
Piš česky a jednak do markdown a jednak do strukturovaného html
vše ulož do adresáře doc

