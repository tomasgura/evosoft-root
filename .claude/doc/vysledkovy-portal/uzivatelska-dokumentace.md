# Uživatelská dokumentace — Judo Výsledkový portál

## K čemu portál slouží

Judo výsledkový portál je veřejná webová aplikace Českého svazu juda (ČSJÚ), která umožňuje:

- Procházet **seznam judistických turnajů** (plánovaných, probíhajících, archivních)
- Sledovat **live výsledky** probíhajících turnajů
- Prohlížet **výsledky** a **losování** (pavouk/tabulka) z jednotlivých kategorií
- Vyhledávat **zápasnické členy** a zobrazit jejich kariérní statistiky
- Procházet **kluby** a seznam jejich členů
- Exportovat výsledky do **PDF** nebo **XLSX**

---

## Sekce aplikace

### Turnaje (`/tournaments`)

**Záložky:** Aktuální | Plánované | Archiv

#### Co zobrazuje seznam turnajů
- Název a typ turnaje
- Pořádající klub a místo konání
- Datum konání
- Příznak: mezinárodní turnaj, žebříčkový turnaj
- Stav turnaje (probíhá / plánovaný / ukončený)

#### Filtrování a řazení
- Vyhledávání podle názvu (autocomplete pole v hlavičce)
- Filtr ve sloupcích tabulky (kliknutím na ikonu filtru ve sloupci)
- Řazení kliknutím na hlavičku sloupce

#### Detail turnaje

Záložky detailu:
- **Základní info** — název, pořadatel, datum, místo, ředitel, typ
- **Výsledky** — výběr věkové kategorie a podkategorie (váhová skupina), tabulka výsledků
- **Zápasy** — live nebo archivní přehled zápasů s tatami přiřazením
- **Tabulky** — losovací diagram (pavouk nebo tabulka round-robin)
- **Statistiky** — souhrn (počty zápasnících, zápasů, tatami)
- **Videa** — embedded YouTube videa z turnaje
- **Přihlášení** — seznam přihlášených zápasnících s filtrem

#### Výsledky kategorie
1. Vyber věkovou kategorii (např. Muži, Ženy, Kadeti)
2. Vyber podkategorii (váhová skupina, např. -66 kg)
3. Zobrazí se výsledková listina s pořadím a zápasnickou

#### Export výsledků
- Tlačítka **PDF** a **XLSX** jsou dostupná na záložce Výsledky
- Stahuje se soubor se všemi věkovými kategoriemi

#### Výsledkové soubory od pořadatelů
- Pokud pořadatel nahrál soubor přes Flexii, bude ke stažení v detailu turnaje

---

### Členové (`/members`)

#### Co zobrazuje seznam
- Celé jméno, klub, rok narození
- Technická úroveň (kyu/dan)
- Národnost (vlajka)

#### Detail člena
- Základní informace (jméno, věk, klub, technický stupeň, datum udělení)
- **Statistiky** — počty turnajů, vítězství, porážek
- **Turnaje** — seznam turnajů, kterých se člen zúčastnil (s filtrem a řazením)
- **Zápasy** — seznam zápasů se jmény soupeřů a výsledky

#### Vyhledávání
- Autocomplete pole v navigaci — vyhledáš jménem
- Filtr i v tabulce seznamu

---

### Kluby (`/clubs`)

#### Co zobrazuje seznam
- Název klubu (zkratka ČSJÚ + plný název)
- Stát (vlajka)
- Počet členů

#### Detail klubu
- Kontaktní informace (web, email, telefon)
- Adresa (hlavní + korespondenční)
- Logo klubu
- Počet členů
- **Tabulka členů** — filtrování a řazení

---

### Statistiky (`/statistics`)

- Globální statistiky napříč všemi turnaji a členy
- Grafy (sloupcové)

---

## Vyhledávání

Na každé stránce je v navigaci rychlé vyhledávací pole:
- Hledá turnaje, členy i kluby najednou
- Funguje jako autocomplete — výsledky se zobrazují průběžně od 2 znaků
- Enter nebo klik na výsledek přejde na detail

---

## Workflow — jak najít výsledky konkrétního zápasnického

1. Otevři sekci **Členové**
2. Do vyhledávacího pole zadej jméno zápasnického
3. Klikni na výsledek → otevře se detail člena
4. Na záložce **Turnaje** vidíš všechna účastněná klání
5. Kliknutím na turnaj přejdeš na výsledky toho konkrétního turnaje

---

## Validace a omezení

- Vyhledávání funguje od **2 znaků**
- Výsledky jsou cachované — aktualizace se projeví po uplynutí cache TTL (obvykle hodiny)
- Live data (zápasy, tabulky) se pro probíhající turnaje obnovují automaticky (každých ~60 s)
- Aplikace je **read-only** — nelze editovat žádná data

---

## Možné chyby a jejich příčiny

| Chyba | Pravděpodobná příčina | Co dělat |
|---|---|---|
| Výsledky turnaje nejsou aktuální | DWH ETL ještě neproběhl, nebo cache | Počkat na refresh, kontaktovat správce |
| Live zápasy se nezobrazují | Hajime API není dostupné | Kontaktovat správce |
| Export nefunguje | Server error při generování PDF/XLSX | Kontaktovat správce, zkusit znovu |
| Vyhledávání nenajde nic | Špatný přepis jména, nebo data nejsou v DWH | Zkusit variaci jména |
| Logo klubu chybí | Sync ještě neproběhl nebo klub logo nemá | Kontaktovat správce |
| 500 chyba | Chyba serveru | Kontaktovat správce |

---

## Tlačítka a akce

| Prvek | Akce |
|---|---|
| Záložky „Aktuální / Plánované / Archiv" | Přepnutí filtru stavu turnajů |
| Hlavička sloupce v tabulce | Seřazení podle sloupce (klik = ASC, klik znovu = DESC) |
| Ikona filtru ve sloupci | Otevření filtrovacího pole pro sloupec |
| Výběr věkové kategorie | Načte výsledky pro tuto kategorii |
| Výběr podkategorie (váha) | Načte výsledky pro danou váhovou skupinu |
| Výběr tatami | Filtruje live zápasy podle tatami |
| Tlačítko PDF | Stáhne výsledky ve formátu PDF |
| Tlačítko XLSX | Stáhne výsledky ve formátu Excel |
| Jméno zápasnického v tabulce | Přejde na profil člena |
| Název turnaje v tabulce | Přejde na detail turnaje |
| Název klubu v tabulce | Přejde na detail klubu |
| Odkaz „Výsledkový soubor" | Stáhne soubor od pořadatele (pokud existuje) |

---

## Live výsledky (probíhající turnaje)

- Zobrazují se na záložce **Zápasy** a **Tabulky**
- Data se aktualizují každých ~60 sekund (automaticky, bez nutnosti obnovit stránku)
- Dostupné pouze pro turnaje s příznakem „Hajime" (live systém)
- Výsledky se přesunou do záložky **Výsledky** po ukončení kategorie
