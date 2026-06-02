# Riziková místa — DWH

## Přehled rizik

| # | Oblast | Závažnost | Popis |
|---|---|---|---|
| 1 | RabbitMQ autoCreate | Vysoká | TCP spojení při každém requestu → 500 při výpadku |
| 2 | PHP Notice při shutdown | Střední | „Cannot set connection to blocking mode" — symptom #1 |
| 3 | Chybějící retry logika | Střední | Selhaná zpráva v RabbitMQ se ztratí bez DLQ |
| 4 | Proprietární EDA ORM | Střední | Bez veřejné dokumentace |
| 5 | Kafka bez autentizace | Střední | Žádné ověření v interní síti |
| 6 | Šifrování hesel v DB | Střední | Klíče v config souboru (ne v secrets manageru) |
| 7 | dataset_values objem | Střední | Miliony řádků — výkon dotazů bez dobré indexace |
| 8 | Testy chybí / neúplné | Vysoká | Žádné integrační testy pro ETL pipeline |
| 9 | Tmp soubory | Nízká | `www/send_to_file/` a `www/temp_files/` se nemaže |
| 10 | Hyperdrive procedury | Vysoká | `DROP SCHEMA CASCADE` je v proceduře — destruktivní |

---

## Detail rizik

### 1. RabbitMQ autoCreate: true ⚠ KRITICKÉ
**Závažnost:** Vysoká  
**Popis:** Konfigurace `autoCreate: true` způsobuje, že Nette DI kontejner při každém HTTP requestu automaticky otevírá TCP spojení s RabbitMQ serverem — i na stránkách, které frontu vůbec nepotřebují.  
**Dopad:** Výpadek RabbitMQ = 500 error na všech stránkách aplikace.  
**Doporučení:**
1. Změnit `autoCreate: false` v `config/rabbitmq.neon`
2. Fronty deklarovat jednorázově přes `rabbitmq:declareQueuesAndExchanges`
3. Přidat health check endpoint, který RabbitMQ testuje izolovaně

---

### 2. PHP Notice při shutdown
**Závažnost:** Střední  
**Popis:** „Cannot set connection to blocking mode" se vypisuje při ukončení requestu — přímý symptom problému #1.  
**Dopad:** Kosmetická chyba, ale indikuje nestabilitu spojení.  
**Doporučení:** Vyřešit spolu s #1.

---

### 3. Chybějící Dead Letter Queue (DLQ)
**Závažnost:** Střední  
**Popis:** Zprávy, které consumer opakovaně selže zpracovat, se vracejí do fronty (requeue) bez limitu pokusů. Pokud zpráva způsobuje trvalou chybu, consumer jí zpracovává donekonečna.  
**Dopad:** Consumer se zacyklí, fronta se plní, pipeline se zastaví.  
**Doporučení:** Nakonfigurovat DLQ pro každou frontu, přidat `x-max-retries` header.

---

### 4. Proprietární EDA ORM
**Závažnost:** Střední  
**Popis:** EDA (Evosoft Data Access) není veřejně dokumentovaná knihovna. Nový developer se v ní obtížně orientuje.  
**Dopad:** Vyšší onboarding čas, obtížný debugging DB problémů.  
**Doporučení:** Zajistit interní dokumentaci EDA, komentáře u nestandardního chování.

---

### 5. Kafka bez autentizace
**Závažnost:** Střední  
**Popis:** Kafka brokeři nemají ve výchozí konfiguraci nastavenou autentizaci (SASL/SSL).  
**Dopad:** Jakýkoliv klient v interní síti může produkovat nebo konzumovat zprávy.  
**Doporučení:** Nakonfigurovat SASL autentizaci pro Kafka, zejména na produkci.

---

### 6. Šifrování hesel — klíče v config souboru
**Závažnost:** Střední  
**Popis:** AES klíče (`iv` a `secret`) pro šifrování hesel k zdrojovým DB jsou uloženy v `config/local.neon` — textový soubor na disku, ne v secrets manageru.  
**Dopad:** Kompromitace serveru = kompromitace všech zdrojových DB hesel.  
**Doporučení:** Přesunout klíče do environment proměnných nebo HashiCorp Vault.

---

### 7. Výkon dataset_values
**Závažnost:** Střední  
**Popis:** Tabulka `dataset_values` má EAV (Entity-Attribute-Value) strukturu. Pro každý záznam je `N` řádků (N = počet sloupců datasetu). Při milionech entit = desítky nebo stovky milionů řádků.  
**Dopad:** Pomalé dotazy bez dobré indexace, pomalé JOINy při publikaci.  
**Doporučení:** Zkontrolovat existenci indexů na `(entity_id, def_id)`, pravidelný VACUUM/ANALYZE na PostgreSQL.

---

### 8. Chybějící automatizované testy ⚠
**Závažnost:** Vysoká  
**Popis:** Nette Tester je nakonfigurován, ale rozsah testů není jasný — ETL pipeline, consumers a services nejsou pokryty integračními testy.  
**Dopad:** Regrese v ETL logice nejsou automaticky detekovány.  
**Doporučení:** Přidat integrační testy pro klíčové části: DataSourceService, ValidationService, PublicationService, RabbitMQ consumer flow.

---

### 9. Tmp soubory
**Závažnost:** Nízká  
**Popis:** `www/send_to_file/` a `www/temp_files/` nejsou automaticky čištěny.  
**Dopad:** Postupné plnění disku exportními soubory.  
**Doporučení:** Přidat cron job pro mazání starých souborů.

---

### 10. Hyperdrive DROP procedura ⚠ DESTRUKTIVNÍ
**Závažnost:** Vysoká  
**Popis:** Soubor `resources/hyperdrive/procedure/drop-postgre.sql` obsahuje `DROP SCHEMA CASCADE` — smaže celou databázi. Je dostupná jako příkaz `hyperdrive:procedure dropPostgre`.  
**Dopad:** Nechtěné spuštění = ztráta všech dat.  
**Doporučení:**
- Příkaz nijdy nespouštět na produkci
- Přidat potvrzovací dialog nebo `--force` flag
- Omezit přístup k příkazu (role, env check)

---

## Doporučená prioritizace

| Priorita | Akce |
|---|---|
| 1 | Opravit RabbitMQ `autoCreate: true` → `false` |
| 2 | Přidat DLQ pro RabbitMQ fronty |
| 3 | Chránit Hyperdrive DROP proceduru před nechtěným spuštěním |
| 4 | Přidat integrační testy pro ETL pipeline |
| 5 | Přesunout šifrovací klíče do env nebo Vault |
| 6 | Přidat cron job pro čištění tmp souborů |
| 7 | Zkontrolovat indexy na dataset_values |
| 8 | Nakonfigurovat Kafka autentizaci na produkci |
