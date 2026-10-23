#!/usr/bin/env python3
"""Build an installable standalone Plasma 6 widget, with QML/JavaScript monitor control."""
import argparse
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def build(output):
    source = ROOT / 'plasma/com.obezuk.g95nc'
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                archive.write(path, path.relative_to(source))
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/g95nc-control.plasmoid')
    args = parser.parse_args()
    print(build(args.output))
