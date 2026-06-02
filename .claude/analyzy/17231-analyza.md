tlačítko rozlosování
action_shuffle: "Nastavit rozlosování"

tlačítko se zobrazuje v
app/Presentation/TournamentModule/templates/SubCategory/default.latte

---

**Q: Kde je napsaná obsluha tohoto tlačítka?**

Tlačítko neodešle formulář přímo — otevře Bootstrap modal (`data-bs-toggle="modal"`).
Modal obsahuje komponentu `ShuffleSettingsFormControl`.

Obsluha je rozepsána ve třech metodách v:
`app/Presentation/TournamentModule/Components/Forms/ShuffleSettingsForm/ShuffleSettingsFormControl.php`

1. `formValidate()` (řádek 231) — validuje vstupy (typ losování, počty skupin, stav subkategorie)
2. `formSucceeded()` (řádek 319) — zpracuje odeslání; pro každou subkategorii zavolá
   `$this->statusController->stateShuffle(...)` (řádek 353), která provede samotné rozlosování
3. `redirectOnSubmit()` (řádek 365) — přesměruje zpět na stránku subkategorie

Klíčová business logika rozlosování je tedy v `StatusController::stateShuffle()`.

Na straně VP jsem našel místo
hyperlink_to: '/tournaments/uid/{tournament_uid}/tables?subcategory_id={subcategory_id|IF_TRUTHY}{is_shuffled|IF_TRUTHY|ERASE}'
dostavat is_shuffle_published....

---

## Q&A log — 2026-06-02

**2026-06-02 07:35 — Budeme potřebovat 3 projekty, hajime, dwh a výsledkový portál**

Potvrzeny adresáře:
- Hajime → `judo-external-hajime/`
- DWH → `dwh/`
- Výsledkový portál → `judo-vysledkovy-portal/`

**2026-06-02 07:35 — Potřebuju abys do souboru s analýzou zapisoval vždy můj dotaz a tvoji odpověď.**

Soubor je `/home/tomas/projekty/evosoft/.claude/analyzy/17231-analyza.md`. Od teď každý dotaz a odpověď zapisuji sem.

---

**2026-06-02 07:38 — V VP máme url `hyperlink_to` s parametrem `is_shuffled`. Prověř jestli API od Hajime a od DWH toto vrací. Pokud ano na jaké URL.**

**Výsledek:** `is_shuffled` **není pole z API** — jde o odvozenou hodnotu přímo ve VP.

### Hajime API

- Endpoint: `GET /api/open/tournament/{uid}/subcategory`
- Vrací: `ResponseSubCategoryDto` — obsahuje pole **`status`** (string)
- Možné hodnoty statusu: `waiting`, `shuffled`, `matches_started`, `finished`, `cancelled`
- Pole `is_shuffled` **neexistuje** — VP si ho odvodí z `status`

### DWH

- Tabulka: `DWH::TOURNAMENT_CATEGORIES` (alias `tc`)
- Čte: **`tc.tc__status as status`**
- Stejné hodnoty jako Hajime
- Pole `is_shuffled` **neexistuje**

### VP — kde vzniká `is_shuffled`

Soubor: `src/Entity/DTO/Datagrid/TournamentCategoryRowDTO.php:89`

```php
$this->is_shuffled = $status === SubCategoryStatusEnum::STATUS_SHUFFLED      // 'shuffled'
                  || $status === SubCategoryStatusEnum::STATUS_FINISHED        // 'finished'
                  || $status === SubCategoryStatusEnum::STATUS_MATCHES_STARTED; // 'matches_started'
```

DTO se plní ze dvou zdrojů:
- **Hajime** (živý turnaj): `fromArray()` — data přicházejí z `GET /api/open/tournament/{uid}/subcategory`
- **DWH** (ukončený turnaj): `fromRow()` — data přicházejí z DB dotazu v `TournamentDetailDWHRepository::getSubcategoriesDatagridData()`

### Závěr pro implementaci 17231

Aktuálně `is_shuffled = (status IN [shuffled, matches_started, finished])` — tedy link na tabulky je aktivní hned po rozlosování, bez ohledu na to zda byl los zveřejněn.

Nový příznak **`publish_shuffle`** bude muset:
1. **Hajime** — přidat pole `publish_shuffle` do `ResponseSubCategoryDto` a vracet ho v API
2. **DWH** — přijímat a ukládat `publish_shuffle` při synchronizaci z Hajime
3. **VP** — místo odvozování z `status` číst přímo `is_shuffle_published` z API/DWH a použít ho v `hyperlink_to`

