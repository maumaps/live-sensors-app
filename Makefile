SHELL := /bin/bash

.PHONY: all
all: precommit ## Run the default local verification suite

.PHONY: deps
deps: ## Install Flutter dependencies
	flutter pub get

.PHONY: format
format: ## Rewrite Dart files with the canonical formatter
	dart format .

.PHONY: format-check
format-check: ## Verify Dart formatting without modifying files
	dart format --output=none --set-exit-if-changed .

.PHONY: analyze
analyze: deps ## Run the Dart analyzer and configured lints
	flutter analyze

.PHONY: test
test: deps ## Run Flutter tests
	flutter test

.PHONY: lint
lint: format-check analyze ## Run all non-test lint checks

.PHONY: build-apk
build-apk: deps ## Build the Android release APK
	./scripts/build.sh

.PHONY: precommit
precommit: lint test ## Run checks expected before committing

.PHONY: verify
verify: precommit build-apk ## Run checks plus Android release build
