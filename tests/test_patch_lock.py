"""lib/patch-lock.py against Omarchy's lock plugin.

Patches every copy of the lock it can find: the installed one
(/usr/share/omarchy/shell/plugins/lock) and any folders listed in
OMARCHY_LOCK_SOURCES (colon-separated; CI passes upstream's master). The
patched QML must parse, or the account would be left with no lock at all.
"""

import os
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
        result = subprocess.run([sys.executable, "-I", str(PATCH), str(work), MARK], capture_output=True, text=True)
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
                view = (work / "LockView.qml").read_text()
                self.assertIn(MARK, service)
                for needed in ("handleSessionEvent", "forgetLogindUnlock", "omarchy-greeter-session-watch"):
                    self.assertIn(needed, service)
                for needed in ("omarchyGreeterSwitch", "activeFocusOnTab: true", "switchFocused()"):
                    self.assertIn(needed, view)
                # Handlers qmllint does not flag but QML refuses: one of each per object.
                self.assertEqual(service.count("onLockRequestedChanged"), 1)
                if Path(QMLLINT).exists():
                    lint = subprocess.run([QMLLINT, str(work / "Service.qml"), str(work / "LockView.qml")],
                                          capture_output=True, text=True)
                    self.assertNotIn("[syntax]", lint.stdout + lint.stderr)

    def test_patch_refuses_a_lock_it_does_not_fit(self):
        work = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, work)
        (work / "Service.qml").write_text("import QtQuick\nItem {}\n")
        (work / "LockView.qml").write_text("import QtQuick\nItem {}\n")
        result = subprocess.run([sys.executable, "-I", str(PATCH), str(work), MARK], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((work / "Service.qml").read_text(), "import QtQuick\nItem {}\n", "nothing half-written")


if __name__ == "__main__":
    unittest.main()
