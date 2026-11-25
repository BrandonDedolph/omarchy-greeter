"""lib/patch-lock.py against Omarchy's lock plugin.

Patches every copy of the lock it can find: the installed one
(/usr/share/omarchy/shell/plugins/lock) and any folders listed in
OMARCHY_LOCK_SOURCES (colon-separated; CI passes upstream's master). The
patched QML must parse, or the account would be left with no lock at all.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PATCH = REPO / "lib" / "patch-lock.py"
MARK = "omarchy-greeter:primary-lock"
QMLLINT = "/usr/lib/qt6/bin/qmllint"
UI = [str(REPO / "lock"), str(REPO / "theme")]


def sources():
    found = []
    for path in ["/usr/share/omarchy/shell/plugins/lock"] + os.environ.get("OMARCHY_LOCK_SOURCES", "").split(":"):
        if path and Path(path, "Service.qml").is_file() and Path(path, "LockView.qml").is_file():
            found.append(Path(path))
    return found


class PatchLock(unittest.TestCase):
    def patched(self, source):
        work = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, work)
        shutil.copytree(source, work, dirs_exist_ok=True)
        result = subprocess.run([sys.executable, "-I", str(PATCH), str(work), MARK, *UI], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, f"{source}: {result.stdout}{result.stderr}")
        return work

    def test_patch_applies_and_parses(self):
        found = sources()
        if not found:
            self.skipTest("no Omarchy lock plugin here (set OMARCHY_LOCK_SOURCES)")
        for source in found:
            with self.subTest(source=str(source)):
                work = self.patched(source)
                service = (work / "Service.qml").read_text()
                shim = (work / "LockView.qml").read_text()
                self.assertIn(MARK, service)
                for needed in ("handleSessionEvent", "forgetLogindUnlock", "omarchy-greeter-session-watch",
                               "accounts: root.accounts"):
                    self.assertIn(needed, service)
                # Handlers qmllint does not flag but QML refuses: one of each per object.
                self.assertEqual(service.count("onLockRequestedChanged"), 1)
                # Omarchy's layout is kept as it is, as the fallback.
                self.assertEqual((work / "StockLockView.qml").read_text(), (source / "LockView.qml").read_text())
                # The wrapper loads ours, falls back to Omarchy's, and takes
                # everything Omarchy's layout takes.
                self.assertIn('source: "GreeterLockView.qml"', shim)
                self.assertIn('source = "StockLockView.qml"', shim)
                for line in (source / "LockView.qml").read_text().splitlines():
                    m = re.fullmatch(r"  property [\w.<>]+ (\w+).*", line)
                    if m:
                        self.assertRegex(shim, rf"\n  property [\w.<>]+ {m.group(1)}\b", m.group(1))
                    m = re.fullmatch(r"  signal (\w+).*", line)
                    if m:
                        self.assertIn(f"  signal {m.group(1)}", shim)
                # Everything the logic hands the layout (LockView { ... } blocks) is declared.
                for block in re.findall(r"\n( +)LockView \{\n(.*?)\n\1\}", service, re.S):
                    for name in re.findall(r"^\s+(?:on([A-Z]\w*)|(\w+))\s*:", block[1], re.M):
                        prop = name[1] or (name[0][0].lower() + name[0][1:])
                        if prop in ("id", "anchors", "opacity"):
                            continue
                        self.assertRegex(shim, rf"(property [\w.<>]+|signal) {prop}\b", f"LockView takes {prop}")
                for name in ("GreeterLockView.qml", "AccountForm.qml", "PasswordBox.qml", "AccountList.qml"):
                    self.assertTrue((work / name).is_file(), name)
                if Path(QMLLINT).exists():
                    lint = subprocess.run([QMLLINT, *map(str, work.glob("*.qml"))], capture_output=True, text=True)
                    self.assertNotIn("[syntax]", lint.stdout + lint.stderr)

    def test_patch_refuses_a_lock_it_does_not_fit(self):
        work = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, work)
        (work / "Service.qml").write_text("import QtQuick\nItem {}\n")
        (work / "LockView.qml").write_text("import QtQuick\nItem {}\n")
        result = subprocess.run([sys.executable, "-I", str(PATCH), str(work), MARK, *UI], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((work / "Service.qml").read_text(), "import QtQuick\nItem {}\n", "nothing half-written")


if __name__ == "__main__":
    unittest.main()
