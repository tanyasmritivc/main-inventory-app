"""Build the credential-free Fusion preview download deterministically."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'integrations/findez-fusion'
DESTINATION = ROOT / 'frontend/public/downloads/findez-fusion-workspace.zip'
FILES = ('README.md', 'FindEZ/FindEZ.py', 'FindEZ/FindEZ.manifest', 'FindEZ/exporter.py', 'FindEZ/client.py', 'FindEZ/workspace.py', 'FindEZ/placement.py', 'FindEZ/palette.html', 'FindEZ/palette.css', 'FindEZ/palette.js')


def build():
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(DESTINATION, 'w', compression=ZIP_DEFLATED) as archive:
        for name in FILES:
            info = ZipInfo(name, date_time=(2026, 11, 15, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, (SOURCE / name).read_bytes())
    print('Packaged', DESTINATION.relative_to(ROOT))


if __name__ == '__main__':
    build()
