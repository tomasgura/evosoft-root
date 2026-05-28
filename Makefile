.PHONY: help

help: ## Show this help
	@echo Usage: make [target]
	@echo
	@echo Targets:
	@grep -E '^[a-zA-Z_0-9-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

vpn-up: ## Připojení k VPN
	wg-quick up evosoft

vpn-down: ## Odpojení od VPN ##
	wg-quick down evosoft





docker-login: ## Přihlášení do Docker registru
	@echo "Evosoft42" | docker login registry.evosoft.cz -u "evosoft" --password-stdin

dev-init: ## Vytvoření adresářů pro data (nutné po smazání)
	mkdir -p dev-docker/data/postgres_{11,13,14,15,16,17}
	mkdir -p dev-docker/data/postgres_18/../postgres_18  # postgres 18 mount je na /var/lib/postgresql
	sudo chown -R 999:999 dev-docker/data/
	sudo chown -R 999:999 dev-docker/data/postgres_18

dev-start: docker-login dev-init## Spuštění dev prostředí (Docker)
	#docker network create evs_dev_net
	cd dev-docker && docker compose up -d
	#docker swarm init > swarm-info.txt

dev-down: ## Vypnutí dev prostředí
	cd dev-docker && docker compose kill && docker compose down

dev-restart: dev-down dev-start ## Restart dev prostředí

flexii-fullstart: dev-start flexii-start flexii-start-db flexii-start-konzumeri ## Spuštění flexi prostředí s databází a konzumeri





# Flexii
flexii-fix:
	cd flexii && docker compose exec app git config --global --add safe.directory /var/www/evo

flexii-start: ## Spuštění flexi prostředí
	cd flexii && docker compose up -d
	$(MAKE) flexii-fix

flexii-start-db: ## Spuštění databáze pro flexi
	cd flexii && /usr/bin/bash ./vendor/evosoftcz/hyperdrive/resources/commands/start.sh -c flexii_app_1 postgre

flexii-start-konzumeri: ## Spuštění databáze pro flexi
	cd flexii && /usr/bin/bash ./resources/scripts/rabbitMq/action.sh -c flexii_app_1 10000

flexii-down: ## Vypnutí flexi prostředí
	cd flexii && docker compose kill && docker compose down

flexii-dump-data:## dump flexi
	# docker exec dev-docker-postgresql_16-1 pg_dump -U app flexii_c9 > dump.sql
	docker exec dev-docker-postgresql_16-1 sh -c 'pg_dump -U app flexii_c9' > flexii_dump_$(shell date +%Y-%m-%d_%H-%M-%S).sql

flexii-restore-dump-data: ## restore data z dumpu
	#sleep 1
	cd flexii && sudo chmod +x vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh
	cd flexii && pwd && bash -c './vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh -c flexii_app_1 postgre dropPostgre'
	#cd flexii && vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh postgre dropPostgre
	docker exec -i dev-docker-postgresql_16-1 psql -U app flexii_c9 < flexii_dump.sql
	#docker exec -i dev-docker-postgresql_16-1 psql -U app flexii_c9 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" && docker exec -i dev-docker-postgresql_16-1 psql -U app flexii_c9 < dump.sql



flexii-restart: flexii-down flexii-start  ## Restart flexi a dev prostředí

flexii-restart-with-start-data: flexii-restart flexii-start-db ## restart s defaultnimi daty

flexii-restart-with-dump-data: flexii-restart flexii-restore-dump-data ## restart s nahranim zazalohovanych datg



# Hajime
hajime-start: dev-start ## Spuštění hajime prostředí
	cd judo-external-hajime && docker compose up -d

hajime-down: ## Vypnutí flexi prostředí
	cd judo-external-hajime && docker compose kill && docker compose down

hajime-install: hajime-start
	#composer install
	#npm install

hajime-start-db: hajime-start## Spuštění databáze pro Hajime
	#cd judo-external-hajime && sudo chmod +x vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh && /usr/bin/bash ./vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh
	#cd judo-external-hajime vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh -c judo_app_1 postgre dropPostgre
	cd judo-external-hajime && /usr/bin/bash ./vendor/evosoftcz/hyperdrive/resources/commands/start.sh -c judo_app_1 postgre

hajime-dump-data:## dump hajime
	docker exec dev-docker-postgresql_15-1 sh -c 'pg_dump -U app judo' > hajime_dump_$(shell date +%Y-%m-%d_%H-%M-%S).sql










dwh-dump-data:## dump dwh
	docker exec dev-docker-postgresql_17-1 sh -c 'pg_dump -U app dwh' > dwh_dump_$(shell date +%Y-%m-%d_%H-%M-%S).sql

dwh-start: dev-start ## Spuštění dwh prostředí
	cd dwh && docker compose up -d

dwh-start-db: ## Spuštění databáze pro Hajime
	cd dwh && sudo chmod +x vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh # && /usr/bin/bash ./vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh
	cd dwh vendor/evosoftcz/hyperdrive/resources/commands/procedure.sh -c dwh_app_1 postgre dropPostgre
	cd dwh && /usr/bin/bash ./vendor/evosoftcz/hyperdrive/resources/commands/start.sh -c dwh_app_1 postgre
	cd dwh && sudo chmod +x ./resources/dev/scripts/startup.sh
	cd dwh && /usr/bin/bash ./resources/dev/scripts/startup.sh -c dwh_app_1 postgre


dwh-rabitmq-consumeri: ## Spuštění rabitmq consumerů pro dwh
	cd dwh && sudo chmod +x ./resources/scripts/rabbitmq/__startAllConsumer.sh
	cd dwh && /usr/bin/bash ./resources/scripts/rabbitmq/__startAllConsumer.sh -c dwh_app_1 500



# vysledkovy portal

vys-port-start: # start vysledkoveho portalu
	cd judo-vysledkovy-portal && docker compose up -d
	cd judo-vysledkovy-portal && docker compose exec app composer install
	cd judo-vysledkovy-portal && docker compose exec app npm i
	cd judo-vysledkovy-portal && docker compose exec app bin/console importmap:install
	cd judo-vysledkovy-portal && docker compose exec app bin/console asset-map:compile


vys-port-down: ## Vypnutí flexi prostředí
	cd judo-vysledkovy-portal && docker compose kill && docker compose down

vys-port-restart: vys-port-down vys-port-start  ## Restart flexi a dev prostředí



all-start: dev-start flexii-start dwh-start hajime-start vys-port-start

