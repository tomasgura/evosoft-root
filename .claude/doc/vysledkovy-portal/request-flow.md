# Tok requestu — Judo Výsledkový portál

## Obecný tok (HTML stránka)

```
Browser
  → GET /tournaments/uid/ABC123
  → public/index.php (Symfony entry point)
  → Kernel.php (bootstrap)
  → Router (attribute-based, matchuje cestu na TournamentsController::detail)
  → TournamentsController::detail($uid)
      → TournamentService::getTournamentByUID($uid)
          → AppCacheService::get('tournament_uid_ABC123')
              ✓ cache hit → vrátí Tournament entitu
              ✗ cache miss → TournamentsRepository::getTournament($uid)
                              → EDA query na PostgreSQL
                              → mapování výsledku na Tournament entitu
                              → AppCacheService::set(...)
      → TournamentService::getTournamentAgeCategories($uid)
          → (stejný cache pattern)
      → render('tournaments/detail.html.twig', [...])
          → Twig engine
          → Twig komponenty (BasicInfoComponent, AgeCategoryPicker, ...)
  ← HTML response
```

## Tok API requestu (datagrid JSON)

```
Browser (JavaScript datagrid)
  → GET /api/tournament?queryData={page:1,pageSize:25,filters:[...],sort:...}&tournament_states=active
  → TournamentsController::datagridData()
      → deserializace QueryParams z JSON
      → TournamentService::getTournamentsDatagridData(QueryParams, states[])
          → AppCacheService::get('datagrid_tournaments_...')
              ✓ hit → vrátí EntitySetDTO
              ✗ miss → TournamentsRepository::getDatagridData(QueryParams, states)
                         → BaseRepository::getDatagridFlow()
                         → EDA: applyFilters(), applySort(), pagination
                         → SELECT z DWH tabulky s WHERE, ORDER BY, LIMIT
                         → mapování na TournamentRowDTO[]
                         → EntitySetDTO { data: DTO[], itemsCount: N }
  ← JsonResponse { data: [...], itemsCount: N, countText: "Nalezeno 42 výsledků" }
```

## Tok live dat (Hajime API)

```
Browser
  → GET /tournaments/uid/ABC123/matches
  → TournamentsController::matches($uid)
      → TournamentService::getTournamentMatches($uid)
          → ITournamentDetailRepository (implementace: TournamentDetailHajimeRepository)
              → HajimeEndpoint::getMatchesJSON($uid, $subcategoryId)
                  → AppCacheService::get('hajime_api_matches_...') [TTL: krátký, live data]
                      ✗ miss → HTTP GET na HAJIME_URL/api/open/tournament/{uid}/subcategory-matches/{id}
                              → parsování JSON odpovědi
                              → mapování na TournamentMatchDTO[]
  ← HTML s live zápasy (aktualizováno pravidelně přes JS)
```

## Tok CLI commandu (cron job)

```
cron: php bin/console app:get-tournaments
  → GetTournamentsCommand::execute()
      → FlexiiRepository::getTournamentsFromFlexii()
          → HTTP GET na Flexii API
          → parsování odpovědi
      → pro každý turnaj:
          → porovnání dt_upd_attributes s lokálním stavem
          → FlexiiRepository::getTournamentResultFilesFromFlexiiIfUpdated($uid)
              → HTTP GET souboru z Flexii
              → uložení do public/files/tournaments/{uid}/
```

## Tok exportu

```
Browser
  → GET /tournaments/uid/ABC123/export_results?format=pdf&category=...
  → TournamentsController::export_results()
      → TournamentService::getResultsForAgeCategory(...)
      → ExportService::exportResultsToPdf($results)
          → mPDF: generování PDF s výsledky
          → uložení do var/tmp/results_ABC123.pdf
      → BinaryFileResponse (stream souboru do browseru)
  ← PDF file download
```

## Cache strategie

| Data | Cache klíč | TTL |
|---|---|---|
| Detail turnaje | `tournament_uid_{uid}` | CACHE_EXPIRATION_SECONDS |
| Seznam turnajů (datagrid) | `datagrid_tournaments_{hash}` | CACHE_EXPIRATION_SECONDS |
| Detail člena | `member_uid_{uid}` | CACHE_EXPIRATION_SECONDS |
| Hajime live zápasy | `hajime_api_matches_{uid}_{id}` | CACHE_EXPIRATION_SECONDS_LIVE_RESULTS |
| Hajime live shuffle | `hajime_api_shuffle_{uid}_{id}` | CACHE_EXPIRATION_SECONDS_LIVE_RESULTS |
| Vyhledávání | `search_{type}_{query}` | CACHE_EXPIRATION_SECONDS |

Live data (Hajime) mají výrazně kratší TTL než archivní data (DWH).

## Typy HTTP responses

| Typ | Kdy |
|---|---|
| HTML (Twig) | Všechny stránky (GET bez /api) |
| JsonResponse | Všechny `/api/*` endpointy |
| BinaryFileResponse (stream) | Export PDF/XLSX, stažení výsledkového souboru |
| RedirectResponse | `/` → `/tournaments/active` |
