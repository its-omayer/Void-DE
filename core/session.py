"""
VoidDE Session Manager (core/session.py)
Launches, supervises, and restarts DE components.
Handles XDG autostart, environment setup, and clean shutdown.
100% AI-generated for VoidDE.
"""

import os, sys, signal, subprocess, threading, logging, time, json
from pathlib import Path

log = logging.getLogger("voidde.session")
logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [VoidDE:Session] %(message)s",
                    datefmt="%H:%M:%S")

CONFIG_DIR   = Path.home() / ".config" / "voidde"
AUTOSTART_DIR= CONFIG_DIR / "autostart"
SETTINGS_FILE= CONFIG_DIR / "settings.json"

COMPONENTS = [
    # (name,               command,              required, restart_delay)
    ("notification-daemon",["voidde-notify"],      False,   2),
    ("panel",              ["voidde-panel"],        True,    1),
    ("dock",               ["voidde-dock"],         True,    1),
    ("wallpaper",          ["voidde-wallpaper"],    False,   3),
]


def load_settings():
    defaults = {"theme":"dark","accent":"#0a84ff","animations":True,
                "dock_autohide":False,"clock_format":"12h"}
    if SETTINGS_FILE.exists():
        try:
            return {**defaults, **json.loads(SETTINGS_FILE.read_text())}
        except Exception: pass
    return defaults


class SessionManager:
    def __init__(self):
        self.procs   = {}
        self.running = False
        self.cfg     = load_settings()
        self._setup_env()
        signal.signal(signal.SIGTERM, self._quit)
        signal.signal(signal.SIGINT,  self._quit)

    def _setup_env(self):
        env = {
            "XDG_CURRENT_DESKTOP": "VoidDE",
            "XDG_SESSION_DESKTOP": "voidde",
            "GTK_THEME":           "MacTahoe-Dark",
            "GTK_ICON_THEME":      "MacTahoe",
            "XCURSOR_THEME":       "MacTahoe-cursors",
            "XCURSOR_SIZE":        "24",
            "QT_QPA_PLATFORMTHEME":"gtk3",
            "QT_STYLE_OVERRIDE":   "gtk3",
            "XDG_DATA_HOME":       str(Path.home()/".local"/"share"),
            "XDG_CONFIG_HOME":     str(Path.home()/".config"),
            "XDG_CACHE_HOME":      str(Path.home()/".cache"),
        }
        if self.cfg.get("theme") == "light":
            env["GTK_THEME"] = "MacTahoe-Light"
        for k,v in env.items():
            os.environ.setdefault(k, v)
        log.info("Environment configured.")

    def _launch(self, name, cmd):
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL)
            self.procs[name] = p
            log.info(f"Started {name} (pid={p.pid})")
            return p
        except FileNotFoundError:
            log.warning(f"Not found: {name} ({cmd[0]})")
            return None

    def _watchdog(self):
        while self.running:
            time.sleep(4)
            for name, cmd, required, delay in COMPONENTS:
                if not required: continue
                p = self.procs.get(name)
                if p and p.poll() is not None:
                    log.warning(f"{name} crashed, restarting in {delay}s…")
                    time.sleep(delay)
                    self._launch(name, cmd)

    def _autostart(self):
        dirs = [AUTOSTART_DIR, Path("/etc/voidde/autostart"),
                Path("/usr/share/voidde/autostart")]
        for d in dirs:
            if not d.exists(): continue
            for df in d.glob("*.desktop"):
                try:
                    lines = df.read_text().splitlines()
                    exec_line = next((l[5:].strip() for l in lines
                                      if l.startswith("Exec=")), None)
                    hidden    = any(l.strip()=="Hidden=true" for l in lines)
                    if exec_line and not hidden:
                        subprocess.Popen(exec_line.split("%")[0].strip().split())
                        log.info(f"Autostart: {df.stem}")
                except Exception as e:
                    log.warning(f"Autostart error {df}: {e}")

    def start(self):
        self.running = True
        log.info("VoidDE session starting…")
        for name, cmd, _, __ in COMPONENTS:
            self._launch(name, cmd)
        threading.Thread(target=self._watchdog, daemon=True).start()
        time.sleep(1.5)
        self._autostart()
        log.info("VoidDE session ready.")

    def stop(self):
        self.running = False
        log.info("Shutting down VoidDE…")
        for name, p in list(self.procs.items()):
            try: p.terminate(); p.wait(timeout=3)
            except Exception: p.kill()
            log.debug(f"Stopped {name}")
        log.info("Session ended.")

    def _quit(self, *_):
        self.stop(); sys.exit(0)

    def logout(self):
        self.stop()
        os.system("pkill -u $USER Xorg 2>/dev/null || pkill -u $USER Xwayland 2>/dev/null || true")

    def reboot(self):
        self.stop(); os.system("systemctl reboot")

    def shutdown(self):
        self.stop(); os.system("systemctl poweroff")


def main():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    sm = SessionManager()
    sm.start()
    try:
        while True: time.sleep(60)
    except (KeyboardInterrupt, SystemExit):
        sm.stop()


if __name__ == "__main__":
    main()
