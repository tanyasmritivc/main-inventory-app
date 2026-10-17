# Crop test runner compatibility

The clean Python CI job failed collection because test_capture_crops.py used
pytest.mark.asyncio, but requirements-dev.txt does not install pytest-asyncio.
Local testing had that undeclared plugin installed and hid the problem.

Use the existing AnyIO pytest plugin with a file-scoped asyncio backend fixture.
No new dependency, production code, schema or assertion change is required.
Running the full suite with pytest-asyncio explicitly disabled passes 817 tests
and 10 subtests. Clean CI must also pass before completion.

Separate lane fix/ci-asyncio-dependency-20261017, based on 75db5c5. This test-only
parent change is included by the mobile directory lane without changing its
production runtime. Rollback is the scoped test-file revert, but restores the
clean-CI collection failure.
