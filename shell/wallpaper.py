"""
VoidDE Wallpaper Manager (shell/wallpaper.py)
Sets desktop wallpaper, supports dynamic wallpapers (time-of-day).
Uses feh for X11, swaybg for Wayland.
100% AI-generated for VoidDE.
"""

import os, subprocess, time, threading, logging, json
from pathlib import Path
from datetime import datetime

log = logging.getLogger("voidde.wallpaper")

WALLPAPER_DIR = Path.home() / ".local" / "share" / "voidde" / "wallpapers"
CONFIG_FILE   = Path.home() / ".config" / "voidde" / "wallpaper.json"
SYSTEM_WALLS  = Path("/usr/share/voidde/wallpapers")

DEFAULT_CONFIG = {
    "mode": "static",       # static | dynamic | slideshow
    "path": "",
    "interval": 300,        # seconds for slideshow
    "dynamic": {            # macOS-style time-of-day
        "dawn":    "dawn.jpg",
        "morning": "morning.jpg",
        "noon":    "noon.jpg",
        "evening": "evening.jpg",
        "night":   "night.jpg",
    }
}


def get_time_slot():
    h = datetime.now().hour
    if 5  <= h < 7:  return "dawn"
    if 7  <= h < 12: return "morning"
    if 12 <= h < 17: return "noon"
    if 17 <= h < 20: return "evening"
    return "night"


def is_wayland():
    return os.environ.get("WAYLAND_DISPLAY") is not None


def set_wallpaper(path: str):
    if not path or not Path(path).exists():
        log.warning(f"Wallpaper not found: {path}")
        return
    if is_wayland():
        subprocess.Popen(["swaybg", "-i", path, "-m", "fill"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.run(["feh", "--bg-fill", path],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    log.info(f"Wallpaper set: {path}")


def find_wallpaper(name: str) -> str:
    for d in [WALLPAPER_DIR, SYSTEM_WALLS]:
        p = d / name
        if p.exists(): return str(p)
    return ""


class WallpaperManager:
    def __init__(self):
        self.cfg = self._load()
        self._running = True

    def _load(self):
        if CONFIG_FILE.exists():
            try:
                return {**DEFAULT_CONFIG,
                        **json.loads(CONFIG_FILE.read_text())}
            except Exception: pass
        return dict(DEFAULT_CONFIG)

    def save(self, cfg: dict):
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_FILE.write_text(json.dumps(cfg, indent=2))
        self.cfg = cfg

    def apply(self):
        mode = self.cfg.get("mode", "static")
        if mode == "static":
            set_wallpaper(self.cfg.get("path",""))
        elif mode == "dynamic":
            slot  = get_time_slot()
            fname = self.cfg["dynamic"].get(slot, "")
            set_wallpaper(find_wallpaper(fname))
        elif mode == "slideshow":
            self._start_slideshow()

    def _start_slideshow(self):
        walls = list(WALLPAPER_DIR.glob("*.jpg")) + \
                list(WALLPAPER_DIR.glob("*.png"))
        if not walls: return
        idx = [0]
        def _run():
            while self._running:
                set_wallpaper(str(walls[idx[0] % len(walls)]))
                idx[0] += 1
                time.sleep(self.cfg.get("interval", 300))
        threading.Thread(target=_run, daemon=True).start()

    def run(self):
        self.apply()
        # Dynamic wallpaper: re-check every 10 min
        if self.cfg.get("mode") == "dynamic":
            def _loop():
                while self._running:
                    time.sleep(600)
                    self.apply()
            threading.Thread(target=_loop, daemon=True).start()
        try:
            while self._running: time.sleep(60)
        except KeyboardInterrupt:
            self._running = False


def main():
    wm = WallpaperManager()
    wm.run()


if __name__ == "__main__":
    main()
