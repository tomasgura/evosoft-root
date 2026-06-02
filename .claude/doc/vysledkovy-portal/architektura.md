# Architektura — Judo Výsledkový portál

## Přehled

| Položka | Hodnota |
|---|---|
| Framework | Symfony 7.1 |
| PHP | 8.3+ |
| Databáze | PostgreSQL (přes vlastní ORM EDA) |
| Šablony | Twig 3.10 |
| Frontend | Bootstrap 5.3.3 + Stimulus + Turbo |
| Cachování | APCu / file-based (AppCacheService) |

## Architekturní vzor

```
REQUEST
  ↓
[Routing] — attribute-based (PHP atributy na metodách controllerů)
  ↓
[Controller] — HTTP handlery (5 hlavních + ErrorController)
  ↓
[Service Layer] — business logika (8 služeb)
  ↓
[Repository Layer] — přístup k datům
  ├── DWH (PostgreSQL přes EDA)
  ├── Flexii API (FlexiiRepository)
  └── Hajime API (HajimeEndpoint)
  ↓
[Cache Layer] — AppCacheService (APCu nebo file-based)
  ↓
[Entity / DTO] — datové modely (53 souborů)
  ↓
[Response]
  ├── Twig rendering (30+ komponent)
  ├── JsonResponse (API endpointy)
  └── BinaryFileResponse (soubory ke stažení)
```

## Framework & technologie

### Symfony 7.1
- Attribute-based routing (žádné YAML/XML routes pro controllery)
- Dependency Injection přes autowire + autoconfigure
- Symfony UX: TwigComponent, Stimulus Bridge, Turbo

### ORM: EDA (Evosoft Data Access)
- Proprietární ORM/query builder od Evosoft
- PostgreSQL driver
- Flow builder API pro SQL dotazy
- Konfigurace: `config/packages/eda.yaml`

### Caching
- Wrapper: `AppCacheService` → `Cache\CacheService`
- Backendy: APCu (web) / file-based (CLI)
- Namespace: `CacheRecord::NAMESPACE`
- Expirační časy konfigurovatelné přes `.env`

### Frontend stack
- **Bootstrap 5.3.3** — CSS framework
- **Stimulus** — reaktivní JS komponenty
- **Turbo 8.0** — SPA-like navigace bez full page reload
- **Tom Select 2.3** — rozšířené selectboxy
- **Tempus Dominus 6.9.11** — datetime picker
- **AssetMapper** — správa frontend závislostí (bez Webpacku)

## Adresářová struktura

```
judo-vysledkovy-portal/
├── src/
│   ├── Attribute/          # Vlastní PHP atributy (DatagridColumn)
│   ├── Command/            # CLI příkazy (cron joby)
│   ├── Controller/         # HTTP controllery
│   ├── Entity/             # Entity a DTO
│   │   ├── Club/
│   │   ├── Member/
│   │   ├── Tournament/
│   │   ├── DTO/
│   │   └── Hajime/
│   ├── Enum/               # Enumerace
│   ├── Exceptions/         # Vlastní výjimky
│   ├── Helpers/            # Pomocné třídy
│   ├── Repository/         # Data access layer
│   │   ├── External/       # Integrace s externími API
│   │   └── Tournament/
│   ├── Service/            # Business logika
│   │   └── Cache/
│   ├── Twig/               # Twig komponenty a filtry
│   │   ├── Components/
│   │   └── Filters/
│   └── Kernel.php
├── config/
│   ├── packages/           # Konfigurace balíčků
│   ├── routes/
│   ├── bundles.php
│   ├── routes.yaml
│   └── services.yaml
├── templates/              # Twig šablony
├── assets/                 # Frontend zdroje (SCSS, JS)
├── public/                 # Web root (index.php, compiled assets)
├── translations/           # i18n (YAML, čeština)
├── var/                    # Cache, logy, tmp
└── resources/
    ├── docker/
    └── scripts/
```

## Dependency Injection

- Autowire: **enabled** — services se injektují automaticky podle typů
- Autoconfigure: **enabled** — tagy se přiřazují automaticky
- Services jsou `readonly` tam kde je to možné
- Rozhraní `ITournamentDetailRepository` se přepíná mezi implementacemi (DWH vs Hajime) dle prostředí/konfigurace

## Počty komponent

| Typ | Počet |
|---|---|
| PHP souborů v src/ | ~128 |
| Entity/DTO | 53 |
| Services | 8 + AppCacheService |
| Controllers | 5 + ErrorController |
| Repositories | 10+ (vč. externích) |
| Twig komponent | 30+ |
| CLI Commands | 2 |
| Custom Exceptions | 6 |
| Enums | 2 |
