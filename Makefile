BACKEND_PYTHON ?= python3

.PHONY: test test-backend test-frontend test-mobile test-integrations test-coverage docs-api

test: test-backend test-frontend test-mobile test-integrations

test-backend:
	$(BACKEND_PYTHON) -m pytest

test-frontend:
	npm --prefix frontend test -- --runInBand

test-mobile:
	cd mobile && flutter test

docs-api:
	$(BACKEND_PYTHON) scripts/api_reference.py
	npm --prefix integrations/findez-mcp run generate

test-integrations:
	npm --prefix integrations/findez-mcp test
	npm --prefix integrations/findez-mcp run check:bundle
	npm --prefix integrations/findez-mcp run test:bundle

test-coverage:
	$(BACKEND_PYTHON) -m pytest --cov=backend/app --cov-report=term-missing --cov-report=xml:backend/coverage.xml
	npm --prefix frontend run test:ci
	cd mobile && flutter test --coverage
	$(MAKE) test-integrations
