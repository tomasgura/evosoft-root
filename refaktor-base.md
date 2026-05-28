# Refaktoring knihovny `base`

## Poznatky

### PHPStan: `Base\Presenters\BasePresenter` dědí z neznámé třídy `App\Presenters\BasePresenter`

- Soubor: `src/Presenters/BasePresenter.php:17`
- Třída `\App\Presenters\BasePresenter` není součástí knihovny `base` ani jejích závislostí — existuje pouze v konkrétních aplikacích (např. `flexii`).
- Jde o **obrácenou závislost**: knihovna závisí na aplikaci, což je architektonický problém.
- Třída je označena `@deprecated use traits instead` — záměr je závislost odstranit a nahradit traity.
- PHPStan to označuje jako `non-ignorable` — nelze potlačit přes baseline.

## Kde se `\App\Presenters\BasePresenter` vyskytuje

### Projekty používající knihovnu `base` (`evosoftcz/base`)

| Projekt | Verze base |
|---------|------------|
| `flexii` | 6.3.4 |
| `dwh` | ^6.3.1 |

`judo-*` projekty knihovnu `base` **nepoužívají**.

### `App\Presenters\BasePresenter` ve `flexii`

- Definice: `flexii/app/Presenters/BasePresenter.php`
- Dědí z: `Nette\Application\UI\Presenter`
- Používá traity: `ModalManagementTrait`, `SystemMessageElementFactoryTrait`, `InitBasePrerequisites`, `Backlink`, `Secured`, `MenuFactoryTrait`
- Obsahuje aplikačně specifickou logiku: `ScriptCollector`, `LogService`, `AgendaFactory`, `ThemeFactory`, `ConfigService`, verze DB atd.
- Je to velmi "tučná" třída — základ celé prezentační vrstvy `flexii`

### Třídy dědící z `\App\Presenters\BasePresenter` ve `flexii`

- `Base\Presenters\BasePresenter` (knihovna `base`) — **problematická závislost**
- `flexii/app/AdminModule/Presenters/BasePresenter.php`
- `flexii/libs/Gdpr/src/Presenters/BasePresenter.php`
- `flexii/libs/Agenda/src/Presenters/BasePresenter.php`
- `flexii/vendor/evosoftcz/reporting/src/Presenters/BasePresenter.php`
- `flexii/vendor/evosoftcz/configuration/src/Presenters/BasePresenter.php`

### Závěr

Vzor `knihovna extends \App\Presenters\BasePresenter` je v `flexii` rozšířený — týká se nejen `base`, ale i dalších `evosoftcz/*` knihoven (`reporting`, `configuration`). Jde o systémový návrhový problém, ne izolovaný případ.

---

## `dwh` — správný přístup (vzor k následování)

`dwh` používá `evosoftcz/base`, ale **nepoužívá** `Base\Presenters\BasePresenter`.

Místo toho si jeho `App\Presenters\BasePresenter` (`dwh/app/Presenters/BasePresenter.php`) dědí přímo z `Nette\Application\UI\Presenter` a potřebné věci z `base` přebírá **traity**:

```php
use Base\Components\Element\SystemMessage\SystemMessageElementFactoryTrait;
use Base\Traits\InitBasePrerequisites;
use Base\Traits\Backlink;
```

Toto je správný způsob použití knihovny — aplikace závisí na knihovně, ne naopak.

---

## Návrh řešení

### Analýza problematické třídy

`Base\Presenters\BasePresenter` (`base/src/Presenters/BasePresenter.php`):
- Dědí z `\App\Presenters\BasePresenter` (závislost na aplikaci)
- Přidává pouze `ModalManagementTrait`
- Je označena `@deprecated use traits instead`
- **Nikdo v aplikačním kódu ji neextenduje** — ani `flexii`, ani `dwh`

Ostatní presentery v `base` (`SecuredPresenter`, `AdminPresenter`, `SignPresenter`, ...) dědí přímo z `Nette\Application\UI\Presenter` — ty jsou v pořádku.

### Řešení: smazat `Base\Presenters\BasePresenter`

Soubor `base/src/Presenters/BasePresenter.php` jednoduše **smazat**.

Důvody:
- Třída je označena `@deprecated` — smazání je deklarovaným záměrem
- Nikdo ji neextenduje — žádný breaking change pro aplikace
- `ModalManagementTrait`, který přidávala, si každá aplikace přidá sama (flexii i dwh to tak již mají)
- Po smazání PHPStan chyba zmizí a závislost knihovny na aplikaci je odstraněna

### Co s `reporting` a `configuration`?

Stejný problém mají i `evosoftcz/reporting` a `evosoftcz/configuration` — jejich `BasePresenter` také dědí z `\App\Presenters\BasePresenter`. Ty jsou ale mimo scope tohoto úkolu; řeší se analogicky.

### Co NENÍ potřeba měnit

`flexii/libs/Agenda`, `flexii/libs/Gdpr`, `flexii/app/AdminModule` mají také `BasePresenter extends \App\Presenters\BasePresenter` — to je **v pořádku**, protože jsou součástí aplikace samotné, ne samostatného balíčku.

---

## `judo-*` projekty — nezávislé na `base`

Žádný z projektů `judo-*` (`judo-external-hajime`, `judo-gate`, `judo-referee-portal`, `judo-vysledkovy-portal`) knihovnu `evosoftcz/base` **nepoužívá**. Problém se jich netýká.

`judo-external-hajime` má vlastní `App\Presentation\Presenters\BasePresenter` dědící z `Nette\Application\UI\Presenter` — plně samostatný, bez závislosti na `base`.
