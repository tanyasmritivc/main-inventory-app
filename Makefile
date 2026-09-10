BACKEND_PYTHON ?= python3

.PHONY: test test-backend test-frontend test-mobile test-coverage

test: test-backend test-frontend test-mobile

test-backend:
	$(BACKEND_PYTHON) -m pytest

test-frontend:
	npm --prefix frontend test -- --runInBand

test-mobile:
	cd mobile && flutter test

test-coverage:
	$(BACKEND_PYTHON) -m pytest --cov=backend/app --cov-report=term-missing --cov-report=xml:backend/coverage.xml
	npm --prefix frontend run test:ci
	cd mobile && flutter test --coverage
