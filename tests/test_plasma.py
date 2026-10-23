import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from contextlib import contextmanager
import fcntl
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
@contextmanager
def monitor_lock(directory, serial):
    """Independent flock client to verify the shell transport's lock contract."""
    path = Path(directory) / f'g95nc-{os.getuid()}' / (hashlib.sha256(serial.encode()).hexdigest() + '.lock')
    with path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


class PlasmaTests(unittest.TestCase):
    def test_package_has_no_python_or_service_dependency(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / 'widget.plasmoid'
            subprocess.run([sys.executable, str(ROOT / 'deploy/build-plasma.py'), '--output', str(package)], check=True, capture_output=True)
            with zipfile.ZipFile(package) as archive:
                self.assertIn('contents/ui/Monitor.js', archive.namelist())
                self.assertIn('contents/code/transport.sh', archive.namelist())
                self.assertFalse(any(name.endswith(('.py', '.pyc', '.so')) for name in archive.namelist()))

    def test_transaction_lock_and_transport(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {**os.environ, 'TMPDIR': directory}
            fake = root / 'fake-ddc'
            fake.write_text((ROOT / 'tests/qml/fake_ddc.py').read_text())
            fake.chmod(0o700)
            script = root / 'transport.sh'
            script.write_text((ROOT / 'plasma/com.obezuk.g95nc/contents/code/transport.sh').read_text().replace('/usr/bin/ddcutil', str(fake)))
            def run(*args):
                return subprocess.run(['bash', str(script), *args], env=env, capture_output=True, text=True, timeout=10)
            session = run('prepare').stdout.strip()
            serial = "test' $(false); serial"
            server = subprocess.Popen(['bash', str(script), 'serve', session, serial], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                self.assertEqual(run('ready', session).returncode, 0)
                with self.assertRaises(BlockingIOError):
                    with monitor_lock(directory, serial): pass
                read = run('exchange', session, 'read')
                self.assertEqual(read.returncode, 0, read.stderr)
                self.assertIn('x39 xd0', read.stdout)
                write = run('exchange', session, 'write', 'E2', '0x0003')
                self.assertEqual(write.returncode, 0, write.stderr)
                self.assertIn('x39 xd1', run('exchange', session, 'read').stdout)
                # Lock is still held between requests and until the whole session closes.
                with self.assertRaises(BlockingIOError):
                    with monitor_lock(directory, serial): pass
                self.assertEqual(run('close', session).returncode, 0)
                server.communicate(timeout=5)
                with monitor_lock(directory, serial): pass
                self.assertFalse(Path(session).exists())
                # An independent flock client also blocks the shell transport.
                session2 = run('prepare').stdout.strip()
                with monitor_lock(directory, serial):
                    rejected = run('serve', session2, serial)
                    self.assertEqual(rejected.returncode, 75)
                run('close', session2)
            finally:
                if server.poll() is None:
                    server.terminate()
                server.communicate(timeout=5)
