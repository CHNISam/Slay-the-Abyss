"""The local tool patch must fail closed for other versions before changing files."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class FocusPatchTests(unittest.TestCase):
    def test_unknown_source_does_not_mutate_or_make_backup(self):
        script = Path(__file__).resolve().parents[1] / 'tools/patch-local-mcp-focus.py'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'runner.py'
            original = b'raise RuntimeError("wrong tool version")\n'
            source.write_bytes(original)
            result = subprocess.run([sys.executable, str(script), str(source), str(root / 'evidence')],
                                    capture_output=True, text=True, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Unexpected source SHA256', result.stderr)
            self.assertEqual(source.read_bytes(), original)
            self.assertFalse((root / 'evidence').exists())
