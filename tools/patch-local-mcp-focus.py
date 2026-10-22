"""Apply a version-checked local MCP focus fix; retain an exact rollback copy."""
from pathlib import Path
import difflib
import hashlib
import json
import sys

source, destination = map(Path, sys.argv[1:3])
raw = source.read_bytes()
expected = '8365fea3d3ccb0abfdce035d346323db7a399b6dcd3dbdd6fdc2d9129f410eab'
if hashlib.sha256(raw).hexdigest() != expected:
    raise SystemExit('Unexpected source SHA256; refusing patch')
old = raw.decode('utf-8').replace('\r\n', '\n')
needle = '''            me = kernel.GetCurrentThreadId()
            other = user.GetWindowThreadProcessId(user.GetForegroundWindow(), None)
            user.AttachThreadInput(me, other, True)
            user.BringWindowToTop(hwnd)
            user.SetForegroundWindow(hwnd)
            user.AttachThreadInput(me, other, False)
'''
replacement = '''            # Match win_input: share both foreground and target input queues.
            kernel.GetCurrentThreadId.restype = W.DWORD
            user.AttachThreadInput.argtypes = [W.DWORD, W.DWORD, W.BOOL]
            user.AttachThreadInput.restype = W.BOOL
            me = kernel.GetCurrentThreadId()
            foreground = user.GetWindowThreadProcessId(user.GetForegroundWindow(), None)
            target = user.GetWindowThreadProcessId(hwnd, None)
            attached = []
            try:
                for thread in set((foreground, target)) - {0, me}:
                    if user.AttachThreadInput(me, thread, True):
                        attached.append(thread)
                user.BringWindowToTop(hwnd)
                user.SetForegroundWindow(hwnd)
            finally:
                for thread in reversed(attached):
                    user.AttachThreadInput(me, thread, False)
'''
if old.count(needle) != 1:
    raise SystemExit('Unexpected tool version; refusing patch')
new = old.replace(needle, replacement)
compile(new, str(source), 'exec')
destination.mkdir(parents=True, exist_ok=True)
backup = destination / 'playtest_runner.original.py'
with backup.open('xb') as stream:
    stream.write(raw)
(destination / 'playtest-focus.patch').write_text(''.join(difflib.unified_diff(
    old.splitlines(True), new.splitlines(True), fromfile='a/src/playtest_runner.py',
    tofile='b/src/playtest_runner.py')), encoding='utf-8')
source.write_text(new, encoding='utf-8', newline='\n')
(destination / 'focus-version.json').write_text(json.dumps({
    'beforeSha256': hashlib.sha256(raw).hexdigest(),
    'afterSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'source': str(source), 'backup': str(backup),
}, indent=2) + '\n', encoding='utf-8')
print('Minimal local focus patch applied; exact rollback copy preserved')
