# Uživatelská dokumentace – Hajime

> Systém pro správu judo turnajů  
> Verze dokumentace: 2026-05-31

---

## Obsah

1. [K čemu systém slouží](#1-k-čemu-systém-slouží)
2. [Typy uživatelů a přihlášení](#2-typy-uživatelů-a-přihlášení)
3. [Modul Admin – správa turnaje](#3-modul-admin--správa-turnaje)
4. [Modul Scale – vážení závodníků](#4-modul-scale--vážení-závodníků)
5. [Modul Scoreboard – výsledková tabule](#5-modul-scoreboard--výsledková-tabule)
6. [Modul Infopanel – informační tabule](#6-modul-infopanel--informační-tabule)
7. [Workflow od začátku do konce turnaje](#7-workflow-od-začátku-do-konce-turnaje)
8. [Validace a omezení](#8-validace-a-omezení)
9. [Přehled tlačítek a akcí](#9-přehled-tlačítek-a-akcí)
10. [Možné chyby a jejich řešení](#10-možné-chyby-a-jejich-řešení)

---

## 1. K čemu systém slouží

**Hajime** je webová aplikace pro komplexní správu judo turnajů. Pokrývá celý životní cyklus akce:

- **Přihlašování závodníků** do turnaje a hmotnostních kategorií (synchronizace z externího systému ČSJÚ přes Flexii API)
- **Vážení závodníků** na váhách (Scale modul) s evidencí naměřené váhy
- **Generování soutěžních skupin a pavouků** (subcategory / draw systém)
- **Přidělování zápasů na tatami** (zápasiště)
- **Řízení průběhu zápasů** a evidenci výsledků (ippon, wazari, shido, hansoku-make…)
- **Zobrazení výsledků** v reálném čase na scoreboardu a informačním panelu
- **REST API** pro integraci s externími systémy (mobilní aplikace, portál ČSJÚ)

---

## 2. Typy uživatelů a přihlášení

| Typ uživatele | URL přihlášení | Přístup k modulům |
|---------------|---------------|-------------------|
| **Admin** | `/sign/in` | Plná správa turnaje (TournamentModule) |
| **Scale operátor** | `/scale/sign/in` | Vážení závodníků (ScaleModule) |
| **Scoreboard** | URL s heslem v parametru | Zobrazení výsledků (ScoreboardModule) |
| **Infopanel** | URL s heslem v parametru | Informační tabule (InfopanelModule) |
| **Superadmin** | Speciální přihlášení | Správa přes více turnajů |

### Přihlášení admina

1. Otevřít `/sign/in`
2. Zadat přihlašovací jméno (username) a heslo
3. Alternativně: přihlášení přes **Flexii SSO** (enterprise účet)
4. Po přihlášení je uživatel přesměrován do administrace turnaje

### Přihlášení scale operátora

1. Otevřít `/scale/sign/in`
2. Zadat jméno a heslo scale účtu
3. Přesměrování na rozhraní vážení

### Scoreboard a Infopanel

- Přihlášení probíhá přímo přes URL obsahující přihlašovací token
- Příklad: `http://judo.loc/infopanel/homepage/default/1`
- Hesla generuje admin v nastavení turnaje

---

## 3. Modul Admin – správa turnaje

### 3.1 Přehled turnaje (Homepage)

Po přihlášení se zobrazí přehledová stránka s:
- Seznamem dostupných turnajů
- Aktuálním stavem kategorií
- Rychlými akcemi (vážení, tatami, výsledky)

**Tlačítka a akce na přehledu:**

| Akce | Popis |
|------|-------|
| Vybrat turnaj | Přepnutí na jiný spravovaný turnaj |
| Nastavení turnaje | Otevře správu kategorií, vah a tatami |
| Závodníci | Přejde na seznam přihlášených závodníků |
| Tatami | Přejde na správu zápasiště |
| Výsledky | Zobrazí výsledky turnaje |

---

### 3.2 Nastavení turnaje (TournamentSettings)

Správa konfigurace turnaje:

**Věkové kategorie (CategoryAge)**
- Přidat věkovou kategorii (název, pohlaví, věk od/do, délka zápasu, golden score)
- Upravit parametry existující kategorie
- Nastavit toleranci váhy pro danou věkovou skupinu

**Hmotnostní kategorie (Category)**
- Přidat hmotnostní kategorii (název, váha od/do)
- Nastavit prioritu zobrazení
- Přiřadit věkové kategorii

**Váhy (Scale)**
- Přidat váhu (závaží stanů)
- Vygenerovat přihlašovací heslo pro scale operátora
- Tisknout přihlašovací lístek (`Tisknout hesla`)

**Tatami**
- Přidat tatami (zápasiště)
- Maximální počet tatami: **10**
- Maximální počet vah: **20**
- Vygenerovat přihlašovací heslo pro scoreboard a infopanel

---

### 3.3 Závodníci (Competitors)

Seznam závodníků přihlášených do turnaje.

**Záložka "Přihlášení závodníci":**
- Přehled závodníků s jejich kategoriemi
- Filtrování podle jména, klubu, kategorie
- Zobrazení stavu schválení přihlášky

**Záložka "Zvážení závodníci":**
- Závodníci, kteří již prošli vážením
- Zobrazení naměřené váhy a přiřazené subkategorie

---

### 3.4 Kategorie a generování pavouka (Category / SubCategory)

#### Přehled kategorie

Po kliknutí na hmotnostní kategorii se zobrazí:
- Seznam závodníků v kategorii
- Stav kategorie (otevřená / uzavřená / vygenerovaná)
- Subcategorie (párovací skupiny)

#### Generování pavouka (Shuffle)

1. Závodníci musí být zváženi a schváleni
2. Kliknout **"Generovat pavouk"**
3. Systém vytvoří párovací skupiny (SubCategory) a vygeneruje zápasy
4. Lze nastavit typ pavouka (Draw system): Table, Spider…

**Formulář nastavení pavouka:**

| Pole | Popis |
|------|-------|
| Draw system | Typ turnajového pavouka |
| Rozdělit podle pohlaví | Zda vytvořit separátní skupiny pro muže/ženy |
| Repechage | Povolit opravné kolo |

#### Zobrazení pavouka (Shuffle view)

- Vizuální zobrazení zápasů v pavouku
- Stav každého zápasu (čeká, probíhá, dokončen)
- Výsledky zápasů

---

### 3.5 Tatami – řízení zápasiště

Stránka tatami zobrazuje:
- Seznam aktivních tatami
- Frontu zápasů na každém tatami
- Aktuální stav zápasů

**Akce na tatami stránce:**

| Tlačítko | Popis |
|----------|-------|
| Přiřadit zápas | Přidá zápas do fronty na tatami |
| Spustit zápas | Označí zápas jako aktivní (nutné před přiřazením na tatami) |
| Přesunout zápas | Přeřazení zápasu na jiné tatami |
| Odstranit ze seznamu | Odebrání zápasu z fronty tatami |

> **Důležité:** Zápasy musí být nejprve spuštěny, než je lze přiřadit na tatami.

---

### 3.6 Výsledky (Results)

- Přehled výsledků po jednotlivých kategoriích
- Finální pořadí závodníků
- Export výsledků

---

## 4. Modul Scale – vážení závodníků

### Workflow vážení

1. **Přihlášení** scale operátora na `/scale/sign/in`
2. **Vyhledat závodníka** – zadat příjmení nebo ID (ČSJÚ)
3. **Načíst závodníka** z Flexii nebo lokální databáze
4. **Zadat váhu** – naměřená hodnota v kg
5. **Vybrat kategorii** – systém navrhne vhodnou hmotnostní kategorii
6. **Potvrdit vážení** – závodník je označen jako zvážený a schválený

### Formuláře vážení

**Hledat závodníka (SearchMember):**
- Pole pro příjmení nebo číslo závodníka
- Zobrazí seznam shod

**Načíst závodníka (LoadMember):**
- Načtení dat závodníka z Flexii API
- Kontrola existence v databázi turnaje

**Vážení (WeightMember):**
- Pole pro zadání váhy (desetinné číslo, kg)
- Výběr věkové kategorie
- Výběr hmotnostní kategorie
- Tlačítko **"Uložit váhu"**

### Po úspěšném vážení

- Flash zpráva: „Vážení bylo úspěšně uloženo"
- Přesměrování zpět na přehled (nebo na subcategorii při adminském přístupu)

---

## 5. Modul Scoreboard – výsledková tabule

Určen pro zobrazení na obrazovce v zápasiště během turnaje.

### Přihlášení

- Přes URL s přihlašovacím tokenem (generuje admin)
- Příklad: `http://judo.loc/scoreboard/homepage/default/[token]`

### Zobrazení

- Živé výsledky aktuálně probíhajících zápasů
- Skóre závodníků (ippon, wazari, shido)
- Čas zápasu
- Automatická aktualizace

---

## 6. Modul Infopanel – informační tabule

Určen pro zobrazení přehledu turnaje na informačních obrazovkách.

### Přihlášení

- Přes URL: `http://judo.loc/infopanel/homepage/default/[id]`

### Zobrazení

- Přehled probíhajících kategorií
- Pořadí zápasiště
- Výsledky dokončených kategorií

### Správa infopanelu (Manage)

Admin může přidat a konfigurovat infopanely přes `/infopanel/manage/`.

---

## 7. Workflow od začátku do konce turnaje

```
1. PŘÍPRAVA TURNAJE (Admin)
   ├── Synchronizace závodníků z ČSJÚ (přes Flexii API)
   ├── Nastavení věkových a hmotnostních kategorií
   ├── Přidání tatami a vah
   └── Vygenerování přihlašovacích hesel pro scale/scoreboard/infopanel

2. VÁŽENÍ (Scale operátor)
   ├── Přihlášení závodníků na scale
   ├── Naměření váhy
   └── Schválení přihlášky do kategorie

3. GENEROVÁNÍ PAVOUKA (Admin)
   ├── Uzavření přihlašování
   ├── Generování párovacích skupin (Shuffle)
   └── Kontrola a případná úprava pavouka

4. PRŮBĚH TURNAJE (Admin + Tatami)
   ├── Spuštění zápasů
   ├── Přiřazení zápasů na tatami
   ├── Zadávání výsledků zápasů
   └── Průběžné zobrazení na scoreboardu / infopanelu

5. VÝSLEDKY
   ├── Zobrazení finálního pořadí
   └── Export výsledků
```

---

## 8. Validace a omezení

### Závodník

| Validace | Pravidlo |
|----------|----------|
| Jméno | Povinné |
| Datum narození | Povinné, musí odpovídat věkové kategorii |
| Pohlaví | Povinné (muž / žena) |
| Klub | Povinné |

### Vážení

| Validace | Pravidlo |
|----------|----------|
| Váha | Povinná, kladné číslo (kg) |
| Váha | Musí být v rozsahu hmotnostní kategorie (± tolerance z CategoryAge) |
| Závodník | Musí být přihlášen do turnaje |
| Závodník | Nelze vážit vícekrát ve stejné kategorii |

### Kategorie

| Validace | Pravidlo |
|----------|----------|
| Rozsah váhy | `weight_from` < `weight_to` |
| Věkový rozsah | `age_from` < `age_to` |
| Délka zápasu | Kladné celé číslo (sekundy) |
| Golden score čas | Kladné celé číslo nebo prázdné (pokud je golden score zakázán) |

### Tatami a váhy

| Omezení | Hodnota |
|---------|---------|
| Maximální počet tatami na turnaj | 10 |
| Maximální počet vah na turnaj | 20 |

### Pavouk (Shuffle)

| Validace | Pravidlo |
|----------|----------|
| Generování pavouka | Závodníci musí být zváženi a schváleni |
| Stav kategorie | Nelze znovu generovat pavouk po uzamčení kategorie |
| Zápas na tatami | Zápas musí být nejprve „spuštěn" před přiřazením na tatami |

---

## 9. Přehled tlačítek a akcí

### Admin – Tournament Homepage

| Tlačítko / Akce | Popis |
|-----------------|-------|
| Vybrat turnaj | Přepnutí aktivního turnaje ze seznamu |
| Přejít na kategorii | Otevře detail hmotnostní kategorie |
| Nastavení | Otevře TournamentSettings |
| Tatami | Přejde na správu zápasiště |
| Závodníci | Seznam přihlášených závodníků |

### Admin – Kategorie

| Tlačítko / Akce | Popis |
|-----------------|-------|
| Nová kategorie | Formulář pro přidání hmotnostní kategorie |
| Generovat pavouk | Spustí algoritmus párování |
| Nastavení pavouka | Formulář výběru draw systému |
| Zobrazit pavouk | Přejde na vizuální zobrazení zápasů |
| Uzamknout kategorii | Uzavře přihlašování (nevratná akce) |

### Admin – SubCategory

| Tlačítko / Akce | Popis |
|-----------------|-------|
| Sloučit skupiny | Sloučení více subkategorií do jedné |
| Rozdělit skupiny | Oddělení závodníků do separátních skupin |
| Odeslat e-mail | Notifikace závodníkům v kategorii |
| Zobrazit výsledky | Výsledková tabulka subcategorie |

### Admin – Tatami

| Tlačítko / Akce | Popis |
|-----------------|-------|
| Přiřadit zápas | Přidá zápas do fronty tatami |
| Spustit zápas | Aktivuje zápas (nutné před přiřazením) |
| Přesunout | Přesun zápasu na jiné tatami |
| Odebrat | Odebrání zápasu z fronty |

### Scale

| Tlačítko / Akce | Popis |
|-----------------|-------|
| Hledat | Vyhledání závodníka podle příjmení / ID |
| Načíst ze Flexii | Import závodníka z externího systému |
| Uložit váhu | Uloží naměřenou váhu a schválí přihlášku |

### TournamentSettings

| Tlačítko / Akce | Popis |
|-----------------|-------|
| Přidat věkovou kategorii | Formulář pro novou věkovou kategorii |
| Přidat hmotnostní kategorii | Formulář pro novou váhovou kategorii |
| Přidat tatami | Přidá zápasiště |
| Přidat váhu | Přidá váhu pro vážení |
| Tisknout hesla | PDF s přihlašovacími údaji pro scale/scoreboard |

---

## 10. Možné chyby a jejich řešení

| Chyba / Situace | Příčina | Řešení |
|-----------------|---------|--------|
| „Nedostatečná oprávnění" po přihlášení | Přihlášen nesprávným účtem nebo bez přístupu k modulu | Přihlásit se správným typem účtu |
| Závodník se nezobrazuje v seznamu | Není přihlášen do turnaje nebo synchronizace ještě neproběhla | Zkontrolovat synchronizaci s Flexii / ČSJÚ |
| „Závodník již byl zvážen" | Dvojité přihlášení nebo duplicitní záznam | Zkontrolovat záznamy v SubCategory |
| Vážení mimo kategorii | Naměřená váha je mimo toleranci hmotnostní kategorie | Upravit toleranci v CategoryAge nebo zařadit do správné kategorie |
| Pavouk nelze generovat | Závodníci nejsou zváženi/schváleni, nebo kategorie je uzamčena | Dokončit vážení, zkontrolovat stav kategorií |
| Zápas nelze přiřadit na tatami | Zápas není ve stavu „spuštěn" | Nejprve kliknout „Spustit zápas" |
| Stránka vrací chybu 500 | Serverová chyba (debug vypnutý) | Zapnout Tracy debug mód nebo zkontrolovat log |
| Přihlášení na scoreboard / infopanel selhává | Neplatné nebo prošlé heslo v URL | Admin musí vygenerovat nové heslo v nastavení tatami |
| Flexii API nedostupné | Výpadek externího systému | Závodníka zadat ručně nebo počkat na obnovení spojení |
| Nelze načíst závodníka ze Flexii | Závodník nemá aktivní účet nebo nesprávné ID | Ověřit ID závodníka v systému ČSJÚ |

---

*Dokumentace vygenerována: 2026-05-31*