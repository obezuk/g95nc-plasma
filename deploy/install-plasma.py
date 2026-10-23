#!/usr/bin/env python3
"""Build and install/update the standalone Plasma 6 widget for the current user."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

if os.getuid() == 0:
    raise SystemExit('Run as the desktop user, without sudo.')
tool = shutil.which('kpackagetool6')
if not tool:
    raise SystemExit('Plasma 6 and kpackagetool6 are required.')
spec = importlib.util.spec_from_file_location('build_plasma', Path(__file__).with_name('build-plasma.py'))
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
installed = data / 'plasma/plasmoids/com.obezuk.g95nc'
with tempfile.TemporaryDirectory(prefix='g95nc-plasma-') as directory:
    package = builder.build(Path(directory) / 'g95nc-control.plasmoid')
    subprocess.run([tool, '--type', 'Plasma/Applet',
                    '--upgrade' if installed.exists() else '--install', str(package)], check=True)
print('Installed G95NC Control. Add it using panel Edit Mode → Add Widgets.')
print('Set the monitor serial in widget settings (find it with ddcutil detect).')
print('No service, browser, or API token is required.')
