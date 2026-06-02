# Analýza: #17321 – Název kola (round_name) v portálu výsledků

## Kontext

Stránka `/tournaments/uid/{uid}/matches` na portálu `portal.czechjudo.org` zobrazuje zápasy turnaje.
Příklad: `https://portal.czechjudo.org/tournaments/uid/1099619/matches?member_value=Filip%20Wolf&member_uid=1045698&subcategory_id=8419`

Pole `round_name` se zobrazuje v `MatchDisplay.html.twig` jako:
```twig
<span class="fw-semibold">{{ match.round_name }}</span>
```

---

## Tok dat pro historické turnaje (DWH cesta)

```
judo.tournament_has_match.round_name   ← Hajime DB (192.168.88.165)
    ↓  data_source 'thm__ds_1' (UPDATE v c6/2025-12-16-00-tatami-add-priority.xml)
    jthm.round_name as thm__round_name
    ↓  DWH dataset_part 'tournament_match_main'
    thm__round_name (typ: string)
    ↓  materialized view export.mv_dataset_export_tournament_match_tournament_match_main
    thm__round_name
    ↓  portal SQL (COALESCE(thm__round_name, '') as round_name)
    match.round_name → zobrazení v šabloně
```

---

## Klíčové soubory v DWH projektu

| Soubor | Co dělá |
|--------|---------|
| `resources/hyperdrive/customer-data/c6/2025-01-30-103711-hajime.xml` | Zakládá dataset `tournament_match` a `tournament_match_main`, původní data_source query |
| `resources/hyperdrive/customer-data/c6/2025-07-29-122846-add-tatami.xml` | Přidává tatami, rozšiřuje query o `jthm.round_name as thm__round_name` |
| `resources/hyperdrive/customer-data/c6/2025-12-16-00-tatami-add-priority.xml` | Poslední UPDATE query pro `thm__ds_1` – aktuálně platná podoba dotazu |
| `resources/hyperdrive/customer-data/c6/2026-06-01-17321-name-of-round.xml` | **Stub pro tuto feature** – TODO komentář, sem patří budoucí změna |

---

## Co je potřeba změnit (DWH část)

Hodnota `thm__round_name` přichází raw z Hajime (`judo.tournament_has_match.round_name`).
Pokud potřebujeme zobrazovat jiný (lidsky čitelný) název kola, máme tyto možnosti:

1. **Transformace v data_source query** – upravit `UPDATE data.data_source WHERE name = 'thm__ds_1'`
   v novém migration souboru, přidat CASE/COALESCE/lookup pro `round_name`.
2. **Enrich vrstva** – přidat enrichment nad `thm__round_name` v DWH pipeline.
3. **Změna v Hajime** – nechat Hajime posílat správnou hodnotu (změna v projektu Hajime).

Po změně query v DWH se portal aktualizuje automaticky – čte z materialized view,
která se rebuilduje po importu.

---

## Q&A

### Když v Hajime změním `round_name`, propíše se to do DWH správně?

**Ano.** Při příštím importu DWH se hodnota `thm__round_name` automaticky aktualizuje pro všechny záznamy.

Důvod – konfigurace data_source `thm__ds_1`:

- **Query načítá VŠECHNY záznamy** z Hajime (`WHERE 1 = 1`, bez datového filtru). Import vždy prochází celou tabulku `judo.tournament_has_match`, takže nezáleží na tom, kdy byl původní zápas importován.
- **`is_update_only_previous_data = FALSE`** → DWH aktualizuje i záznamy, které v DWH už existují (nejen nové).
- **`is_rewrite_value_by_null = FALSE`** → Hodnota se přepíše, pokud je nová hodnota z Hajime nenulová. Pokud by Hajime poslal NULL, stará hodnota zůstane. Pokud posílá string (nový název kola), přepíše se. ✓
- **Historizace: žádná** (`id_lookup_dataset_historization = NULL`) → DWH nepřekrývá staré hodnoty jako historii, prostě je přepíše. Neexistuje "zamrazená" minulost pro `tournament_match`.

**Postup po změně v Hajime:**
1. Hajime změní `round_name` v `judo.tournament_has_match`
2. Spustí se DWH import jobu pro dataset `tournament_match`
3. DWH aktualizuje `thm__round_name` v `dataset_values`
4. Materialized view `export.mv_dataset_export_tournament_match_tournament_match_main` se rebuilduje
5. Portál zobrazí nová data (bez deploy portálu)

---

### Jak se import spouští? Platí to i pro ukončené turnaje?

**Import se nespouští automaticky cronem.** V migracích neexistuje žádný `job_definition` pro dataset `tournament_match`. Import se spouští **externím triggerem** – REST API voláním:

```
POST /api/v1/action/get-data/{dataset_entity_name}
Header: apiToken: <token>
```

Pravděpodobný scénář: Hajime zavolá tento endpoint po ukončení turnaje (webhook/trigger z Hajime projektu).

**Ale data ze VŠECH turnajů (i historických) se updatují najednou**, protože query `thm__ds_1` načítá `WHERE 1 = 1` – žádný filtr na datum nebo stav turnaje. Jeden import = refresh všech zápasů ze všech turnajů.

**Co to znamená pro změnu `round_name`:**

| Scénář | Výsledek |
|--------|---------|
| Nový turnaj proběhne (Hajime trigger se zavolá) | ✅ Automaticky se přepíše `round_name` pro VŠECHNY záznamy |
| Chceme updatovat data BEZ nového turnaje | ⚠️ Musíme import spustit ručně |

**Jak ručně spustit import pro ukončené turnaje:**

Možnost A – REST API (vyžaduje apiToken):
```bash
curl -X POST "https://<dwh-host>/api/v1/action/get-data/<entity_name>" \
  -H "apiToken: <token>" \
  -H "Content-Type: application/json"
```

Možnost B – DWH Admin UI: DataModule → dataset entity `tournament_match` → spustit akci "Get Data"

Po spuštění importu DWH automaticky rebuilduje materialized view a portál zobrazí aktualizovaná data.

### Dotčená místa v portálu (pro referenci, ne naše repo)
- `TournamentDetailDWHRepository::getMatches()` – `COALESCE(thm__round_name, '') as round_name`
- `TournamentDetailDWHRepository::getTatamiMatches()` – `COALESCE(thm__round_name, '') as round_name`
- `MatchRepository::getMemberMatches()` – `COALESCE(thm__round_name, '') as round_name`

---

## Zdroj `round_name` v Hajime (live turnaje)

Pro živé turnaje jde data přes Hajime API (ne DWH), klíč `round_name` v JSON odpovědi
z `/api/open/tournament/{uid}/subcategory-matches/{id}`. Změna pro live turnaje = změna v projektu Hajime.
