from pathlib import Path

import pytest
from kickstart.engineering.config import KickstartSettings
from kickstart.testing.settings import isolate_settings

PROJECT_ROOT = Path(__file__).resolve().parent.parent


@pytest.fixture(autouse=True)
def _isolate_settings(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Sever every test from the developer's local ``.env`` so settings come only from the test."""
    isolate_settings(
        monkeypatch,
        settings_class=KickstartSettings,
        working_dir=tmp_path,
        ROOT=str(PROJECT_ROOT),
    )
