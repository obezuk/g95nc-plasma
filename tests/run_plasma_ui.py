#!/usr/bin/env python3
"""Run offline QML integration tests using the installed Qt 6 Quick Test library.

Requires Plasma 6 QML modules and libQt6QuickTest.so.6. No monitor access.
"""
import ctypes
import os
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
    os.environ.setdefault('QT_QUICK_BACKEND', 'software')
    with tempfile.TemporaryDirectory(prefix='g95nc-qml-') as directory:
        root = Path(directory)
        widget = root / 'widget'
        shutil.copytree(ROOT / 'plasma/com.obezuk.g95nc', widget, ignore=shutil.ignore_patterns('__pycache__'))
        fake = root / 'fake-ddc'
        shutil.copy2(ROOT / 'tests/qml/fake_ddc.py', fake)
        fake.chmod(0o700)
        transport = widget / 'contents/code/transport.sh'
        transport.write_text(transport.read_text().replace('/usr/bin/ddcutil', str(fake)))
        tests = root / 'tests'
        tests.mkdir()
        shutil.copy2(ROOT / 'tests/qml/tst_widget.qml', tests)
        editor = widget / 'contents/ui/Editor.qml'
        editor.write_text(editor.read_text().replace('Item {', 'Item {\n    function i18n(text, arg) { return arg === undefined ? text : text.replace("%1", String(arg)); }', 1))
        # The distro includes the Qt Quick Test library even without the runner binary.
        library = ctypes.CDLL('libQt6QuickTest.so.6')
        run = getattr(library, '_Z15quick_test_mainiPPcPKcS2_')
        run.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_char_p), ctypes.c_char_p, ctypes.c_char_p]
        args = [b'g95nc-widget-test', b'-input', os.fsencode(tests)]
        argv = (ctypes.c_char_p * (len(args) + 1))(*args, None)
        result = run(len(args), argv, b'g95nc-widget', None)
        if (root / 'preview.png').exists():
            (ROOT / '.runtime').mkdir(exist_ok=True)
            shutil.copy2(root / 'preview.png', ROOT / '.runtime/plasma-widget.png')
        return result


if __name__ == '__main__':
    sys.exit(main())
