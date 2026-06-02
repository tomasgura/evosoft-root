# Riziková místa — Judo Výsledkový portál

## Přehled rizik

| # | Oblast | Závažnost | Popis |
|---|---|---|---|
| 1 | SSL Hajime API | Střední | SSL verifikace vypnuta |
| 2 | DWH read-only | Nízká | Aplikace nepíše, ale závisí na externím ETL |
| 3 | Cache invalidace | Střední | Stará data při dlouhém TTL nebo při výpadku APCu |
| 4 | Tmp soubory | Nízká | `var/tmp/` se automaticky nemaže |
| 5 | Flexii sync | Střední | Jednosměrná synchronizace bez retry logiky |
| 6 | Live data závislost | Střední | Hajime API jako SPOF pro live turnaje |
| 7 | Proprietární ORM | Střední | EDA není veřejně dokumentovaná |
| 8 | Testy chybí | Vysoká | Žádné PHP unit/integration testy v src/ |

---

## Detail rizik

### 1. SSL verifikace vypnuta (Hajime API)
**Závažnost:** Střední  
**Popis:** `HajimeEndpoint` má vypnutou SSL verifikaci (`setSslVerifyHost(false)`, `setSslVerifyPeer(false)`).  
**Dopad:** Možnost MITM útoku v interní síti.  
**Doporučení:** Ověřit, zda Hajime API má platný certifikát, a SSL verifikaci zapnout.

---

### 2. Závislost na externím ETL pro DWH
**Závažnost:** Nízká  
**Popis:** DWH tabulky jsou materializované pohledy, aktualizuje je externí ETL. Pokud ETL selže, aplikace zobrazuje stará data bez varování.  
**Dopad:** Uživatel vidí neaktuální výsledky.  
**Doporučení:** Přidat do UI nebo admin rozhraní datum posledního refreshe DWH, monitorovat ETL.

---

### 3. Cache invalidace
**Závažnost:** Střední  
**Popis:** Data jsou cachována s fixním TTL. Při aktualizaci dat v DWH nebo Flexii se cache automaticky neinvaliduje — uživatel vidí stará data po dobu TTL.  
**Dopad:** Zpožděné zobrazení aktuálních výsledků po synchronizaci.  
**Doporučení:** Přidat manuální invalidaci cache po Flexii syncu, nebo zkrátit TTL pro kritická data.

---

### 4. Tmp soubory (export)
**Závažnost:** Nízká  
**Popis:** `ExportService` ukládá exportní soubory do `var/tmp/` a nemaže je.  
**Dopad:** Postupné plnění disku na serveru.  
**Doporučení:** Přidat cron job pro mazání starých souborů z `var/tmp/`.

---

### 5. Flexii synchronizace bez retry
**Závažnost:** Střední  
**Popis:** CLI commandi (`app:get-tournaments`, `app:get-clubs`) nemají retry logiku. Při chybě API přerušení dojde ke ztrátě dat pro daný běh.  
**Dopad:** Chybějící loga nebo výsledkové soubory, které se obnoví až při dalším cron spuštění.  
**Doporučení:** Přidat retry s backoffem, logovat chyby per-turnaj/klub.

---

### 6. Hajime API jako Single Point of Failure
**Závažnost:** Střední  
**Popis:** Pro live turnaje je jediným zdrojem dat Hajime API. Výpadek API = prázdné stránky výsledků a zápasů.  
**Dopad:** Viditelný pro uživatele v době konání turnaje — nejkritičtější moment.  
**Doporučení:** Přidat graceful degradaci (zobrazit poslední known data z cache, nebo hlášku o výpadku).

---

### 7. Proprietární ORM EDA
**Závažnost:** Střední  
**Popis:** EDA (Evosoft Data Access) je interní proprietární knihovna bez veřejné dokumentace. Nový developer mimo Evosoft se v ní obtížně zorientuje.  
**Dopad:** Vyšší onboarding čas, obtížnější debugging DB problémů.  
**Doporučení:** Zajistit interní dokumentaci EDA, komentáře u nestandardního chování.

---

### 8. Chybějící automatizované testy
**Závažnost:** Vysoká  
**Popis:** V `src/` nejsou žádné unit ani integration testy. PHPStan a Playwright jsou nakonfigurované, ale Playwright testy nebyly nalezeny.  
**Dopad:** Regrese nejsou automaticky detekovány, každá změna je riziková.  
**Doporučení:** Přidat unit testy alespoň pro Services a Repository vrstvu. Prioritně pokrýt složitou logiku (cache, export, kategorie).

---

## Doporučená prioritizace

| Priorita | Akce |
|---|---|
| 1 | Přidat automatizované testy (Services, Repository) |
| 2 | Přidat cron job pro čištění `var/tmp/` |
| 3 | Graceful degradace při výpadku Hajime API |
| 4 | Zapnout SSL verifikaci pro Hajime API |
| 5 | Přidat retry logiku pro Flexii sync |
| 6 | Monitorovat datum posledního ETL refreshe |
