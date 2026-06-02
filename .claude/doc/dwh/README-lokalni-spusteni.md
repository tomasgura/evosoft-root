# README — Lokální spuštění DWH

## Požadavky

- PHP 8.3+
- Composer
- Node.js + npm
- Docker (pro PostgreSQL, RabbitMQ, Kafka)
- Java runtime (pro Liquibase / Hyperdrive)
- Přístupy ke zdrojovým DB (volitelně pro import)

## Klonování a instalace

```bash
git clone <repo-url>
cd dwh

# PHP závislosti
composer install

# Frontend závislosti (ve www/)
cd www && npm install && cd ..

# Zkopíruj lokální konfiguraci
cp config/local.example.neon config/local.neon
```

## Konfigurace `config/local.neon`

Vyplň sekce:

```neon
parameters:
  customer: 1           # Customer ID (číslo zákazníka)
  database: postgre     # postgre | oracle

databaseConnection:
  postgre:
    host: postgresql_17   # Docker service name
    database: dwh
    username: app
    password: "1234"

rabbitmq_connection:
  host: rabbitmq          # Docker service name
  user: rabbitmq_dev
  password: dev123
  vhost: /

mailer:
  host: smtp.host
  username: user
  password: pass
  secure: ssl
  mailFrom: dev@evosoft.cz
```

## Spuštění Dev stacku (Docker)

```bash
# Spuštění aplikace
docker-compose up -d

# Ověření
docker ps
```

Přidej do `/etc/hosts`:
```
127.0.0.1 dwh.loc
```

Aplikace bude dostupná na: `http://dwh.loc`

## Inicializace databáze

```bash
# Spustit Liquibase migrace (vytvoří celé schéma)
php bin/console.php hyperdrive:start postgre

# Inicializovat RabbitMQ fronty
php bin/console.php rabbitmq:declareQueuesAndExchanges
```

## Spuštění RabbitMQ consumerů

```bash
# Spustí všech 9 consumerů v background
make rabbitmq

# Nebo jednotlivě (pro debugging):
php bin/console.php rabbitmq:staticConsumer masterConsumer 5000
php bin/console.php rabbitmq:staticConsumer dataSourceConsumer 5000
php bin/console.php rabbitmq:staticConsumer dataToValuesConsumer 5000
php bin/console.php rabbitmq:staticConsumer transformationConsumer 5000
php bin/console.php rabbitmq:staticConsumer enrichmentConsumer 5000
php bin/console.php rabbitmq:staticConsumer validationConsumer 5000
php bin/console.php rabbitmq:staticConsumer dataQualityConsumer 5000
php bin/console.php rabbitmq:staticConsumer publicationConsumer 5000
php bin/console.php rabbitmq:staticConsumer jobProcessConsumer 5000
```

## Frontend assets

```bash
cd www
npm run build     # Jednorázové sestavení (Webpack)
npm run watch     # Watch mode při vývoji
```

## Debug mód

```bash
# Zapnout Tracy debugger
touch app/.debug

# Vypnout
rm app/.debug
```

## Přehled Make příkazů

```bash
make setup          # Kompletní setup (Docker + composer + npm + RabbitMQ init)
make install        # composer install
make update         # composer update
make phpstan        # PHPStan analýza
make reload-postgre # ⚠ DESTRUKTIVNÍ: smaže a znovu vytvoří DB
make rabbitmq       # Spustí 9 consumerů v background
```

## Přehled CLI příkazů

```bash
# DB migrace
php bin/console.php hyperdrive:start postgre       # Spustit migrace
php bin/console.php hyperdrive:procedure <name>    # Spustit SQL proceduru
  # Dostupné procedury: dropPostgre, dropOracle (⚠ DESTRUKTIVNÍ)

# RabbitMQ
php bin/console.php rabbitmq:declareQueuesAndExchanges   # Init topologie
php bin/console.php rabbitmq:staticConsumer <name> <ms>  # Spustit consumer

# Aplikační příkazy
php bin/console.php app:job-queue                         # Zpracovat joby (cron)
php bin/console.php app:index-rebuild                     # Rebuild DB indexů
php bin/console.php app:dataset-entity-historization      # Archivace entit
php bin/console.php app:database-views-rebuild            # Rebuild materialized views
```

## Adresáře, které musí být zapisovatelné

```bash
chmod -R 777 temp/
chmod -R 777 log/
chmod -R 777 www/files/
chmod -R 777 www/send_to_file/
chmod -R 777 www/temp_files/
chmod -R 777 www/persistent_files/
```

## Tracy Profiler

V debug módu (`touch app/.debug`) je dostupný Tracy debugger.
Chyby se zobrazují v prohlížeči a logují do `log/exception*.html`.

Logy: `log/exception.log`

## Kafka debug skripty

```bash
# Číst zprávy z Kafka topiku
php bin/kafkaReader.php

# Testovat publikaci do Kafka
php bin/kafkaTest.php
```

## Časté problémy

**Aplikace vrací 500 při každém requestu:**
- Zkontroluj, zda běží RabbitMQ kontejner: `docker ps`
- Zkontroluj `rabbitmq_connection` v `config/local.neon`

**Migrace selhávají:**
- Zkontroluj, zda běží PostgreSQL: `docker ps`
- Zkontroluj `databaseConnection` v `config/local.neon`
- Ověř, zda je nainstalovaná Java (pro Hyperdrive)

**Consumer zpracuje zprávu a znovu vrátí do fronty:**
- Zkontroluj `log/exception.log`
- Spusť consumer ručně (bez background) a sleduj výstup

**Frontend se nezobrazuje:**
```bash
cd www && npm run build
```

**Čistý reset vývojové DB:**
```bash
make reload-postgre   # ⚠ Smaže vše a znovu inicializuje
```
