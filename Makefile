.DEFAULT_GOAL := run
EXTENDDB_BACKEND := "sqlite"
EXTENDDB_BRANCH := "v0.1.6"
EXTENDDB_CONFIG := "deps/extenddb.toml"
EXTENDDB_ADMIN_PASSWORD := "radu"

.PHONY: run
run: deps
	@HOME="$(CURDIR)/deps" deps/extenddb/target/release/extenddb serve --config $(EXTENDDB_CONFIG) --write-pid-file

.PHONY: deps
deps:
	@if [ ! -d "deps" ]; then \
		mkdir -p deps; \
	fi
	@if [ ! -d "deps/extenddb" ]; then \
		git clone git@github.com:ExtendDB/extenddb.git deps/extenddb --branch $(EXTENDDB_BRANCH); \
	fi
	@if [ ! -f "deps/extenddb/target/release/extenddb" ]; then \
		cd deps/extenddb; \
		cargo build --release --no-default-features --features $(EXTENDDB_BACKEND); \
	fi
	@if [ ! -d "deps/storage" ]; then \
		mkdir -p deps/storage; \
	fi
	@if [ ! -f "deps/storage/extenddb.sqlite" ]; then \
		HOME="$(CURDIR)/deps" EXTENDDB_ADMIN_PASSWORD=$(EXTENDDB_ADMIN_PASSWORD) deps/extenddb/target/release/extenddb init --config $(EXTENDDB_CONFIG) --overwrite; \
		if [ -f extenddb.sqlite ]; then mv extenddb.sqlite deps/storage/; fi; \
		if [ -f extenddb.sqlite-shm ]; then mv extenddb.sqlite-shm deps/storage/; fi; \
		if [ -f extenddb.sqlite-wal ]; then mv extenddb.sqlite-wal deps/storage/; fi; \
		sed -i '' 's|path = "extenddb.sqlite"|path = "deps/storage/extenddb.sqlite"|' $(EXTENDDB_CONFIG); \
		HOME="$(CURDIR)/deps" deps/extenddb/target/release/extenddb serve --config $(EXTENDDB_CONFIG) --write-pid-file; \
		account_id=$$(HOME="$(CURDIR)/deps" deps/extenddb/target/release/extenddb manage --config $(EXTENDDB_CONFIG) --user admin --password "$(EXTENDDB_ADMIN_PASSWORD)" list-accounts | python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["account_id"])'); \
		HOME="$(CURDIR)/deps" deps/extenddb/target/release/extenddb manage --config $(EXTENDDB_CONFIG) --user admin --password "$(EXTENDDB_ADMIN_PASSWORD)" \
			create-user --account-id $$account_id \
			--user-name admin --user-password "$(EXTENDDB_ADMIN_PASSWORD)"; \
		HOME="$(CURDIR)/deps" deps/extenddb/target/release/extenddb manage --config $(EXTENDDB_CONFIG) --user admin --password "$(EXTENDDB_ADMIN_PASSWORD)" \
			put-user-policy --account-id $$account_id \
			--user-name admin --policy-name FullAccess \
			--policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"dynamodb:*","Resource":"*"}]}'; \
		HOME="$(CURDIR)/deps" deps/extenddb/target/release/extenddb manage --config $(EXTENDDB_CONFIG) --user $$account_id/admin --password "$(EXTENDDB_ADMIN_PASSWORD)" \
			create-access-key | sed -n '/^{/,$$p' > deps/access-keys.json; \
		kill -TERM $$(cat deps/.extenddb/run/extenddb-*.pid); \
	fi

.PHONY: healthcheck
healthcheck:
	@curl --cacert deps/.extenddb/tls/cert.pem https://127.0.0.1:18443/health

.PHONY: env
env:
	@access_key_id=$$(jq -r '.access_key_id' "$(CURDIR)/deps/access-keys.json"); \
	secret_access_key=$$(jq -r '.secret_access_key' "$(CURDIR)/deps/access-keys.json"); \
	echo "export AWS_CA_BUNDLE=$(CURDIR)/deps/.extenddb/tls/cert.pem"; \
	echo "export AWS_ENDPOINT_URL_DYNAMODB=https://127.0.0.1:18443"; \
	echo "export AWS_ACCESS_KEY_ID=$$access_key_id"; \
	echo "export AWS_SECRET_ACCESS_KEY=$$secret_access_key"; \
	echo "export AWS_DEFAULT_REGION=us-east-1"; \
	echo "export export AWS_ENDPOINT_URL=https://127.0.0.1:18443"

.PHONY: stop
stop:
	@kill -TERM $$(cat deps/.extenddb/run/extenddb-*.pid) 2>/dev/null

.PHONY: clean
clean:
	@rm -rfv deps
