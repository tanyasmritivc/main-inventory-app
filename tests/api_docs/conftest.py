"""Reuse the application's hermetic test environment; never use live secrets."""
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
runpy.run_path(str(ROOT / "backend/tests/conftest.py"))
sys.path.insert(0, str(ROOT / "scripts"))
