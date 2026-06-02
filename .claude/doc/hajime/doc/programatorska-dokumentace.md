# Programátorská dokumentace – Hajime

> Judo Tournament Management System  
> Verze dokumentace: 2026-05-31

---

## Obsah

1. [Architektura](#1-architektura)
2. [Moduly a entry pointy](#2-moduly-a-entry-pointy)
3. [Business vrstva](#3-business-vrstva)
4. [Data vrstva – ORM](#4-data-vrstva--orm)
5. [Datový model](#5-datový-model)
6. [REST API](#6-rest-api)
7. [Integrace](#7-integrace)
8. [Dependency Injection a konfigurace](#8-dependency-injection-a-konfigurace)
9. [Autentizace](#9-autentizace)
10. [Migrace databáze](#10-migrace-databáze)
11. [CLI příkazy](#11-cli-příkazy)
12. [Onboarding a vývoj](#12-onboarding-a-vývoj)

---

## 1. Architektura

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
| Message broker | RabbitMQ (contributte/rabbitmq) | 9.1 |
| Event-driven | evosoftcz/eda | - |
| Migrace DB | Hyperdrive (Liquibase) | 3.0 |
| CLI | Contributte/Console | 0.9 |
| Ladění | Tracy | 2.10+ |
| PDF | mPDF | 8.2 |
| Statická analýza | PHPStan | Level 8 |

### Vrstvový model

```
┌─────────────────────────────────────────────────────────────────┐
│                          www/index.php                          │
│                     (jediný vstupní bod HTTP)                   │
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

### Tok webového requestu (MVC)

```
Browser
  → www/index.php
  → Bootstrap::boot() → DI Container (common.neon + services.neon + local.neon)
  → Nette\Application\Application::run()
  → RouterFactory::createRouter() → párování URL
  → [Modul]Presenter::startup()   → autorizace (Nette\Security\User)
  → Presenter::action*($params)   → business logika
  → Presenter::render*()          → příprava proměnných
  → Latte::render(*.latte)
  → HTML odpověď
```

### Tok REST API requestu

```
HTTP klient
  → www/index.php (detekuje /api/rest/ v $_SERVER['REQUEST_URI'])
  → Contributte\Middlewares pipeline:
      1. TracyMiddleware          – Tracy debug bar
      2. AutoBasePathMiddleware   – detekce base path
      3. MethodOverrideMiddleware – X-HTTP-Method-Override
      4. CorsMiddleware           – CORS hlavičky
      5. TokenMiddleware          – ověření X-Api-Token → 401
      6. VersionMiddleware        – X-Api-Version do odpovědi
      7. ApiMiddleware            – Apitte routing (#[Path], #[Method])
      8. LogMiddleware            – logování request/response
  → RestApi\Controllers\[Doména]Controller::method()
  → Business\Controllers\DataController nebo LogicController
  → Nextras ORM → PostgreSQL
  → JSON odpověď
```

### Tok CLI commandu

```
php bin/console.php [command]
  → Bootstrap::bootForConsole() → DI Container
  → Contributte\Console\Application
  → konkrétní Command (Hyperdrive migrace, …)
```

---

## 2. Moduly a entry pointy

### HTTP vstupní bod

- **`www/index.php`** – jediný HTTP vstupní bod, volá `Bootstrap::boot()`

### CLI vstupní bod

- **`bin/console.php`** – CLI vstupní bod, volá `Bootstrap::bootForConsole()`

### Prezentační moduly

| Modul | Namespace | URL prefix | Účel |
|-------|-----------|-----------|------|
| `TournamentModule` | `App\Presentation\TournamentModule` | `/tournament/` | Plná správa turnaje |
| `ScaleModule` | `App\Presentation\ScaleModule` | `/scale/` | Vážení závodníků |
| `ScoreboardModule` | `App\Presentation\ScoreboardModule` | `/scoreboard/` | Živé výsledky |
| `InfopanelModule` | `App\Presentation\InfopanelModule` | `/infopanel/` | Informační tabule |
| `RestApi` | `App\Presentation\RestApi` | `/api/rest/` | REST API (Apitte) |
| `ApiModule` | `App\Presentation\ApiModule` | `/api/v2/`, `/api/open/` | Starší API vrstva |
| Globální | `App\Presentation\Presenters` | `/` | Login, homepage, chyby |

### Routing (`app/RouterFactory.php`)

URL jsou mapovány v tomto pořadí (první shoda vyhrává):

```php
api/open/<presenter>/<id>[/<action>[/<sid>]]  → Api\TournamentPresenter
api/v2/tournament/<id>                        → Api\TournamentV2Presenter
infopanel/<presenter>/<action>[/<id>]         → Infopanel modul
scale/<presenter>/<action>[/<id>]             → Scale modul
scoreboard/<presenter>/<action>[/<id>]        → Scoreboard modul
tournament/<presenter>[/<action>][/<id>]      → Tournament modul
<presenter>/<action>[/<id>]                   → Globální (Homepage, Sign, Error)
```

### Mapping presenter tříd

```neon
application:
    mapping:
        *: App\Presentation\*Module\Presenters\*Presenter
```

Příklad: URL `/tournament/homepage/default` → `App\Presentation\TournamentModule\Presenters\HomepagePresenter::renderDefault()`

---

## 3. Business vrstva

Adresář: `app/Business/`

### DataControllers (`app/Business/Controllers/DataControllers/`)

Vzor 1 controller = 1 doménový objekt. Obsahují CRUD operace nad entitami.

| Controller | Entita | Popis |
|------------|--------|-------|
| `AdminController` | Admin | Správa adminů |
| `CategoryController` | Category | Hmotnostní kategorie |
| `CategoryAgeController` | CategoryAge | Věkové kategorie |
| `ClubController` | Club | Kluby |
| `MemberController` | Member | Závodníci |
| `MemberCategoryController` | MemberCategory | Přihlášky závodníků |
| `ScaleController` | Scale | Váhy |
| `SubCategoryController` | SubCategory | Párovací skupiny |
| `SubCategoryResultsController` | SubCategoryResults | Výsledky subcategorií |
| `TableController` | Table | Tabulkové pohledy |
| `TatamiController` | Tatami | Zápaziště |
| `TatamiMatchController` | TatamiMatch | Sloty na tatami |
| `TournamentController` | Tournament | Turnaje |
| `TournamentMatchController` | TournamentMatch | Zápasy v pavouku |
| `TournamentMatchDataController` | TournamentMatchData | Data zápasů |

### LogicControllers (`app/Business/Controllers/LogicControllers/`)

Komplexní byznys operace přesahující jeden doménový objekt.

| Controller | Popis |
|------------|-------|
| `CompetitorsController` | Správa soutěžících v kontextu turnaje |
| `EventController` | Zpracování událostí (EDA) |
| `ScoreboardController` | Logika scoreboardu |
| `ShuffleController` | Generování pavouků (využívá ShuffleService + algoritmy) |
| `StatusController` | Správa stavů kategorií a subcategorií |
| `TatamiShuffleController` | Přidělování zápasů na tatami |
| `TournamentMatchController` | Logika průběhu zápasů |
| `UserController` | Správa sessions a uživatelů |

### Services (`app/Business/Services/`)

Průřezové služby autowirované přes DI.

| Služba | Popis |
|--------|-------|
| `BasicAuthenticatorService` | Autentizace adminů a scale uživatelů |
| `FlexiiAuthenticatorService` | Autentizace přes Flexii SSO |
| `SuperadminAuthenticatorService` | Autentizace superadminů |
| `ConfigurationService` | Čtení konfigurace aplikace |
| `SessionService` | Správa sessions (login/logout logika) |
| `MailService/MailService` | Odesílání e-mailů (Nette Mail + SMTP) |
| `HtmlGeneratorService` | Generování HTML výstupů |
| `PasswordPrintService` | Generování PDF s přihlašovacími hesly (mPDF) |
| `ShuffleService/ShuffleService` | Algoritmy pro generování turnajového pavouka |

### Algoritmy (`app/Business/Algorithm/`)

| Algoritmus | Popis |
|------------|-------|
| `DFS/Dfs` | Depth-First Search – prohledávání grafu pavouka |
| `TopSort/TopSort` | Topologické třídění – řazení zápasů bez cyklů |

### DataStructures (`app/Business/DataStructures/`)

Komplexní datové objekty (DTO / view modely) pro prezentační vrstvu:

- `MatchList/Tournament/TournamentBuilder` – sestavuje celý turnaj jako datový strom
- `MatchList/TournamentMatch` – reprezentace zápasu v pavouku
- `MatchList/ResultPair` – dvojice závodníků v zápasu

### Enums (`app/Business/Enums/`)

| Enum | Hodnoty | Popis |
|------|---------|-------|
| `GenderEnum` | MALE, FEMALE, BOTH | Pohlaví |
| `TournamentTypeEnum` | různé typy | Typ turnaje |
| `DrawSystemEnum` | Table, Spider, … | Typ turnajového pavouka |
| `CategoryStatusEnum` | různé stavy | Stav hmotnostní kategorie |
| `SubCategoryStatusEnum` | STATUS_SHUFFLED, … | Stav párovací skupiny |
| `MatchStatusEnum` | různé stavy | Stav zápasu |

---

## 4. Data vrstva – ORM

Adresář: `app/Data/`

### Struktura

Každá doménová složka obsahuje trojici:

```
Data/
└── [Doména]/
    ├── [Doména]Entity.php      # Entita s typed properties a vazbami
    ├── [Doména]Repository.php  # Repozitář s query metodami
    └── [Doména]Mapper.php      # Mapování na DB tabulku/schéma
```

### Centrální registr – Orm.php

```php
// app/Data/Orm.php - přístupový bod ke všem repozitářům
$this->orm->tournaments->findAll();
$this->orm->members->getById($id);
$this->orm->memberCategories->findBy(['member' => $member]);
```

### Dostupné repozitáře (vlastnosti `Orm.php`)

`tournaments`, `members`, `clubs`, `admins`, `scales`, `tatamis`, `tatamiMatches`, `categories`, `categoryAges`, `subCategories`, `memberCategories`, `tournamentMatches`, `tournamentMatchData`, `tables`, `subCategoryResults`, `infoPanels`

### Typické operace s repozitářem

```php
// Získat jednu entitu
$entity = $repository->getById($id);           // Entity nebo výjimka
$entity = $repository->findBy(['uid' => $uid])->fetch();

// Získat kolekci
$collection = $repository->findAll();
$collection = $repository->findBy(['tournament' => $tournament]);

// Uložit
$this->orm->persistAndFlush($entity);

// Smazat
$this->orm->removeAndFlush($entity);
```

---

## 5. Datový model

### ER diagram (zjednodušený)

```
Admin ─────────────────────────────────────── Tournament
  │  (m:n přes admin_has_tournament)               │
  │                              ┌─────────────────┼──────────────────┐
  └── TatamiMatch ◄─── Tatami ◄──┘    CategoryAge  │   Category        │
           │                               │        │     │             │
           │                            SubCategory │     │             │
           │                               │        └─────┘        MemberCategory
           └── TournamentMatch ────────────┘                            │
                    │                                               Member ─── Club
                    └── TournamentMatchData
```

### Entity a jejich tabulky

| Entita | Tabulka (schéma `judo`) | Klíčové sloupce |
|--------|------------------------|-----------------|
| `Tournament` | `tournament` | `uid`, `name`, `type`, `is_approved`, `enabled`, `dt_tournament_start` |
| `Member` | `tournament_has_member` | `uid`, `member_csju_id`, `firstname`, `lastname`, `gender`, `dt_birth` |
| `Club` | `club` | `name`, `club_csju_id` |
| `Admin` | `admin` | `full_name`, `password`, `flexii_account`, `is_super_admin` |
| `Scale` | `tournament_has_scale` | `id_tournament`, heslo pro přihlášení |
| `Tatami` | `tatami` | `id_tournament`, pořadí |
| `TatamiMatch` | `tatami_match` | `priority`, `id_tatami`, `id_admin`, `id_tournament_match` |
| `Category` | `tournament_has_category` | `weight_name`, `weight_from`, `weight_to`, `status`, `priority` |
| `CategoryAge` | `tournament_has_category_age` | `gender`, `age_name`, `age_from`, `age_to`, `match_time`, `is_golden_score`, `weight_tolerance` |
| `SubCategory` | `tournament_has_subcategory` | `draw_system`, `status`, `is_repechage`, `weight` |
| `MemberCategory` | `tournament_has_member_has_category` | `is_approved`, `is_dnf`, `weight`, `starting_number`, `seeding` |
| `TournamentMatch` | `tournament_has_match` | `subcategory_match_number`, `status`, `is_blue_winner`, `round`, skóre (ippon/wazari/shido) |
| `TournamentMatchData` | `tournament_has_match_data` | `match_data` (JSON), `timestamp` |
| `InfoPanel` | `tournament_has_infopanel` | heslo pro přihlášení |
| `SubCategoryResults` | `tournament_has_subcategory_results` | výsledky párovací skupiny |

### PostgreSQL schémata

| Schéma | Obsah |
|--------|-------|
| `judo` | Hlavní aplikační data (turnaje, závodníci, zápasy) |
| `base` | Základní číselníky |
| `configuration` | Konfigurační záznamy |
| `log` | Aplikační logy |
| `public` | PostgreSQL výchozí |

### Detail důležitých entit

#### Tournament – klíčové vazby

```
Tournament (1)
  ├── Category (n)         – hmotnostní kategorie
  │     └── CategoryAge    – věková kategorie
  │           └── SubCategory – párovací skupina
  │                 ├── MemberCategory – přihláška závodníka
  │                 │     └── Member ─── Club
  │                 └── TournamentMatch – zápas
  │                       ├── TatamiMatch → Tatami
  │                       └── TournamentMatchData
  ├── Scale (n)            – váhy
  ├── Tatami (n)           – zápaziště
  ├── Admin (m:n)          – správci
  └── InfoPanel (n)        – informační panely
```

#### MemberCategory – spojovací entita

Závodník může být přihlášen do více kategorií. Tato entita nese:
- `weight` – naměřená váha
- `is_approved` – schválení přihlášky (po vážení)
- `is_dnf` – závodník nenastoupil
- `starting_number` – startovní číslo
- `seeding` – nasazení v pavouku

#### TournamentMatch – skóre

Entita ukládá výsledek zápasu přímo v sloupcích:
- `blue_ippon`, `blue_wazari`, `blue_shido`, `blue_hansoku_make`
- `white_ippon`, `white_wazari`, `white_shido`, `white_hansoku_make`
- `is_blue_winner` (true = modrý vyhrál, false = bílý)
- `round` a `round_name` (pořadí kola a název, např. „Final", „SF", „R8")

#### TournamentMatchData – audit log

Ukládá JSON snapshot stavu zápasu při každé změně (historie výsledků).

---

## 6. REST API

### Přehled

- **Base URL:** `/api/rest/`
- **Autentizace:** HTTP hlavička `X-Api-Token: <token>` nebo query parametr `?token=<token>`
- **Tokeny** jsou konfigurovány v `config/local.neon` → `parameters.apiTokens`
- **OpenAPI dokumentace:** `/api/rest/doc` (pouze v debug módu)
- **Format odpovědi:** JSON (Apitte Negotiation)

### Middleware stack (v pořadí)

1. `TracyMiddleware` – Tracy debug bar
2. `AutoBasePathMiddleware` – detekce base path
3. `MethodOverrideMiddleware` – `X-HTTP-Method-Override` hlavička
4. `CorsMiddleware` – CORS hlavičky
5. `TokenMiddleware` – ověření tokenu → 401 při neplatném
6. `VersionMiddleware` – přidá `X-Api-Version` do odpovědi
7. `ApiMiddleware` – Apitte routing podle PHP atributů `#[Path]`, `#[Method]`
8. `LogMiddleware` – logování request/response

### Endpointy

| Metoda | Cesta | Controller | Popis |
|--------|-------|------------|-------|
| GET | `/api/rest/tournament/list` | TournamentController | Všechny aktivní turnaje |
| GET | `/api/rest/tournament/{uid}` | TournamentController | Detail turnaje |
| PUT | `/api/rest/tournament/{uid}/approve/{approved}` | TournamentController | Schválení/zrušení turnaje |
| POST | `/api/rest/tournament` | TournamentController | Vytvoření turnaje |
| PUT | `/api/rest/tournament/{uid}` | TournamentController | Aktualizace turnaje |
| GET | `/api/rest/member/list` | MemberController | Všichni závodníci |
| GET | `/api/rest/member/{tournament_uid}/{uid}` | MemberController | Detail závodníka |
| GET | `/api/rest/category/list` | CategoryController | Všechny kategorie |
| GET | `/api/rest/category/{id}` | CategoryController | Detail kategorie |
| GET | `/api/rest/category-age/list` | CategoryAgeController | Věkové kategorie |
| GET | `/api/rest/subcategory/list` | SubCategoryController | Párovací skupiny |
| GET | `/api/rest/subcategory/{id}` | SubCategoryController | Detail skupiny |
| GET | `/api/rest/tatami/list` | TatamiController | Zápaziště |
| GET | `/api/rest/tatami-match/list` | TatamiMatchController | Všechny sloty na tatami |
| GET | `/api/rest/tatami-match/{id}` | TatamiMatchController | Detail slotu |
| GET | `/api/rest/tournament-match/list` | TournamentMatchController | Zápasy |
| GET | `/api/rest/tournament-match/{id}` | TournamentMatchController | Detail zápasu |
| GET | `/api/rest/tournament-match-data/list` | TournamentMatchDataController | Data zápasů |
| GET | `/api/rest/club/list` | ClubController | Kluby |
| GET | `/api/rest/member-category/list` | MemberCategoryController | Přihlášky závodníků |
| GET | `/api/rest/scale/list` | ScaleController | Váhy |
| GET | `/api/rest/table/list` | TableController | Tabulky |
| GET | `/api/rest/admin/list` | AdminController | Admini |

### Příklad implementace REST controlleru

```php
#[Path('/tournament')]
#[Tag('Tournaments')]
final class TournamentController extends BaseController
{
    #[Path('/list')]
    #[Method(IRequest::Get)]
    #[Negotiation('json', true)]
    #[Response('Success', '200')]
    public function list(ApiRequest $request, ApiResponse $response): ApiResponse
    {
        $list = $this->tournamentController->getActiveEntityCollection()->fetchAll();
        return $this->successEntityCollection($response, $list);
    }
}
```

### Starší API (`ApiModule`)

Paralelně existuje starší API vrstva přístupná přes:
- `/api/open/<presenter>/<id>[/<action>[/<sid>]]` → `ApiModule\TournamentPresenter`
- `/api/v2/tournament/<id>` → `ApiModule\TournamentV2Presenter`

> **Poznámka:** Tato vrstva je legacy a zvyšuje maintenance cost. Doporučeno postupně migrovat na Apitte REST API.

---

## 7. Integrace

### Flexii (enterprise platforma)

- **Balíček:** `evosoftcz/flexii-connector`
- **Účel:** SSO autentizace uživatelů, synchronizace závodníků z ČSJÚ
- **Konfigurace:**
  ```neon
  flexiiConnector:
      api:
          url: %flexiiConnector.url%
          token: %flexiiConnector.token%
      crypto:
          enabled: %flexiiConnector.crypto%
          iv: %flexiiConnector.iv%
          secret: %flexiiConnector.secret%
  ```
- **Šifrování:** AES (IV + secret)
- **Driver:** `FlexiiConnector\Driver` – injektován přes DI

### RabbitMQ (message broker)

- **Balíček:** `contributte/rabbitmq`
- **Účel:** Asynchronní zpracování eventů a jobů
- **Konfigurace:** `rabbitmq_connection`, `rabbitmq_queues_url` v `config/local.neon`
- **Tracy panel:** integrovaný diagnostický panel

> **Riziko:** Pokud je RabbitMQ nedostupné, chování závisí na fallback logice v jednotlivých konzumentech.

### EDA – Event-Driven Architecture

- **Balíček:** `evosoftcz/eda`
- **Účel:** Workflow zpracování na bázi DB eventů (PostgreSQL driver)
- **Integrace:** Tracy debug panel pro EDA, `EventController` v business vrstvě
- **Konfigurace:** `eda:` sekce v `common.neon` (sdílené DB připojení)

### Rights systém

- **Balíček:** `evosoftcz/rights`
- **Účel:** Granulární kontrola oprávnění přístupu k modulům
- **Použití:** `Rights::RIGHTS_MODULE_TOURNAMENT`, `Rights::RIGHTS_MODULE_SCALE` apod. v `startup()` presenterů

### SMTP – e-maily

- Nette Mail s SMTP backendem
- **Service:** `MailService` – šablonové e-maily (notifikace závodníků)
- **Konfigurace:**
  ```neon
  mail:
      smtp: true
      host: %mailer.host%
      username: %mailer.username%
      password: %mailer.password%
      secure: %mailer.secure%
  ```

### PDF generátor

- **Balíček:** `mpdf/mpdf`
- **Service:** `PasswordPrintService` – generuje PDF s přihlašovacími hesly pro scale/scoreboard/infopanel
- **Service:** `HtmlGeneratorService` – pomocné HTML generování

### Hyperdrive – DB migrace

- **Balíček:** interní `evosoftcz/hyperdrive` (Liquibase-based, XML changesets)
- **Umístění:** `resources/hyperdrive/`
  - `structure/` – DDL migrace (schéma)
  - `basic-data/` – povinná aplikační data
  - `dummy-data/` – vývojová testovací data (pouze demo mód)
  - `configurations/` – konfigurační záznamy
  - `version/` – verze
- **Spuštění:** `php bin/console.php hyperdrive:start postgre`

---

## 8. Dependency Injection a konfigurace

### Pořadí načítání konfiguračních souborů

```
config/common.neon    ← hlavní konfigurace, extensions, parametry
config/services.neon  ← ruční registrace + autodiscovery pravidla
config/local.neon     ← lokální přepisy (není v gitu!)
```

### Autodiscovery (ResourceExtension)

Projekt využívá `contributte/di` pro automatické registrování:

| Zdroj | Vzor | Popis |
|-------|------|-------|
| `app/Adapter/` | `*Adapter`, `*Factory` | Adaptery a továrny |
| `app/Business/Controllers/` | `*Controller` | Business controllery |
| `app/Business/Services/` | `*Service` | Byznys služby |
| `app/Presentation/RestApi/Controllers/` | `*Controller` (bez `BaseController`) | REST controllery |
| `app/Presentation/*/Components/` | `*Factory` | UI komponenty |

### Ručně registrované služby

```neon
services:
    router: App\RouterFactory::createRouter
    authenticator: App\Business\Services\BasicAuthenticatorService
    -
        create: App\Business\Services\FlexiiAuthenticatorService
        autowired: self
    -
        create: App\Business\Services\SuperadminAuthenticatorService
        autowired: self
    - App\Business\DataStructures\MatchList\Tournament\TournamentBuilder
    - App\Business\Api\ApiDataBuilder
```

### Nette extensions

| Klíč | Třída | Účel |
|------|-------|------|
| `orm` | `Nextras\Orm\Bridges\NetteDI\OrmExtension` | ORM |
| `dbal` | `Nextras\Dbal\Bridges\NetteDI\DbalExtension` | DBAL |
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

---

## 9. Autentizace

Systém používá tři odlišné mechanismy autentizace a pět typů uživatelů.

### Mechanismy

```
/sign/in (web)     → BasicAuthenticatorService    → ověřuje Admin entitu v DB
/scale/sign/in     → BasicAuthenticatorService    → ověřuje Scale entitu v DB
/api/rest/**       → TokenMiddleware              → ověřuje API token z parametrů
Flexii SSO         → FlexiiAuthenticatorService   → ověřuje přes Flexii API
Superadmin         → SuperadminAuthenticatorService
```

### Typy uživatelů

| Třída | Přihlášení | Přístup |
|-------|-----------|---------|
| `AdminUser` | `/sign/in` | `TournamentModule` – plná správa |
| `ScaleUser` | `/scale/sign/in` | `ScaleModule` – vážení |
| `ScoreboardUser` | URL s heslem | `ScoreboardModule` – jen čtení |
| `InfoPanelUser` | URL s heslem | `InfopanelModule` – jen čtení |
| `SuperAdminUser` | SuperAdmin login | Cross-tournament přístup |

### Autorizace v presenterech

```php
// BasePresenter TournamentModule
public function startup(): void
{
    parent::startup();
    if (!($this->getUser()->isLoggedIn()
        && $this->getUser()->isAllowed(Rights::RIGHTS_MODULE_TOURNAMENT))) {
        $this->redirect(':Sign:in');
    }
}
```

---

## 10. Migrace databáze

### Nástroj: Hyperdrive (Liquibase)

XML changesets v `resources/hyperdrive/structure/`. Skupiny migrací:

```
resources/hyperdrive/
├── structure/          # DDL – tabulky, indexy, FK
├── basic-data/         # Povinná aplikační data
├── dummy-data/         # Demo/testovací data (jen demo mód)
├── configurations/     # Konfigurační záznamy
└── version/            # Verze schématu
```

### Příkazy

```bash
# Aplikovat nové changesets
php bin/console.php hyperdrive:start postgre

# Smazat celou DB (dev only!)
php bin/console.php hyperdrive:procedure postgre dropPostgre

# Zkratky přes Makefile
make load     # hyperdrive:start postgre
make reload   # drop + load (kompletní reset DB)
```

### Přidání nové migrace

1. Vytvořit XML changeset v `resources/hyperdrive/structure/XXXX_nazev_zmeny.xml`
2. Spustit `php bin/console.php hyperdrive:start postgre`
3. Ověřit, že schéma souhlasí s ORM Mapperem nové entity

---

## 11. CLI příkazy

### Spuštění

```bash
php bin/console.php [příkaz] [parametry]
```

### Dostupné příkazy

| Příkaz | Popis |
|--------|-------|
| `hyperdrive:start postgre` | Aplikuje všechny čekající DB migrace |
| `hyperdrive:procedure postgre dropPostgre` | Smaže celou databázi |
| `list` | Zobrazí všechny dostupné příkazy (Contributte/Console) |

---

## 12. Onboarding a vývoj

### Nastavení prostředí

```bash
# 1. Konfigurovat prostředí
cp config/local.example.neon config/local.neon
# Vyplnit DB připojení a Flexii token

# 2. Spustit Docker
docker-compose up -d

# 3. Nainstalovat PHP závislosti
composer install

# 4. Inicializovat DB
php bin/console.php hyperdrive:start postgre
# nebo make load

# 5. Ověřit – otevřít http://judo.loc
```

### Klíčové soubory k pochopení projektu (v pořadí)

1. `config/common.neon` – co aplikace potřebuje a jaké má parametry
2. `app/Bootstrap.php` – inicializace DI containeru
3. `app/RouterFactory.php` – URL routing
4. `app/Data/Orm.php` – přehled všech entit a repozitářů
5. `app/Presentation/RestApi/Controllers/TournamentController.php` – vzorový REST controller
6. `app/Business/Controllers/DataControllers/TournamentController.php` – vzorový data controller
7. `app/Business/Services/ShuffleService/ShuffleService.php` – nejsložitější část (algoritmy pavouka)

### Typický pattern implementace nové funkce

```
1. DB migrace     resources/hyperdrive/structure/XXXX_nazev.xml
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
Potřebuji jen CRUD nad jednou entitou?
  ├── ANO → DataController
  └── NE (složitá logika, více entit, algoritmy)
        └── LogicController + volitelně Service
```

### Kódové standardy

```bash
# Statická analýza PHPStan Level 8 – POVINNÉ před každým MR
composer phpstan-app

# Kontrola code style
composer cs-app

# Autofix code style
composer cbf-app-extreme
```

### Časté chyby

| Problém | Příčina | Řešení |
|---------|---------|--------|
| `ServiceNotFoundException` | Třída není autowired | Přidat do `services.neon` nebo splnit podmínky autodiscovery |
| Tracy 500 bez detailu | Debug vypnutý | `touch app/.debug` nebo `tracy: debugMode: true` v `local.neon` |
| Nette routing 404 | Špatný název presenteru/akce | Zkontrolovat `RouterFactory.php` a název třídy/metody |
| ORM mapping error | Špatná tabulka/schéma | Zkontrolovat `Mapper.php` – metodu `getTableName()` |
| API 401 Unauthorized | Chybí token | Hlavička `X-Api-Token` nebo `?token=` parametr |
| PHPStan error v CI | Porušení Level 8 typů | Spustit `composer phpstan-app` lokálně před push |
| `local.neon` chybí | Není v gitu | Zkopírovat `config/local.example.neon` a vyplnit |
| RabbitMQ nedostupné | Výpadek brokeru | Zkontrolovat Docker kontejner, fallback logiku v konzumentech |

### Rizikové oblasti kódu

| Oblast | Riziko | Poznámka |
|--------|--------|----------|
| `ShuffleService` + `DFS` + `TopSort` | Složitost algoritmu pavouka | Netriviální logika, chybí unit testy edge cases |
| `ApiModule` (starší API) | Paralelní existence dvou API systémů | Legacy vrstva, zvyšuje maintenance cost |
| Dev-master závislosti | `contributte/forms-multiplier`, `evosoftcz/tools` | Nestabilní větve mohou způsobit breakage po `composer update` |
| Multi-schema PostgreSQL | `search_path` na 5 schématech | Při ladění SQL nutno znát správné schéma |
| Tři autentizační mechanismy | Pět typů uživatelů | Nutno dobře rozlišit, který flow platí pro které UI |

---

*Dokumentace vygenerována: 2026-05-31*