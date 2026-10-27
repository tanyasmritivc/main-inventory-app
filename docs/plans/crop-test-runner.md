# Clean CI compatibility

The clean Python CI job failed collection because test_capture_crops.py used
pytest.mark.asyncio, but requirements-dev.txt does not install pytest-asyncio.
Local testing had that undeclared plugin installed and hid the problem.

Use the existing AnyIO pytest plugin with a file-scoped asyncio backend fixture.
No new dependency, production code, schema or assertion change is required.
Running the full suite with pytest-asyncio explicitly disabled passes 817 tests
and 10 subtests. Clean CI must also pass before completion.

The newer Flutter 3.47.7 CI SDK also reports an existing Memory settings ListTile
whose ink is painted behind the glass card. Give that tile a transparent Material
owner, preserving its layout, copy and behavior. All 32 profile tests and analysis
pass locally; the clean newer-SDK job must also pass. Dashboard code is untouched.

Separate compatibility lane fix/ci-asyncio-dependency-20261017, based on 75db5c5.
It is the parent of the mobile directory lane. The directory release includes the
same settings wrapper. Rollback restores the clean-CI collection/ink failures;
no database or backend deployment is involved.
