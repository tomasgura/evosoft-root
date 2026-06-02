# README — Lokální spuštění

## Požadavky

- PHP 8.3+
- Composer
- Node.js + npm
- Docker (pro databázi)
- Přístupy k DWH (PostgreSQL), Flexii API, Hajime API

## Klonování a instalace

```bash
git clone <repo-url>
cd judo-vysledkovy-portal

# PHP závislosti
composer install

# Frontend závislosti
npm install

# Zkopíruj env soubor
cp .env .env.local
```

## Konfigurace `.env.local`

Vyplň následující proměnné:

```dotenv
APP_ENV=dev
APP_SECRET=<vygeneruj: php -r "echo bin2hex(random_bytes(16));">

# Databáze (DWH)
DATABASE_NAME=judo_dwh
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=judo_readonly
DATABASE_PASSWORD=<heslo>

# Cache (pro dev vypni)
EVO_CACHE_ENABLED=false
EVO_CACHE_MODE=file
EVO_CACHE_MODE_CLI=file
CACHE_EXPIRATION_SECONDS=3600
CACHE_EXPIRATION_SECONDS_LIVE_RESULTS=60

# Flexii API
FLX_CONNECT_API_URL=https://...
FLX_CONNECT_API_TOKEN=<token>
FLX_CONNECT_API_DEBUG=1
FLX_CONNECT_API_LAZY=1
FLX_CONNECT_CRYPTO_ENABLED=0

# Hajime API
HAJIME_URL=https://...

# Club UID (ČSJÚ)
CSJU_CLUB_UID=100006

# Google Analytics (vypni pro dev)
GOOGLE_ANALYTICS_ID=
```

## Spuštění přes Docker

```bash
# Spuštění kontejneru
docker-compose up -d

# Ověření
docker ps
```

Aplikace bude dostupná na: `http://judo-portal.loc`

Přidej do `/etc/hosts`:
```
127.0.0.1 judo-portal.loc
```

## Spuštění bez Dockeru (PHP built-in server)

```bash
# Cache a assets
php bin/console cache:clear
php bin/console assets:install

# Spuštění serveru
php -S localhost:8000 -t public/
```

Aplikace bude dostupná na: `http://localhost:8000`

## Frontend assets

```bash
# Jednorázové sestavení
npm run build

# Watch mode (při vývoji)
npm run watch
```

## Cron joby (synchronizace dat)

Spouštěj ručně při vývoji nebo nastav v cronu pro produkci:

```bash
# Sync turnajů a výsledkových souborů
php bin/console app:get-tournaments

# Sync klubů a log
php bin/console app:get-clubs
```

## Přehled Symfony příkazů

```bash
# Vyčistit cache
php bin/console cache:clear

# Vyčistit cache pool
php bin/console cache:pool:clear cache.app

# Přehled routes
php bin/console debug:router

# Přehled services
php bin/console debug:container

# PHPStan analýza
composer phpstan

# Code style check
composer cs

# Code style fix
composer cbf
```

## Symfony Profiler

V dev prostředí je k dispozici debug toolbar na spodku každé stránky.
Detailní profiler: `http://localhost:8000/_profiler`

Zobrazuje:
- Dobu zpracování requestu
- DB dotazy (EDA)
- Cache hity/miss
- Paměť
- Logy

## Adresáře, které musí být zapisovatelné

```bash
chmod -R 777 var/
chmod -R 777 public/files/
```

## Časté problémy

**Prázdná stránka / 500 error:**
```bash
tail -f var/log/dev.log
```

**Cache stará data:**
```bash
php bin/console cache:pool:clear cache.app
# nebo nastav EVO_CACHE_ENABLED=false v .env.local
```

**Frontend se nezobrazuje správně:**
```bash
npm run build
php bin/console assets:install
```

**DB připojení selhalo:**
- Zkontroluj `DATABASE_*` proměnné v `.env.local`
- Ověř, že Docker kontejner s DB běží: `docker ps`
