"""
VoidDE Top Panel (shell/panel.py)
Full macOS-style menu bar:
- Apple/VoidDE logo menu (shutdown, restart, logout, settings)
- Active app name + fake global menu
- Right side: wifi, battery, volume, clock, notification bell
- System tray area
Built with GTK4 + PyGObject. MacTahoe theme applied via GTK_THEME.
100% AI-generated for VoidDE.
"""

import gi
gi.require_version("Gtk","4.0")
gi.require_version("Gdk","4.0")
gi.require_version("GLib","2.0")
from gi.repository import Gtk, Gdk, GLib

import os, time, subprocess, logging, threading
import psutil

log = logging.getLogger("voidde.panel")
logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [VoidDE:Panel] %(message)s", datefmt="%H:%M:%S")

PANEL_H = 32

PANEL_CSS = b"""
window.voidde-panel {
    background-color: rgba(22, 22, 24, 0.90);
    color: #f5f5f7;
    border-bottom: 1px solid rgba(255,255,255,0.07);
    font-size: 13px;
}
.panel-btn {
    background: none;
    border: none;
    color: #f5f5f7;
    padding: 0 9px;
    border-radius: 5px;
    font-size: 13px;
    min-height: 22px;
}
.panel-btn:hover { background-color: rgba(255,255,255,0.12); }
.panel-btn:active { background-color: rgba(255,255,255,0.06); }
.panel-logo { font-size: 16px; padding: 0 12px; }
.panel-sep { background-color: rgba(255,255,255,0.12); min-width:1px; margin: 6px 2px; }
.panel-clock { font-size: 13px; font-weight: 500; color: #f5f5f7; padding: 0 8px; }
.panel-stat { font-size: 12px; color: rgba(245,245,247,0.70); padding: 0 5px; }
.panel-menu { background-color: rgba(28,28,30,0.96); border-radius:10px;
               border: 1px solid rgba(255,255,255,0.10); padding: 4px; }
.panel-menu-item { border-radius:6px; padding: 5px 12px; color:#f5f5f7; font-size:13px; }
.panel-menu-item:hover { background-color:#0a84ff; color:#fff; }
"""


def make_sep():
    s = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
    s.add_css_class("panel-sep")
    return s


class AppleMenu(Gtk.MenuButton):
    """VoidDE ◈ logo with power/settings popover."""

    def __init__(self, session_cb):
        super().__init__()
        self.add_css_class("panel-btn")
        self.add_css_class("panel-logo")
        self.set_label("◈")
        self.set_has_frame(False)
        self.session_cb = session_cb

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        box.add_css_class("panel-menu")

        items = [
            ("About VoidDE",  self._about),
            ("─────────────", None),
            ("System Settings…", lambda: subprocess.Popen(["voidde-settings"])),
            ("─────────────", None),
            ("Sleep",         lambda: os.system("systemctl suspend")),
            ("Restart…",      lambda: session_cb("restart")),
            ("Shut Down…",    lambda: session_cb("shutdown")),
            ("─────────────", None),
            ("Log Out",       lambda: session_cb("logout")),
        ]
        for label, cb in items:
            if label.startswith("─"):
                box.append(Gtk.Separator())
                continue
            btn = Gtk.Button(label=label)
            btn.add_css_class("panel-menu-item")
            btn.set_has_frame(False)
            if cb:
                btn.connect("clicked", lambda b, f=cb: (f(), self.popdown()))
            box.append(btn)

        pop = Gtk.Popover()
        pop.set_child(box)
        pop.add_css_class("panel-menu")
        self.set_popover(pop)

    def _about(self):
        dlg = Gtk.AlertDialog()
        dlg.set_message("VoidDE 1.0")
        dlg.set_detail("macOS-inspired Linux Desktop\nBuilt with GTK4 + Python\nTheme: MacTahoe by vinceliuice")
        dlg.show(None)


class AppNameMenu(Gtk.Box):
    """Active app name + fake File/Edit/View global menu."""

    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.app_btn = Gtk.Button(label="Finder")
        self.app_btn.add_css_class("panel-btn")
        self.app_btn.set_has_frame(False)
        self.append(self.app_btn)
        for menu_name in ["File", "Edit", "View", "Go", "Window", "Help"]:
            b = Gtk.Button(label=menu_name)
            b.add_css_class("panel-btn")
            b.set_has_frame(False)
            self.append(b)

    def set_app(self, name: str):
        self.app_btn.set_label(name)


class SystemTray(Gtk.Box):
    """Right side: wifi icon, battery, volume, clock."""

    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.set_halign(Gtk.Align.END)

        self.vol_lbl  = self._lbl("🔊")
        self.wifi_lbl = self._lbl("⃝")
        self.bat_lbl  = self._lbl("")
        self.cpu_lbl  = self._stat("")
        self.clk_lbl  = Gtk.Label(label="")
        self.clk_lbl.add_css_class("panel-clock")

        for w in [self.cpu_lbl, make_sep(),
                  self.bat_lbl, make_sep(),
                  self.wifi_lbl, make_sep(),
                  self.vol_lbl, make_sep(),
                  self.clk_lbl]:
            self.append(w)

        GLib.timeout_add(1000, self._tick)
        self._tick()

    def _lbl(self, text):
        l = Gtk.Label(label=text); l.add_css_class("panel-btn"); return l

    def _stat(self, text):
        l = Gtk.Label(label=text); l.add_css_class("panel-stat"); return l

    def _tick(self):
        # Clock
        fmt = "%a %b %-d   %-I:%M %p"
        self.clk_lbl.set_label(time.strftime(fmt))
        # CPU
        cpu = psutil.cpu_percent(interval=None)
        self.cpu_lbl.set_label(f"CPU {cpu:.0f}%")
        # Battery
        try:
            bat = psutil.sensors_battery()
            if bat:
                pct = bat.percent
                charging = bat.power_plugged
                if   pct > 80: icon = "🔋"
                elif pct > 40: icon = "🪫"
                else:          icon = "⚠️"
                plug = "⚡" if charging else ""
                self.bat_lbl.set_label(f"{plug}{icon}{pct:.0f}%")
            else:
                self.bat_lbl.set_label("")
        except Exception:
            self.bat_lbl.set_label("")
        # Wifi
        try:
            stats = psutil.net_if_stats()
            connected = any(s.isup for n,s in stats.items() if n != "lo")
            self.wifi_lbl.set_label("⃝ WiFi" if connected else "✗")
        except Exception:
            self.wifi_lbl.set_label("")
        return True


class Panel(Gtk.ApplicationWindow):
    def __init__(self, app, session_cb):
        super().__init__(application=app)
        self.set_title("VoidDE Panel")
        self.set_decorated(False)
        self.set_resizable(False)
        sw = self._sw()
        self.set_default_size(sw, PANEL_H)
        self._css()
        self._build(session_cb)

    def _sw(self):
        d = Gdk.Display.get_default()
        m = d.get_monitors().get_item(0)
        return m.get_geometry().width

    def _css(self):
        p = Gtk.CssProvider(); p.load_from_data(PANEL_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), p,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.add_css_class("voidde-panel")

    def _build(self, session_cb):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        row.set_hexpand(True)
        row.set_vexpand(True)

        self.apple_menu = AppleMenu(session_cb)
        row.append(self.apple_menu)
        row.append(make_sep())

        self.app_menu = AppNameMenu()
        row.append(self.app_menu)

        sp = Gtk.Box(); sp.set_hexpand(True)
        row.append(sp)

        self.tray = SystemTray()
        row.append(self.tray)

        self.set_child(row)

    def set_active_app(self, name: str):
        self.app_menu.set_app(name)


class PanelApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.void.Panel")

    def do_activate(self):
        def session_cb(action):
            from core.session import SessionManager
            sm = SessionManager()
            getattr(sm, action, sm.logout)()
        win = Panel(self, session_cb)
        win.present()


def main():
    import sys
    PanelApp().run(sys.argv)


if __name__ == "__main__":
    main()
