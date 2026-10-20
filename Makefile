PYTHON_VERSION := $(shell cat .python-version)
UV_VERSION := 0.12.24
UV_PATH := export PATH=$$HOME/.local/bin:$$PATH
DOCKER_COMPOSE_CONTAINER_GROUP_NAME := from-make

.PHONY: install-uv
install-uv:
	@if command -v uv > /dev/null 2>&1; then \
		echo "uv already installed, updating to $(UV_VERSION)..."; \
		$(UV_PATH) && uv self update $(UV_VERSION) || \
			echo "warning: uv self update failed, continuing with the installed uv; if it came from a package manager, update it there (e.g. brew upgrade uv) to match $(UV_VERSION)" >&2; \
	else \
		echo "Installing uv $(UV_VERSION)..."; \
		sh scripts/secure-curl.sh https://github.com/astral-sh/uv/releases/download/$(UV_VERSION)/uv-installer.sh e8c19f8dbfaafcbeddc8d17bf9227505d918220eba2aeb543d6922bdc5bb9625 -- sh; \
	fi

.PHONY: install-keyring
install-keyring:
	$(UV_PATH) && uv tool install keyring==25.7.0 --with keyrings.google-artifactregistry-auth==1.1.2

.PHONY: install-python
install-python:
	$(UV_PATH) && uv python install $(PYTHON_VERSION)

.PHONY: install-deps
install-deps:
	$(UV_PATH) && uv sync --all-extras --all-groups

.PHONY: install-prek
install-prek:
	$(UV_PATH) && uv run prek install

.PHONY: setup
setup: install-uv install-keyring install-python install-deps install-prek
	@bash scripts/env.sh init

.PHONY: env
env:
	@bash scripts/env.sh select

.PHONY: env-current
env-current:
	@bash scripts/env.sh current

.PHONY: docker-up
docker-up:
	# we recommend using the '-p' argument to give a name to the containers so you can track that they are for your test
	docker compose -p $(DOCKER_COMPOSE_CONTAINER_GROUP_NAME) up --build -d
	# if your container needs time to be healty, use wait-for-container.sh
	# e.g., bash ./scripts/wait-for-container.sh container-name 10

.PHONY: docker-down
docker-down:
	docker compose -p $(DOCKER_COMPOSE_CONTAINER_GROUP_NAME) down

.PHONY: test
test:
	uv run pytest tests

.PHONY: integration-test
integration-test: docker-up
	uv run pytest tests
	$(MAKE) docker-down

.PHONY: check
check:
	uv run prek run --show-diff-on-failure  --all-files

.PHONY: secure secure-supply-chain
secure: secure-supply-chain

secure-supply-chain:
	uv run il-supply-chain-security auto-pin || { status=$$?; [ "$$status" -eq 1 ] || exit "$$status"; }

.PHONY: coverage
coverage:
	uv run pytest
	uv run genbadge coverage -l -i ./reports/coverage/coverage.xml -o coverage.svg

.PHONY: docs
docs:
	uv run zensical serve

.PHONY: build
build:
	uv build

.PHONY: init
init:
	@bash scripts/init.sh

.PHONY: mlflow
mlflow:
	uv run mlflow ui --port 8080 --backend-store-uri sqlite:///.mlflow/mlruns.db --default-artifact-root file:.mlruns

.PHONY: update-prek
update-prek:
	uv run prek auto-update --cooldown-days 7 --freeze

.PHONY: vendor-package
vendor-package:
ifndef PKG
	$(error PKG is required. Usage: make vendor-package PKG=il-kickstart)
endif
	@bash scripts/vendor-package.sh $(PKG)

.PHONY: mirror
mirror:
	@echo "Bootstrapping repository mirroring..."
	@bash scripts/mirror.sh
