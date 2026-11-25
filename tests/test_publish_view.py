"""lib/publish-view: what reaches the login screen from an account's folder.

Runs as the current user: ownership changes are stubbed out and the
decoders run without the nobody sandbox (setpriv needs root).
"""

import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def load():
    loader = importlib.machinery.SourceFileLoader("publish_view", str(REPO / "lib" / "publish-view"))
    spec = importlib.util.spec_from_loader("publish_view", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def have(tool):
    return shutil.which(tool) is not None


class PublishView(unittest.TestCase):
    def setUp(self):
        self.pv = load()
        self.tmp = Path(tempfile.mkdtemp())
        self.root = self.tmp / "root"
        self.src_dir = self.root / "alex"
        self.src_dir.mkdir(parents=True)
        self.sessions = self.tmp / "sessions"
        self.sessions.mkdir()
        self.conf = self.tmp / "omarchy-greeter.conf"
        self.conf.write_text("video=no\n")
        self.pv.ROOT = str(self.root)
        self.pv.VIEW = str(self.root / ".view")
        self.pv.SESSIONS = str(self.sessions)
        self.pv.CONF = str(self.conf)
        self.pv.SANDBOX = []
        self._chown = os.chown
        os.chown = lambda *args, **kwargs: None

    def tearDown(self):
        os.chown = self._chown
        shutil.rmtree(self.tmp)

    def write(self, name, data):
        path = self.src_dir / name
        path.write_bytes(data if isinstance(data, bytes) else data.encode())
        return path

    def publish(self):
        src = self.pv.Source(str(self.src_dir), os.getuid())
        view = self.pv.View("alex", os.getgid())
        self.pv.publish("alex", src, view)
        view.prune()
        return Path(view.dir)

    def image(self, fmt, size="64x48"):
        out = self.tmp / f"sample.{fmt}"
        subprocess.run(["magick", "-size", size, "xc:#336699", str(out)], check=True)
        return out.read_bytes()

    # ---- text ------------------------------------------------------------

    def test_valid_text_passes_through(self):
        self.write("colors.toml", 'background = "#1a1b26"\naccent = "#7aa2f7"\nnot_a_color = 3\n')
        self.write("theme.name", "Tokyo Night\n")
        self.write("updated", "1764000000\n")
        self.write("switch-to", "1764000000 sam\n")
        view = self.publish()
        self.assertEqual((view / "colors.toml").read_text(), 'background = "#1a1b26"\naccent = "#7aa2f7"\n')
        self.assertEqual((view / "theme.name").read_text(), "Tokyo Night\n")
        self.assertEqual((view / "updated").read_text(), "1764000000\n")
        self.assertEqual((view / "switch-to").read_text(), "1764000000 sam\n")
        self.assertEqual(oct((view / "theme.name").stat().st_mode & 0o777), "0o640")

    def test_bad_text_is_left_out(self):
        self.write("theme.name", "<b>bold</b>\n")
        self.write("updated", "١٢٣\n")  # Arabic-Indic digits
        self.write("switch-to", "1764000000 ../root\n")
        view = self.publish()
        for name in ("theme.name", "updated", "switch-to"):
            self.assertFalse((view / name).exists(), name)

    def test_display_is_rebuilt_from_known_keys(self):
        self.write("display.json", json.dumps({
            "fontFamily": "JetBrainsMono Nerd Font",
            "fontBaseSize": 14,
            "extra": "dropped",
            "monitors": {
                "DP-1": {"scale": 1.5, "width": 3840, "height": 2160, "refresh": 143.99, "x": 0, "y": 0, "transform": 1},
                "HDMI-A-1\n": {"scale": 1},
                "eDP-1": {"scale": 99, "width": 1920, "height": 1080},
            },
        }))
        view = self.publish()
        display = json.loads((view / "display.json").read_text())
        self.assertNotIn("extra", display)
        self.assertEqual(sorted(display["monitors"]), ["DP-1", "eDP-1"])
        self.assertNotIn("scale", display["monitors"]["eDP-1"])
        self.assertEqual((view / "monitors").read_text(),
                         "DP-1 3840x2160@143.99 0x0 1.5 1\neDP-1 1920x1080@60 0x0 1 0\n")

    def test_session_marker_needs_a_live_session(self):
        self.write("session", "7\n")
        view = self.publish()
        self.assertFalse((view / "session").exists())
        self.assertFalse((self.src_dir / "session").exists(), "stale marker is dropped")
        (self.sessions / "8").write_text("STATE=active\n")
        self.write("session", "8\n")
        view = self.publish()
        self.assertEqual((view / "session").read_text(), "8\n")

    # ---- file types ------------------------------------------------------

    def test_links_fifos_and_huge_files_are_refused(self):
        secret = self.tmp / "secret"
        secret.write_text("Tokyo Night\n")
        (self.src_dir / "theme.name").symlink_to(secret)
        os.mkfifo(self.src_dir / "colors.toml")
        self.write("display.json", "{" + " " * (65 * 1024) + "}")
        view = self.publish()  # must not hang on the FIFO
        for name in ("theme.name", "colors.toml", "display.json"):
            self.assertFalse((view / name).exists(), name)

    def test_view_is_pruned(self):
        self.write("theme.name", "Tokyo Night\n")
        view = self.publish()
        self.assertTrue((view / "theme.name").exists())
        (self.src_dir / "theme.name").unlink()
        view = self.publish()
        self.assertFalse((view / "theme.name").exists())

    # ---- images ----------------------------------------------------------

    @unittest.skipUnless(have("magick"), "needs ImageMagick")
    def test_images_are_reencoded_and_checked(self):
        self.write("background.jpg", self.image("jpg"))
        self.write("avatar.png", self.image("png", "300x300"))
        view = self.publish()
        self.assertTrue((view / "background.jpg").read_bytes().startswith(b"\xff\xd8\xff"))
        avatar = view / "avatar.png"
        self.assertTrue(avatar.read_bytes().startswith(b"\x89PNG"))
        size = subprocess.run(["magick", "identify", "-format", "%wx%h", str(avatar)],
                              capture_output=True, text=True, check=True).stdout
        self.assertEqual(size, "256x256")

    @unittest.skipUnless(have("magick"), "needs ImageMagick")
    def test_disguised_images_are_refused(self):
        self.write("background.jpg", b"<svg xmlns='http://www.w3.org/2000/svg'><image href='file:///etc/passwd'/></svg>")
        self.write("avatar.png", self.image("jpg"))  # a JPEG named .png
        view = self.publish()
        self.assertFalse((view / "background.jpg").exists())
        self.assertFalse((view / "avatar.png").exists())

    # ---- video -----------------------------------------------------------

    def video(self):
        out = self.tmp / "clip.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=blue:s=320x240:d=1",
                        "-c:v", "mpeg4", str(out)], check=True)
        return out.read_bytes()

    @unittest.skipUnless(have("ffmpeg"), "needs ffmpeg")
    def test_video_only_when_the_machine_allows_it(self):
        self.write("background.mp4", self.video())
        self.write("video", "background.mp4\n")
        view = self.publish()
        self.assertFalse((view / "video").exists())
        self.conf.write_text("video=yes\n")
        view = self.publish()
        self.assertEqual((view / "video").read_text(), "background.mkv\n")
        self.assertTrue((view / "background.mkv").read_bytes().startswith(b"\x1a\x45\xdf\xa3"))

    @unittest.skipUnless(have("ffmpeg"), "needs ffmpeg")
    def test_playlist_disguised_as_video_is_refused(self):
        self.conf.write_text("video=yes\n")
        self.write("background.mp4", "#EXTM3U\n#EXTINF:1,\nfile:///etc/passwd\n")
        self.write("video", "background.mp4\n")
        view = self.publish()
        self.assertFalse((view / "video").exists())
        self.assertFalse((view / "background.mkv").exists())


if __name__ == "__main__":
    unittest.main()
