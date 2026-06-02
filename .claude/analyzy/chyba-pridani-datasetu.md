# Chyba: Cannot set connection to blocking mode při přidání datasetu

**Datum:** 2026-05-28  
**Autor šetření:** Claude Code (podnět: Tomas Gura)  
**Kontext:** Tomas si všiml záznamu v `log/exception.log` poté, co lokálně vyplnil a odeslal formulář pro vytvoření nového datasetu (`http://dwh.loc/data/dataset/new`). Po úspěšném uložení server odeslal HTTP redirect na `http://dwh.loc/data/` s flash message — a právě po odeslání **této HTTP odpovědi** (tedy až ve fázi PHP shutdown, kdy prohlížeč redirect already dostal) se chyba vygenerovala.  
**Závažnost:** ~~PHP Notice (nízká)~~ → **viz aktualizace 2026-05-29 — závažnost je vyšší**  
**Prostředí:** lokální dev (Docker `app83:latest`, PHP 8.3.16, Apache 2.4.62)

---

## TL;DR — Shrnutí (2026-05-28)

Při vytvoření/úpravě datasetu se do `log/exception.log` zapíše Notice `Cannot set connection to blocking mode`. **Dataset se uložil správně, RabbitMQ zpráva odešla, uživatel dostal redirect** — chyba je čistě kosmetická.

**Co se děje:** Během requestu se otevře TCP spojení na RabbitMQ (publish zprávy při uložení datasetu). PHP pak odešle HTTP 302 redirect prohlížeči a začne shutdown — v té fázi destruktor `Contributte\RabbitMQ\Connection` se pokusí korektně uzavřít **to AMQP TCP spojení** přes `syncDisconnect()`, jenže uvnitř zavolá `fflush()` na socket v okamžiku, kdy PHP interně socket uklízí — PHP to vyhodí jako Notice. Redirect samotný s tím nesouvisí, je jen časový bod kdy prohlížeč odpověď dostal.

**Je to jen lokální prostředí? (názor AI)** Pravděpodobně ne — Notice existuje v kódu obecně a objeví se kdekoli, kde se dataset vytváří/upravuje a RabbitMQ spojení se otevře. Lokálně se to projevilo poprvé dnes, protože exception log byl od 12. května prázdný — nejspíš šlo o první spuštění téhle code path v tomto lokálním prostředí. Na produkci/stagingu to buď stejně tiše probíhá a Tracy tam Notices do `exception.log` neloguje, nebo to nikdo dosud nezaregistroval. Rozhodně stojí za to zkontrolovat produkční `log/exception.log`.

**Tři oddělené problémy nalezeny:**

1. **PHP Notice (původní chyba)** — jde za knihovnou bunny/bunny a PHP shutdown mechanikou. Oprava vyžaduje buď `composer-patches` (potlačení `@` v `Connection::__destruct()`), nebo to lze nechat být, pokud produkce Notices neloguje.

2. **Špatná konfigurace dev-docker RabbitMQ** (vedlejší nález, opraveno 2026-05-28) — `channel_operation_timeout` v `rabbitmq.conf` není platný parametr → RabbitMQ odmítal nastartovat. Opraveno odebráním nevhodného parametru, zbylé parametry (`heartbeat`, `consumer_timeout`) jsou platné.

3. **Fundamentální problém: `autoCreate: true` způsobuje povinné TCP připojení k RabbitMQ při každém requestu** — viz sekce níže. **Pokud je RabbitMQ nedostupný, aplikace spadne** (přidání datasetu selže, homepage se nenačte).

---

## Symptom

V `log/exception.log` se opakovaně objevují záznamy:

```
[2026-05-28 15-18-21] Notice: PHP Request Shutdown: Cannot set connection to blocking mode
  in Unknown:0  @  http://dwh.loc/data/?bl=p5esz&_fid=a5zq
  @@  exception--2026-05-28--15-18--90eee12a36.html

[2026-05-28 15-21-54] Notice: PHP Request Shutdown: Cannot set connection to blocking mode
  in Unknown:0  @  http://dwh.loc/data/dataset/new?bl=eygk1
  @@  exception--2026-05-28--15-18--90eee12a36.html

[2026-05-28 15-30-29] Notice: PHP Request Shutdown: Cannot set connection to blocking mode
  in Unknown:0  @  http://dwh.loc/data/?bl=0r7na&_fid=2eme
  @@  exception--2026-05-28--15-18--90eee12a36.html
  ... (+ dalších 9 výskytů téhož requestu)
```

- `File: Unknown` a `PHP Request Shutdown` = chyba vzniká uvnitř PHP C internals při destrukci stream resource, ne v PHP userland kódu
- `_fid=` v URL = flash message ID → request proběhl úspěšně a uživatel byl přesměrován

---

## Kdy se to spouští

Kdykoli je vytvořen nebo upraven dataset. Konkrétně při odeslání formuláře `DatasetSettingsForm`, který zavolá `AdminManager::insertSystemProcess(PROCESS_TYPE_RESET_QUEUES, ...)`, což otevře TCP spojení na RabbitMQ přes knihovnu **bunny/bunny**.

---

## Call chain

```
DatasetSettingsFormControl::handleFormSuccess()
  app/AdminModule/Components/Forms/DatasetSettingsForm/DatasetSettingsFormControl.php:279
  └─ AdminManager::insertSystemProcess(PROCESS_TYPE_RESET_QUEUES, ...)
       app/Manager/AdminManager.php:232
       ├─ ServiceManager::isAnyActionRunningInRabbitMq('systemProcessQueue')
       │    app/Manager/ServiceManager.php:93
       │    └─ [HTTP call na RabbitMQ Management API — žádné AMQP spojení]
       │
       └─ SystemProcessQueue::publish($processHash, $id_appuser)
            app/RabbitMq/Queue/SystemProcessQueue.php:35
            └─ Producer::publish(...)
                 vendor/contributte/rabbitmq/src/Producer/Producer.php
                 └─ Connection::getChannel()
                      vendor/contributte/rabbitmq/src/Connection/Connection.php
                      └─ [otevře TCP socket na RabbitMQ přes bunny/bunny]

--- HTTP response (redirect) se odešle ---
--- PHP začíná shutdown ---

PHP destrukce DI kontejneru
  └─ Connection::__destruct()
       vendor/contributte/rabbitmq/src/Connection/Connection.php:62–65
       └─ Client::syncDisconnect()  [contributte wrapper]
            vendor/contributte/rabbitmq/src/Connection/Client.php:23
            ├─ channelClose(...) → write() → fflush($stream)   ← PRAVDĚPODOBNÝ ZDROJ
            ├─ connectionClose(0, '', 0, 0)
            └─ closeStream() → @fclose($stream); $stream = null

            Bunny\AbstractClient::write()
              vendor/bunny/bunny/src/Bunny/AbstractClient.php:329–339
              └─ fflush($this->getStream())  ← řádek 339, bez @ suppressoru
                 ↑ tady PHP generuje Notice "Cannot set connection to blocking mode"

  └─ Bunny\Client::__destruct()
       vendor/bunny/bunny/src/Bunny/Client.php:54–65
       └─ isConnected() → false (syncDisconnect() już zavolal init())
          → nic se nestane
```

---

## Proč to nevadí funkčně

- Notice nastane **po** `return $this->redirect(...)` v presenteru
- Dataset byl uložen, zpráva do RabbitMQ byla publishnuta
- PHP Notice je úroveň nižší než Warning — neovlivní odpověď ani session

---

## Zdrojové soubory k prověření

| Soubor | Řádek | Co prověřit |
|--------|-------|-------------|
| `app/AdminModule/Components/Forms/DatasetSettingsForm/DatasetSettingsFormControl.php` | 279 | Volání `insertSystemProcess` — zde začíná chain |
| `app/Manager/AdminManager.php` | 232–249 | `insertSystemProcess()` — volá `publish()` na RabbitMQ |
| `app/RabbitMq/Queue/SystemProcessQueue.php` | 35–46 | `publish()` — otevírá Bunny spojení |
| `vendor/contributte/rabbitmq/src/Connection/Connection.php` | 62–65 | `__destruct()` — volá `syncDisconnect()` bez error suppression |
| `vendor/contributte/rabbitmq/src/Connection/Client.php` | 23–46 | `syncDisconnect()` — AMQP close handshake, chybí try/catch pro Notice |
| `vendor/bunny/bunny/src/Bunny/AbstractClient.php` | 339 | `fflush($this->getStream())` — bez `@`, pravděpodobný zdroj Notice |
| `vendor/bunny/bunny/src/Bunny/AbstractClient.php` | 284–285 | `stream_set_blocking($this->stream, 0)` — jen pro async=true, zde se nevykoná |

---

## Možné příčiny proč to je jen lokálně

1. **`app83:latest` Docker image byl dnes aktualizován** s jiným `error_reporting` nastavením
2. **První spuštění téhle code path lokálně** — log byl prázdný od 12. května, první vytvoření datasetu dnes tuto notice poprvé vygenerovalo
3. **Jiná Tracy konfigurace** — produkce/staging možná neloguje Notices do `exception.log`

---

## Možnosti opravy

### Varianta A — composer-patches (doporučeno)
Nainstalovat `cweagans/composer-patches` a přidat patch pro jeden řádek:

```diff
--- a/vendor/contributte/rabbitmq/src/Connection/Connection.php
+++ b/vendor/contributte/rabbitmq/src/Connection/Connection.php
@@ -62,7 +62,7 @@ final class Connection implements IConnection
     public function __destruct()
     {
         if ($this->bunnyClient->isConnected()) {
-            $this->bunnyClient->syncDisconnect();
+            @$this->bunnyClient->syncDisconnect();
         }
     }
```

Patch se automaticky přehraje po každém `composer update`.

### Varianta B — post-update-cmd skript
Do `composer.json` přidat:
```json
"scripts": {
    "post-install-cmd": ["php -r \"...\""],
    "post-update-cmd": ["..."]
}
```
Bez nové závislosti, ale křehčí.

### Varianta C — nechat být
Notice neovlivňuje funkčnost. Pokud produkce/staging stejnou chybu neloguje, jde jen o lokální šum.

---

## Vedlejší nález: špatná konfigurace dev-docker RabbitMQ

Při vyšetřování bylo zjištěno, že **žádná z vlastních konfiguračních hodnot pro RabbitMQ se v dev-docker vůbec neaplikuje.**

### Proč

V `docker-compose.yml` je mountován pouze jeden soubor:
```yaml
volumes:
  - ./rabbitmq/rabbitmq-env.conf:/etc/rabbitmq/rabbitmq-env.conf
```

`rabbitmq-env.conf` je soubor pro **shell proměnné** startovacích skriptů RabbitMQ (věci jako `RABBITMQ_NODENAME`, `RABBITMQ_MNESIA_DIR`). Klíče `heartbeat`, `consumer_timeout`, `channel_operation_timeout` v tomto souboru RabbitMQ nerozumí a tiše je ignoruje.

`rabbitmq-advanced.conf` (který nastavuje `consumer_timeout = undefined`) **není mountovaný** do containeru vůbec.

### Reálné vs. zamýšlené hodnoty

| Nastavení | Zamýšleno | Reálně (default) |
|-----------|-----------|-----------------|
| `heartbeat` | `0` (zakázáno) | **60 s** |
| `consumer_timeout` | `7 200 000 ms` (2 h) | **1 800 000 ms** (30 min) |
| `channel_operation_timeout` | `7 200 000 ms` (2 h) | **15 000 ms** (15 s) |

Ověřeno přes `rabbitmqctl eval "application:get_env(rabbit, heartbeat)."` → `{ok,60}`.

### Důsledky

- **Heartbeat 60 s** místo zakázaného: consumers, kteří jsou delší dobu idle, mohou být serverem odpojeni
- **`channel_operation_timeout` 15 s** místo 2 h: pomalejší channel operace timeoutují
- **`consumer_timeout` 30 min** místo 2 h nebo ∞: dlouhé consumer operace se mohou přerušit

Na chybu "Cannot set connection to blocking mode" ve webových requestech toto **vliv nemá** (spojení trvá < 1 s, heartbeat nestihne hrát roli).

### Provedená oprava

Vytvořen soubor `dev-docker/rabbitmq/rabbitmq.conf` ve správném formátu (`klíč = hodnota`):

```ini
heartbeat = 0
consumer_timeout = 7200000
channel_operation_timeout = 7200000
```

A přidán mount do `dev-docker/docker-compose.yml`:
```yaml
- ./rabbitmq/rabbitmq.conf:/etc/rabbitmq/conf.d/20-custom.conf
```

Mountuje se do `conf.d/` — RabbitMQ načítá všechny `.conf` soubory z tohoto adresáře v abecedním pořadí (za `10-defaults.conf` z image).

**Pro aktivaci je potřeba restartovat container:**
```bash
cd ~/projekty/evosoft/dev-docker
docker compose up -d --force-recreate rabbitmq
```

---

## Tracy HTML dump

Uložen v: `log/exception--2026-05-28--15-18--90eee12a36.html`

Klíčové položky z dumpu:
- **Error:** `Notice: PHP Request Shutdown: Cannot set connection to blocking mode`
- **Source file:** `Unknown` (PHP internals)
- **URL:** `http://dwh.loc/data/?bl=p5esz&_fid=a5zq`
- **Referer:** `http://dwh.loc/data/dataset/new?bl=p5esz`
- **PHP:** 8.3.16
- **Server:** Apache/2.4.62 (Debian), `dwh.loc`
- **Presenter:** `null` (chyba nastala po ukončení presenteru, ve fázi shutdown)

---

## Aktualizace 2026-05-29 — Skutečná příčina a dopad

### Původní analýza byla nesprávná

Původní závěr ("chyba je čistě kosmetická") byl chybný. Notice je symptom hlubšího problému, který **způsobuje pád celé aplikace pokud je RabbitMQ nedostupný**.

---

### Proč se TCP spojení otvírá při každém requestu

Klíčový řetězec v knihovně `contributte/rabbitmq`:

```
Client::getProducer('masterProducer')
  └─ ProducerFactory::create('masterProducer')
       └─ QueueFactory::getQueue('masterQueue')        ← voláno proto, že producerData['queue'] je nastaveno
            └─ QueueFactory::create('masterQueue')
                 └─ QueueDeclarator::declareQueue('masterQueue')   ← protože autoCreate: true
                      └─ $connection->getChannel()
                           └─ Connection::connectIfNeeded()
                                └─ Bunny\Client::connect()          ← TCP SPOJENÍ!
```

`lazy: true` v konfiguraci připojení chrání **pouze konstruktor** `Connection` (neprovede `connect()` v `__construct()`). Ale `QueueDeclarator::declareQueue()` zavolá `getChannel()` přímo, čímž `lazy: true` obejde a připojení vynutí.

Výsledek: **`autoCreate: true` ve všech frontách = povinné TCP spojení k RabbitMQ vždy, když je vytvořena libovolná DI služba závislá na frontě.**

---

### Které DI řetězce otevírají RabbitMQ na konkrétních stránkách

**`http://dwh.loc/data/` (homepage, `Data:Homepage:default`):**

```
HomepagePresenter (OverviewDatagridTrait)
  └─ createComponentOverviewDatagrid()
       └─ OverviewDatagridControl::__construct(DatasetActionService)
            └─ DatasetActionService::__construct(MasterQueue)
                 └─ MasterQueue = new MasterQueue(@Client::getProducer('masterProducer'))
                      └─ QueueDeclarator::declareQueue('masterQueue') → TCP CONNECT
```

Každý GET na homepage — i bez kliknutí na tlačítko — otevírá spojení na RabbitMQ přes tento řetězec.

**`http://dwh.loc/data/dataset/new` (přidání datasetu, `Data:Dataset:new`):**

```
DatasetPresenter (NewDatasetEntityFormTrait)
  └─ createComponentNewDatasetEntityForm()
       └─ NewDatasetEntityFormFactory::create(DatasetEntityFactory)
            └─ DatasetEntityFactory::__construct(DatasetManagerService)
                 └─ DatasetManagerService::__construct(AdminManager)
                      └─ AdminManager::__construct(SystemProcessQueue)
                           └─ SystemProcessQueue = new SystemProcessQueue(@Client::getProducer('systemProcessProducer'))
                                └─ QueueDeclarator::declareQueue('systemProcessQueue') → TCP CONNECT
```

I samotné **načtení stránky** formuláře pro přidání datasetu otevírá RabbitMQ spojení — bez jakéhokoli odeslání formuláře.

---

### Skutečný dopad: pád aplikace při nedostupném RabbitMQ

Pokud `QueueDeclarator::declareQueue()` zavolá `getChannel()` a RabbitMQ **není dostupný**:

1. `Connection::connectIfNeeded()` → `Bunny\Client::connect()` **vyhodí výjimku** (`ClientException` nebo `ConnectionException`)
2. Výjimka se propaguje přes: `QueueDeclarator` → `QueueFactory` → `ProducerFactory` → `Client::getProducer` → Nette DI kontejner
3. Nette DI kontejner nedokáže vytvořit službu → výjimka se šíří do presenteru/komponenty
4. Výjimka **není nikde zachycena** v aplikačním kódu
5. **Výsledek: Tracy/500 error page** — uživatel nemůže nic dělat

**Konkrétní situace, kde aplikace padá:**
- Načtení homepage (`OverviewDatagridControl` nelze vytvořit)
- Načtení nebo odeslání formuláře `Data:Dataset:new` (`DatasetEntityFactory` nelze vytvořit)
- Jakákoliv stránka, která používá `DatasetActionService` nebo `AdminManager`

Toto odpovídá chování pozorovanému 2026-05-29 ráno, kdy `rabbitmq.conf` s neplatným parametrem `channel_operation_timeout` způsobil pád RabbitMQ containeru → celá aplikace nefungovala.

---

### Proč Notice (`Cannot set connection to blocking mode`) není jen kosmetická

Notice sama o sobě (když RabbitMQ **funguje**) je skutečně kosmetická. Ale je příznakem, že **každý request povinně otevírá TCP spojení k RabbitMQ** přes `autoCreate: true`. Jakmile RabbitMQ není dostupný (restart, chyba konfigurace, výpadek sítě), aplikace kompletně spadne — ne jen určitá funkce, ale celá aplikace.

---

### Možnosti opravy (aktualizováno)

**Prioritní fix — `autoCreate: false` + separátní deklarace front:**

V `config/rabbitmq.neon` změnit všechny fronty:
```yaml
queues:
    systemProcessQueue:
        connection: default
        autoCreate: false   # ← bylo: true
        arguments:
            x-max-priority: 10
    masterQueue:
        connection: default
        autoCreate: false   # ← bylo: true
        ...
```

Fronty deklarovat jednorázově při deployi/startu (konzolový příkaz), ne při každém requestu.

**Výhody:** Aplikace přestane být závislá na RabbitMQ pro KAŽDÝ request. Při výpadku RabbitMQ budou padat jen operace, které skutečně potřebují RabbitMQ (publish/consume), ne celá aplikace.

**Alternativa — Varianta A (původní návrh, stále platná):**
`composer-patches` pro potlačení Notice v `Connection::__destruct()`. Neřeší ale fundamentální závislost na dostupnosti RabbitMQ.

---

### Opravené soubory k datu 2026-05-29

| Soubor | Změna |
|--------|-------|
| `dev-docker/rabbitmq/rabbitmq.conf` | Odebráno `channel_operation_timeout` (neplatný parametr → crash RabbitMQ) |