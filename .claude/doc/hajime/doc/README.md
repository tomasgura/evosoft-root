# Dokumentace – Hajime

Adresář obsahuje kompletní dokumentaci systému Hajime (Judo Tournament Management System).

## Soubory

| Soubor | Obsah |
|--------|-------|
| [uzivatelska-dokumentace.md](uzivatelska-dokumentace.md) | Uživatelská dokumentace (Markdown) |
| [uzivatelska-dokumentace.html](uzivatelska-dokumentace.html) | Uživatelská dokumentace (HTML) |
| [programatorska-dokumentace.md](programatorska-dokumentace.md) | Programátorská dokumentace (Markdown) |
| [programatorska-dokumentace.html](programatorska-dokumentace.html) | Programátorská dokumentace (HTML) |
| [datove-schema.md](datove-schema.md) | Datové schéma – tabulky, sloupce, FK (Markdown) |
| [datove-schema.html](datove-schema.html) | Datové schéma s ER diagramem (HTML) |
| [architektura.html](architektura.html) | architektura.md → HTML |
| [zal-architektura.html](zal-architektura.html) | zal-architektura.md → HTML |
| [readme.html](readme.html) | README.md → HTML |

## Uživatelská dokumentace

- K čemu systém slouží
- Typy uživatelů a přihlášení (Admin, Scale, Scoreboard, Infopanel)
- Workflow od začátku do konce turnaje
- Popis všech modulů a tlačítek
- Validace a omezení
- Možné chyby a jejich řešení

## Programátorská dokumentace

- Architektura a technologický stack (PHP 8, Nette 3.1, Nextras ORM 4, PostgreSQL 15)
- Moduly a entry pointy, routing
- Business vrstva (DataControllers, LogicControllers, Services, Algoritmy)
- Data vrstva – ORM (Entity, Repository, Mapper)
- Datový model a ER diagram
- REST API (Apitte, 16 controllerů, OpenAPI)
- Integrace (Flexii, RabbitMQ, EDA, SMTP, PDF)
- Dependency Injection a konfigurace
- Autentizace (3 mechanismy, 5 typů uživatelů)
- Migrace databáze (Hyperdrive/Liquibase)
- CLI příkazy
- Onboarding, kódové standardy, riziková místa

*Vygenerováno: 2026-05-31*