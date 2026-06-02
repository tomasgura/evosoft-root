# Datové schéma – Hajime

> PostgreSQL 15 · schéma `judo`  
> Zdroj: ORM entity (`app/Data/`) + mappery + migrace (`resources/hyperdrive/structure/`)

---

## Obsah

1. [Přehled tabulek](#1-přehled-tabulek)
2. [ER diagram – vazby](#2-er-diagram--vazby)
3. [Tabulky – detail sloupců](#3-tabulky--detail-sloupců)
4. [Cizí klíče (FK)](#4-cizí-klíče-fk)
5. [Datové typy a konvence](#5-datové-typy-a-konvence)

---

## 1. Přehled tabulek

Všechny tabulky leží ve schématu **`judo`** (pokud není uvedeno jinak).

| Tabulka | ORM entita | Popis |
|---------|-----------|-------|
| `tournament` | Tournament | Turnaj |
| `tournament_has_member` | Member | Závodník přihlášený do turnaje |
| `tournament_has_club` | Club | Klub v turnaji |
| `admin` | Admin | Administrátor |
| `admin_has_tournament` | *(junction m:n)* | Admin ↔ Tournament |
| `tournament_has_scale` | Scale | Váha v turnaji |
| `tournament_has_tatami` | Tatami | Zápaziště v turnaji |
| `tatami_has_match` | TatamiMatch | Slot zápasu na tatami |
| `tournament_has_category` | Category | Hmotnostní kategorie |
| `tournament_has_category_age` | CategoryAge | Věková kategorie |
| `tournament_has_subcategory` | SubCategory | Párovací skupina / pavouk |
| `tournament_has_member_has_category` | MemberCategory | Přihláška závodníka do kategorie |
| `tournament_has_match` | TournamentMatch | Zápas v pavouku |
| `match_data` | TournamentMatchData | JSON audit log změn zápasu |
| `tournament_has_infopanel` | InfoPanel | Informační panel |
| `subcategory_has_results` | SubCategoryResults | Výsledky párovací skupiny |

---

## 2. ER diagram – vazby

```
                           ┌─────────────┐
                    ┌──────┤   ADMIN     ├──────────────────────┐
                    │  m:n └─────────────┘ m:n                  │ 1:m
                    │                                    ┌──────▼──────────┐
                    │                                    │  tatami_has_match│
         ┌──────────▼──────────┐                        │  (TatamiMatch)   │
         │     TOURNAMENT       │◄──────────────────────┤  id_admin        │
         │  (tournament)        │         1:m           └──────┬───────────┘
         └──────────┬───────────┘                              │ 1:1
                    │ 1:m (ve všech níže)                      ▼
       ┌────────────┼─────────────────┐            ┌──────────────────────┐
       ▼            ▼                 ▼            │  tournament_has_match │
  ┌─────────┐ ┌──────────┐ ┌──────────────────┐   │  (TournamentMatch)    │
  │  Scale  │ │  Tatami  │ │   CategoryAge    │   │  id_member_cat_blue  │
  └─────────┘ └──────────┘ └────────┬─────────┘   │  id_member_cat_white │
                                    │ 1:m          └──────────┬───────────┘
                                    ▼                         │ 1:m
                          ┌──────────────────┐       ┌───────▼──────────┐
                          │    Category       │       │   match_data      │
                          └────────┬─────────┘       │   (JSON log)      │
                                   │ 1:m             └──────────────────┘
                                   ▼
                          ┌──────────────────┐
                          │   SubCategory     │
                          └────────┬─────────┘
                                   │ 1:m
                    ┌──────────────┼──────────────────┐
                    ▼                                  ▼
        ┌───────────────────────┐        ┌──────────────────────┐
        │ MemberCategory        │        │  TournamentMatch      │
        │ (přihláška závodníka) │        │  (zápas v pavouku)    │
        └───────────┬───────────┘        └──────────────────────┘
                    │ m:1
                    ▼
             ┌────────────────┐     m:1
             │    Member      ├──────────► Club
             └────────────────┘
```

---

## 3. Tabulky – detail sloupců

### tournament

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `uid` | VARCHAR(400) NOT NULL | Externě sdílený identifikátor |
| `tournament_csju_id` | INT NOT NULL | ID v systému ČSJÚ |
| `name` | VARCHAR(400) NOT NULL | Název turnaje |
| `dt_tournament_start` | TIMESTAMP | Datum začátku |
| `dt_tournament_end` | TIMESTAMP | Datum konce |
| `dt_term_for_registration` | TIMESTAMP | Uzávěrka přihlášek |
| `location` | VARCHAR | Místo konání |
| `street` | VARCHAR | Ulice |
| `street_number` | VARCHAR | Číslo orientační |
| `house_number` | VARCHAR | Číslo popisné |
| `city` | VARCHAR | Město |
| `postal_code` | VARCHAR | PSČ |
| `address_region` | VARCHAR | Kraj |
| `country` | VARCHAR | Země |
| `tatami_count` | INT | Počet zápazišť |
| `scale_count` | INT | Počet vah |
| `tournament_starting_fee` | INT | Startovné (Kč) |
| `web_link_for_registration` | VARCHAR | URL registrace |
| `type` | VARCHAR (enum) | Typ turnaje |
| `is_approved` | BOOLEAN | Schválen |
| `results_are_approved` | BOOLEAN | Výsledky schváleny |
| `enabled` | BOOLEAN | Aktivní záznam |
| `dt_ins` | TIMESTAMP DEFAULT now() | Datum vložení |
| `dt_upd` | TIMESTAMP | Datum poslední změny |

---

### tournament_has_member

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `uid` | VARCHAR NOT NULL | Externě sdílený identifikátor |
| `member_csju_id` | VARCHAR NOT NULL | ID závodníka v ČSJÚ |
| `firstname` | VARCHAR NOT NULL | Jméno |
| `lastname` | VARCHAR NOT NULL | Příjmení |
| `gender` | VARCHAR (enum) | Pohlaví (men/women) |
| `dt_birth` | DATE | Datum narození |
| `dt_birthyear` | INT | Rok narození |
| `kyu` | VARCHAR | Technická úroveň kyu |
| `dan` | VARCHAR | Technická úroveň dan |
| `dt_flexii_edit` | TIMESTAMP | Datum syncu z Flexii |
| `dt_match_end` | TIMESTAMP | Datum konce posledního zápasu |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `id_club` | INT FK→tournament_has_club.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_club

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `uid` | VARCHAR | |
| `name` | VARCHAR NOT NULL | Název klubu |
| `abbreviation` | VARCHAR | Zkratka |
| `short_name` | VARCHAR | Krátký název |
| `country` | VARCHAR | Země |
| `country_alpha2` | VARCHAR(2) | ISO 3166 alpha-2 |
| `country_alpha3` | VARCHAR(3) | ISO 3166 alpha-3 |
| `location` | VARCHAR | Město/lokalita |
| `city` | VARCHAR | Město |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### admin

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `uid` | VARCHAR | |
| `full_name` | VARCHAR NOT NULL | Celé jméno |
| `password` | VARCHAR NOT NULL | Hashované heslo |
| `flexii_account` | VARCHAR | Propojení s Flexii účtem |
| `is_super_admin` | BOOLEAN DEFAULT false | Superadmin |
| `enabled` | BOOLEAN | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### admin_has_tournament *(m:n junction)*

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id_admin` | INT FK→admin.id | |
| `id_tournament` | INT FK→tournament.id | |

---

### tournament_has_scale

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `name` | VARCHAR NOT NULL | Název váhy |
| `password` | VARCHAR NOT NULL | Heslo pro přihlášení |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_tatami

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `name` | VARCHAR NOT NULL | Název tatami |
| `password` | VARCHAR NOT NULL | Heslo pro scoreboard |
| `priority` | INT | Pořadí zobrazení |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tatami_has_match

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `priority` | INT | Pořadí v frontě tatami |
| `enabled` | BOOLEAN | |
| `id_tournament_has_tatami` | INT FK→tournament_has_tatami.id | |
| `id_tournament_has_match` | INT FK→tournament_has_match.id | 1:1 |
| `id_admin` | INT FK→admin.id | Odpovědný rozhodčí |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_category_age

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `gender` | VARCHAR (enum) | Pohlaví (men/women/both) |
| `age_name` | VARCHAR NOT NULL | Název věkové kategorie |
| `age_name_short` | VARCHAR | Zkrácený název |
| `age_from` | INT | Věk od (let) |
| `age_to` | INT | Věk do (let) |
| `match_time` | INT | Délka zápasu (sekundy) |
| `is_golden_score` | BOOLEAN | Povoleno prodloužení |
| `golden_score_time` | INT | Délka golden score (sekundy) |
| `weight_tolerance` | FLOAT | Tolerance váhy (kg) |
| `listed` | BOOLEAN | Zobrazit v přehledu |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_category

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `weight_name` | VARCHAR NOT NULL | Název (např. „-60 kg") |
| `weight_from` | INT | Váha od (kg) |
| `weight_to` | INT | Váha do (kg) |
| `status` | VARCHAR (enum) | Stav kategorie |
| `priority` | INT | Pořadí zobrazení |
| `merged_into` | INT | ID cílové kategorie při sloučení |
| `listed` | BOOLEAN | Zobrazit v přehledu |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `id_tournament_has_category_age` | INT FK→tournament_has_category_age.id | |
| `id_tournament_has_category_plus` | INT FK→tournament_has_category.id | Seberef. (volitelná nadkategorie) |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_subcategory

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `draw_system` | VARCHAR (enum) | Typ pavouka |
| `draw_system_extra` | VARCHAR | Doplňkový parametr pavouka |
| `gender_split` | BOOLEAN | Rozdělit dle pohlaví |
| `status` | VARCHAR (enum) | Stav skupiny |
| `is_repechage` | BOOLEAN | Opravné kolo |
| `is_one_third_place` | BOOLEAN | Souboj o 3. místo |
| `table_continue` | BOOLEAN | Pokračovat v tabulkovém systému |
| `weight` | FLOAT | Výsledná průměrná váha skupiny |
| `priority` | INT | Pořadí |
| `customName` | VARCHAR | Vlastní název skupiny |
| `results_printed` | BOOLEAN | Výsledky vytištěny |
| `shuffle_printed` | BOOLEAN | Pavouk vytištěn |
| `additional_weighting_enabled` | BOOLEAN | Povoleno doplňkové vážení |
| `enabled` | BOOLEAN | |
| `id_tournament_has_category` | INT FK→tournament_has_category.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_member_has_category

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `is_approved` | BOOLEAN | Přihláška schválena (po vážení) |
| `is_dnf` | BOOLEAN | Závodník nenastoupil |
| `is_results_excluded` | BOOLEAN | Vyloučen z výsledků |
| `is_preregistered` | BOOLEAN | Pouze předregistrace |
| `starting_number` | INT | Startovní číslo |
| `weight` | FLOAT | Naměřená váha (kg) |
| `seeding` | INT | Nasazení v pavouku |
| `enabled` | BOOLEAN | |
| `id_tournament_has_member` | INT FK→tournament_has_member.id | |
| `id_tournament_has_category_age` | INT FK→tournament_has_category_age.id | |
| `id_tournament_has_category_age_preregistered` | INT FK | Předregistrace – věk. kategorie |
| `id_tournament_has_category` | INT FK→tournament_has_category.id | |
| `id_tournament_has_category_preregistered` | INT FK | Předregistrace – hmot. kategorie |
| `id_tournament_has_subcategory` | INT FK→tournament_has_subcategory.id | |
| `id_tournament_has_scale` | INT FK→tournament_has_scale.id | Kde byl zvážen |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_match

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `subcategory_match_number` | VARCHAR NOT NULL | Identifikátor v pavouku |
| `status` | VARCHAR (enum) | Stav zápasu |
| `is_blue_winner` | BOOLEAN | true=modrý vyhrál, false=bílý |
| `is_skipped` | BOOLEAN | Zápas přeskočen |
| `match_number` | INT | Číslo zápasu |
| `round` | INT | Kolo pavouka |
| `round_name` | VARCHAR | Název kola (Final, SF, R8…) |
| `start_datetime` | TIMESTAMP | Čas začátku zápasu |
| `end_datetime` | TIMESTAMP | Čas konce zápasu |
| `current_match_time` | FLOAT | Aktuální čas zápasu (sec) |
| `current_match_time_left` | FLOAT | Zbývající čas (sec) |
| `gs_start_datetime` | TIMESTAMP | Začátek golden score |
| `gs_end_datetime` | TIMESTAMP | Konec golden score |
| `current_gs_time` | FLOAT | Aktuální GS čas |
| `reset_counter` | INT | Počet resetů |
| `winner_score` | FLOAT | Výsledné skóre vítěze |
| `osaekomi_records` | VARCHAR | Záznamy oseakomi |
| `blue_ippon` | BOOLEAN | Ippon modrého |
| `blue_wazari` | INT | Wazari modrého |
| `blue_wazari_time_1` | TIMESTAMP | Čas prvního wazari |
| `blue_yuko` | INT | Yuko modrého |
| `blue_yuko_times` | VARCHAR | Časy yuko |
| `blue_shido` | INT | Shido modrého |
| `blue_shido_time_1` | TIMESTAMP | Čas prvního shido |
| `blue_shido_time_2` | TIMESTAMP | Čas druhého shido |
| `blue_hansoku_make` | BOOLEAN | Diskvalifikace modrého |
| `blue_oseakomi` | INT | Oseakomi modrého |
| `blue_judge_point` | BOOLEAN | Bod od rozhodčího (modrý) |
| `blue_fusen_kiken_gachi` | BOOLEAN | Vítězství kontumací (modrý) |
| *(stejné sloupce pro white_…)* | | Skóre bílého závodníka |
| `enabled` | BOOLEAN | |
| `id_tournament_has_subcategory` | INT FK→tournament_has_subcategory.id | |
| `id_tournament_has_member_category_blue` | INT FK→tournament_has_member_has_category.id | |
| `id_tournament_has_member_category_white` | INT FK→tournament_has_member_has_category.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### match_data

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `match_data` | JSONB | Snapshot stavu zápasu při každé změně |
| `timestamp` | TIMESTAMP NOT NULL | Čas změny |
| `enabled` | BOOLEAN | |
| `id_tournament_has_match` | INT FK→tournament_has_match.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### tournament_has_infopanel

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

### subcategory_has_results

| Sloupec | Typ | Popis |
|---------|-----|-------|
| `id` | SERIAL PK | |
| `member_rank` | INT | Výsledné pořadí závodníka |
| `enabled` | BOOLEAN | |
| `id_tournament` | INT FK→tournament.id | |
| `id_subcategory` | INT FK→tournament_has_subcategory.id | |
| `id_member` | INT FK→tournament_has_member.id | |
| `dt_ins` | TIMESTAMP DEFAULT now() | |
| `dt_upd` | TIMESTAMP | |

---

## 4. Cizí klíče (FK)

| Tabulka | Sloupec (FK) | Odkazuje na |
|---------|-------------|-------------|
| `tournament_has_member` | `id_tournament` | `tournament.id` |
| `tournament_has_member` | `id_club` | `tournament_has_club.id` |
| `tournament_has_club` | `id_tournament` | `tournament.id` |
| `admin_has_tournament` | `id_admin` | `admin.id` |
| `admin_has_tournament` | `id_tournament` | `tournament.id` |
| `tournament_has_scale` | `id_tournament` | `tournament.id` |
| `tournament_has_tatami` | `id_tournament` | `tournament.id` |
| `tatami_has_match` | `id_tournament_has_tatami` | `tournament_has_tatami.id` |
| `tatami_has_match` | `id_tournament_has_match` | `tournament_has_match.id` *(1:1)* |
| `tatami_has_match` | `id_admin` | `admin.id` |
| `tournament_has_category_age` | `id_tournament` | `tournament.id` |
| `tournament_has_category` | `id_tournament` | `tournament.id` |
| `tournament_has_category` | `id_tournament_has_category_age` | `tournament_has_category_age.id` |
| `tournament_has_category` | `id_tournament_has_category_plus` | `tournament_has_category.id` *(self-ref)* |
| `tournament_has_subcategory` | `id_tournament_has_category` | `tournament_has_category.id` |
| `tournament_has_member_has_category` | `id_tournament_has_member` | `tournament_has_member.id` |
| `tournament_has_member_has_category` | `id_tournament_has_category` | `tournament_has_category.id` |
| `tournament_has_member_has_category` | `id_tournament_has_category_age` | `tournament_has_category_age.id` |
| `tournament_has_member_has_category` | `id_tournament_has_subcategory` | `tournament_has_subcategory.id` |
| `tournament_has_member_has_category` | `id_tournament_has_scale` | `tournament_has_scale.id` |
| `tournament_has_match` | `id_tournament_has_subcategory` | `tournament_has_subcategory.id` |
| `tournament_has_match` | `id_tournament_has_member_category_blue` | `tournament_has_member_has_category.id` |
| `tournament_has_match` | `id_tournament_has_member_category_white` | `tournament_has_member_has_category.id` |
| `match_data` | `id_tournament_has_match` | `tournament_has_match.id` |
| `tournament_has_infopanel` | `id_tournament` | `tournament.id` |
| `subcategory_has_results` | `id_tournament` | `tournament.id` |
| `subcategory_has_results` | `id_subcategory` | `tournament_has_subcategory.id` |
| `subcategory_has_results` | `id_member` | `tournament_has_member.id` |

---

## 5. Datové typy a konvence

### Společné sloupce (všechny tabulky)

| Sloupec | Typ | Výchozí | Popis |
|---------|-----|---------|-------|
| `id` | SERIAL / BIGSERIAL | auto | Primární klíč |
| `enabled` | BOOLEAN | true | Soft-delete příznak |
| `dt_ins` | TIMESTAMP | `now()` | Datum vložení záznamu |
| `dt_upd` | TIMESTAMP | `now()` | Datum poslední změny (auto trigger) |

### Trigger `update_dt_upd`

Automaticky nastavuje `dt_upd = now()` při každém UPDATE. Definován v první migraci (`2023-08-03-120000-judo.xml`).

### Enums (jako VARCHAR s validací v PHP)

| Pole | Hodnoty |
|------|---------|
| `gender` | `men`, `women`, `both` |
| `tournament.type` | viz `TournamentTypeEnum` |
| `tournament_has_category.status` | viz `CategoryStatusEnum` |
| `tournament_has_subcategory.status` | viz `SubCategoryStatusEnum` |
| `tournament_has_subcategory.draw_system` | viz `DrawSystemEnum` |
| `tournament_has_match.status` | viz `MatchStatusEnum` |

### Soft-delete

Záznamy se fyzicky nemažou. Sloupec `enabled = false` je ekvivalent smazání. ORM repozitáře filtrují `WHERE enabled = true` automaticky.

### Schémata

`search_path` je nastaven na: `configuration, base, log, judo, public` (v tomto pořadí). Při psaní SQL vždy uvádět schéma explicitně: `judo.tournament`.

---

*Vygenerováno ze zdrojového kódu: 2026-05-31*
