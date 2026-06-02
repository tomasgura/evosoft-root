# Architektonická analýza – Hajime (Judo Tournament System)

## 1. Přehled architektury

**Hajime** je webová aplikace pro správu judo turnajů. Jedná se o vícevrstvý PHP monolitický projekt postavený na frameworku **Nette 3.1+** s REST API rozhraním.

```
┌─────────────────────────────────────────────────────────────────┐
│                          www/index.php                          │
│                   (jediný vstupní bod HTTP)                     │
└───────────────────┬─────────────────────┬───────────────────────┘
                    │                     │
          /api/rest/...            ostatní URL
                    │                     │
        ┌───────────▼────────┐   ┌────────▼──────────┐
        │  REST API vrstva   │   │  MVC Presenters   │
        │ (Apitte framework) │   │ (Nette\Application)│
        └───────────┬────────┘   └────────┬──────────┘
                    │                     │
        ┌───────────▼─────────────────────▼───────────┐
        │           Business vrstva                   │
        │  DataControllers │ LogicControllers         │
        │  Services │ Algorithms │ DataStructures      │
        └───────────────────────┬─────────────────────┘
                                │
        ┌───────────────────────▼─────────────────────┐
        │           Data vrstva (Nextras ORM)          │
        │     Entities │ Repositories │ Mappers        │
        └───────────────────────┬─────────────────────┘
                                │
        ┌───────────────────────▼─────────────────────┐
        │              PostgreSQL databáze             │
        │     (schémata: judo, base, configuration,    │
        │              log, public)                   │
        └─────────────────────────────────────────────┘
```

**Klíčové technologie:**

| Vrstva | Technologie |
|--------|-------------|
| Framework | Nette 3.1+ |
| ORM | Nextras ORM 4.0 |
| DBAL | Nextras DBAL 4.0 |
| Databáze | PostgreSQL |
| Templating | Latte 3.0 |
| REST API | Contributte/Apitte 0.12 |
| Fronty | RabbitMQ (contributte/rabbitmq) |
| Migrace DB | Liquibase/Hyperdrive |
| CLI | contributte/console |
| Debugging | Tracy |

---

## 2. Hlavní moduly

### Prezentační moduly (`app/Presentation/`)

| Modul | URL prefix | Účel |
|-------|-----------|------|
| `TournamentModule` | `/tournament/` | Správa turnajů, kategorií, zápasů |
| `ScaleModule` | `/scale/` | Vážení závodníků |
| `ScoreboardModule` | `/scoreboard/` | Zobrazení výsledků |
| `InfopanelModule` | `/infopanel/` | Informační tabule |
| `RestApi` | `/api/rest/` | REST API (16 controllerů) |
| `ApiModule` | `/api/v2/`, `/api/open/` | Starší API |
| Globální | `/` | Login, homepage, chyby |

### Business vrstva (`app/Business/`)

```
Business/
├── Controllers/
│   ├── DataControllers/   # CRUD operace nad entitami
│   └── LogicControllers/  # Komplexní byznys logika
├── Services/              # Průřezové služby
├── Algorithms/            # TopSort, DFS (generování pavouka)
├── DataStructures/        # Komplexní datové objekty
├── Enums/                 # Doménové výčty
└── Helpers/               # Utility
```

### Data vrstva (`app/Data/`)

15+ repozitářů pokrývajících:
- Turnaje, kategorie, věkové kategorie
- Závodníci, kluby, přihlášky
- Tatami (zápasiště), zápasy, výsledky
- Váhy, vážení
- Administrátoři, info panely

---

## 3. Tok requestu

### A) Web request (MVC)

```
1. www/index.php
2. Bootstrap::boot() → Nette\Configurator → DI Container
3. Nette\Application\Application::run()
4. RouterFactory → párování URL na Presenter:Action
5. Presenter::startup() → autorizace
6. Presenter::action*() → business logika
7. Presenter::render*() → příprava dat pro šablonu
8. Latte renderer → HTML odpověď
```

### B) API request

```
1. www/index.php  (detekce /api/rest/ v URI)
2. Contributte\Middlewares middleware stack:
   TracyMiddleware
   → AutoBasePathMiddleware
   → MethodOverrideMiddleware
   → CorsMiddleware
   → TokenMiddleware          ← ověření API tokenu
   → VersionMiddleware
   → ApiMiddleware            ← Apitte routing
   → LogMiddleware
3. Apitte Controller → anotace (@Path, @Method)
4. Business Controllers / Services
5. JSON odpověď (Apitte Negotiation)
```

### C) CLI command

```
1. bin/console.php
2. Contributte\Console\Application
3. Hyperdrive příkazy (migrace DB)
```

---

## 4. Datové vrstvy

### ORM model (Nextras ORM)

- **Entity**: třídy s typed properties a vazbami (1:m, m:n)
- **Repository**: `findAll()`, `getBy()`, vlastní query metody
- **Mapper**: mapování entity → DB tabulka/schéma
- **Orm.php**: centrální registr všech repozitářů

```php
// Příklad přístupu v business vrstvě
$this->orm->tournaments->findAll();
$this->orm->members->getById($id);
```

### PostgreSQL schémata

| Schéma | Obsah |
|--------|-------|
| `judo` | Hlavní aplikační data (turnaje, závodníci, zápasy) |
| `base` | Základní číselníky |
| `configuration` | Konfigurační záznamy |
| `log` | Aplikační logy |
| `public` | PostgreSQL výchozí |

### Migrace

- Nástroj: **Hyperdrive** (Liquibase-based, XML changesets)
- Umístění: `resources/hyperdrive/`
  - `structure/` – DDL migrace
  - `basic-data/` – povinná data
  - `dummy-data/` – vývojová testovací data
- Spuštění: `php bin/console.php hyperdrive:start postgre`

---

## 5. Externí integrace

### Flexii (enterprise platforma)
- **Balíček**: `evosoftcz/flexii-connector`
- **Účel**: Autentizace uživatelů přes Flexii účty
- **Konfigurace**: `flexiiConnector.*` v `config/common.neon`
- **Šifrování**: AES (IV + secret v konfiguraci)

### RabbitMQ (message broker)
- **Balíček**: `contributte/rabbitmq`
- **Účel**: Asynchronní zpracování eventů/jobů
- **Konfigurace**: `rabbitmq_connection`, `rabbitmq_queues_url`

### EDA (event-driven architektura)
- **Balíček**: `evosoftcz/eda`
- **Účel**: Workflow zpracování na bázi DB eventů
- **Integrace**: Tracy debug panel pro EDA

### Rights systém
- **Balíček**: `evosoftcz/rights`
- **Účel**: Granulární správa oprávnění

### SMTP (e-mail)
- Nette Mail s konfigurací SMTP
- Service `MailService` – šablonové e-maily

### PDF generátor
- **Balíček**: `mpdf/mpdf`
- **Účel**: Generování dokumentů (startovní listiny, výsledky)

---

## 6. Riziková místa

### 6.1 Nepublikovaný `local.neon`
- `config/local.neon` není v gitu (správně), ale **bez něj aplikace spadne**
- Vzor: `config/local.example.neon`

### 6.2 Složitost generování pavouka
- `app/Business/Algorithms/` (TopSort, DFS) + `ShuffleService` + `ShuffleController`
- Netriviální logika turnajového pavouka; chybí unit testy pokrývající edge cases

### 6.3 Stará API vrstva (`ApiModule`)
- Vedle Apitte existuje i starší `ApiModule` (`/api/v2/`, `/api/open/`)
- Paralelní existence dvou API systémů zvyšuje maintenance cost

### 6.4 Závislost na `dev-master` / `dev-develop`
- `contributte/forms-multiplier`: `dev-master`
- `evosoftcz/tools`: `dev-develop`
- `evosoftcz/universal-datagrid`: `dev-develop`
- Nestabilní větve mohou způsobit breakage po `composer update`

### 6.5 Autentizace – více mechanismů
- Tři odlišné authenticatory (Basic, Flexii, SuperAdmin)
- Pět typů uživatelů se separátními sessions
- Nutné dobře rozumět, který flow platí pro které UI

### 6.6 RabbitMQ jako single point of failure
- Pokud fronta nedostupná, chování aplikace závisí na fallback logice – je třeba ji dohledat

### 6.7 PostgreSQL multi-schema
- `search_path` nastavena na 5 schémat
- Při ladění SQL je třeba znát, ve kterém schématu tabulka leží

### 6.8 PHPStan Level 8
- Vysoká úroveň statické analýzy (pozitivní)
- Nové kódy musí projít přísnou typovou kontrolou, jinak CI selže

---

## 7. Doporučení pro onboarding nového developera

### Krok 1 – Nastavení prostředí

```bash
# Zkopírovat a vyplnit lokální konfiguraci
cp config/local.example.neon config/local.neon

# Spustit Docker prostředí
docker-compose up -d

# Nainstalovat PHP závislosti
composer install

# Spustit migrace databáze
php bin/console.php hyperdrive:start postgre
```

### Krok 2 – Klíčové soubory k přečtení (v tomto pořadí)

1. `config/common.neon` – co aplikace potřebuje ke konfiguraci
2. `app/Bootstrap.php` – jak se inicializuje DI container
3. `app/RouterFactory.php` – jaké URL kde končí
4. `app/Data/Orm.php` – přehled entit a repozitářů
5. `app/Presentation/RestApi/Controllers/TournamentController.php` – vzorový REST controller
6. `app/Business/Controllers/DataControllers/` – vzorový data controller

### Krok 3 – Pochopení doménového modelu

Klíčový tok: **Turnaj → Kategorie → Závodník → Přihláška → Tatami → Zápas → Výsledek**

```
Tournament
  └── Category (hmotnostní třída)
       └── CategoryAge (věková skupina)
            └── MemberCategory (přihláška závodníka)
                 └── Member (závodník z Club)
  └── Tatami (zápasiště)
       └── TatamiMatch (konkrétní zápas na tatami)
            └── TournamentMatch (výsledek zápasu)
                 └── TournamentMatchData (data o výsledku)
```

### Krok 4 – Vývoj nové funkce (typický pattern)

1. **Entita** v `app/Data/[Doména]/[Doména]Entity.php`
2. **Mapper** v `app/Data/[Doména]/[Doména]Mapper.php` – SQL vazba
3. **Repozitář** v `app/Data/[Doména]/[Doména]Repository.php`
4. **Registrace** v `app/Data/Orm.php`
5. **DataController** v `app/Business/Controllers/DataControllers/`
6. **REST Controller** v `app/Presentation/RestApi/Controllers/`
   nebo **Presenter** v `app/Presentation/[Modul]Module/Presenters/`
7. **Migrace** v `resources/hyperdrive/structure/`

### Krok 5 – Časté gotchas

| Problém | Řešení |
|---------|--------|
| `ServiceNotFoundException` | Přidat do `config/services.neon` nebo zkontrolovat autowiring |
| Nette routing 404 | Zkontrolovat `RouterFactory.php`, název presenteru a akce |
| ORM mapping chyba | Zkontrolovat `Mapper` – přesný název tabulky a schéma |
| API vrací 401 | API token v hlavičce `X-Api-Token` nebo parametru |
| Tracy error 500 | Zapnout Tracy: `tracy: debugMode: true` v `config/local.neon` |
| PHPStan selhání | Spustit `composer phpstan-app` před commitem |

### Užitečné příkazy

```bash
# Statická analýza
composer phpstan-app

# Code style check / autofix
composer cs-app
composer cbf-app-extreme

# DB migrace
php bin/console.php hyperdrive:start postgre

# Drop DB (dev)
php bin/console.php hyperdrive:procedure postgre dropPostgre
```

---

*Vygenerováno: 2026-05-31*
