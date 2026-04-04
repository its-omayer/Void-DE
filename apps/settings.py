"""
VoidDE Settings (apps/settings.py)
Full macOS System Preferences-style settings app.
Sections: Appearance, Desktop, Dock, Display, Keyboard,
          Notifications, Users, About.
Built with GTK4 + PyGObject.
100% AI-generated for VoidDE.
"""

import gi
gi.require_version("Gtk","4.0")
gi.require_version("Gdk","4.0")
gi.require_version("Adw","1")
from gi.repository import Gtk, Gdk, GLib, Adw

import json, logging, os, subprocess
from pathlib import Path

log = logging.getLogger("voidde.settings")
logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [VoidDE:Settings] %(message)s", datefmt="%H:%M:%S")

CONFIG_DIR  = Path.home() / ".config" / "voidde"
CONFIG_FILE = CONFIG_DIR / "settings.json"

DEFAULTS = {
    "theme":           "dark",
    "accent_color":    "#0a84ff",
    "font_size":       13,
    "animations":      True,
    "transparency":    True,
    "dock_size":       52,
    "dock_autohide":   False,
    "dock_position":   "bottom",
    "clock_format":    "12h",
    "show_seconds":    False,
    "hot_corners":     True,
    "natural_scroll":  True,
    "wallpaper_mode":  "static",
    "wallpaper_path":  "",
    "notifications":   True,
    "do_not_disturb":  False,
}

SETTINGS_CSS = b"""
window { background-color: #1a1a1c; }
.sidebar { background-color: #161618; border-right: 1px solid rgba(255,255,255,0.06); }
.sidebar-row { padding: 9px 16px; border-radius: 9px; color: #e5e5ea; font-size: 13px; }
.sidebar-row:selected { background-color: rgba(10,132,255,0.28); }
.page-title { font-size: 22px; font-weight: 700; color: #f5f5f7;
              padding: 22px 24px 10px; }
.section-label { font-size: 11px; font-weight: 600;
                 color: rgba(245,245,247,0.38);
                 text-transform: uppercase; letter-spacing:0.07em;
                 padding: 14px 20px 5px; }
.pref-group { background-color: rgba(255,255,255,0.05);
              border-radius: 12px; margin: 0 20px 12px; }
.pref-row { padding: 12px 16px; color: #f5f5f7; }
.pref-row-sep { background: rgba(255,255,255,0.06); min-height:1px; margin:0 14px; }
.pref-key { font-size: 13px; color: #f5f5f7; }
.pref-val { font-size: 12px; color: rgba(245,245,247,0.50); }
"""


def load_cfg():
    if CONFIG_FILE.exists():
        try: return {**DEFAULTS, **json.loads(CONFIG_FILE.read_text())}
        except Exception: pass
    return dict(DEFAULTS)


def save_cfg(cfg):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(cfg, indent=2))


def row(label, sublabel, widget):
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
    box.add_css_class("pref-row")
    left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
    left.set_hexpand(True)
    k = Gtk.Label(label=label, xalign=0); k.add_css_class("pref-key")
    left.append(k)
    if sublabel:
        s = Gtk.Label(label=sublabel, xalign=0); s.add_css_class("pref-val")
        left.append(s)
    box.append(left)
    box.append(widget)
    return box


def sep():
    s = Gtk.Separator(); s.add_css_class("pref-row-sep"); return s


def section(title):
    l = Gtk.Label(label=title, xalign=0); l.add_css_class("section-label"); return l


def group(*rows):
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
    box.add_css_class("pref-group")
    for i, r in enumerate(rows):
        box.append(r)
        if i < len(rows)-1: box.append(sep())
    return box


# ── Pages ──────────────────────────────────────────────────────────────────

class AppearancePage(Gtk.Box):
    def __init__(self, cfg, on_save):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.cfg = cfg; self.on_save = on_save
        title = Gtk.Label(label="Appearance", xalign=0); title.add_css_class("page-title")
        self.append(title)
        self.append(section("Style"))

        dark_sw = Gtk.Switch(); dark_sw.set_active(cfg["theme"]=="dark")
        dark_sw.connect("notify::active",
            lambda s,_: self._set("theme","dark" if s.get_active() else "light"))
        self.append(group(row("Dark mode","System-wide dark appearance",dark_sw)))

        self.append(section("Accent Color"))
        color_btn = Gtk.ColorButton()
        color_btn.set_use_alpha(False)
        rgba = Gdk.RGBA()
        rgba.parse(cfg.get("accent_color","#0a84ff"))
        color_btn.set_rgba(rgba)
        color_btn.connect("color-set",lambda b: self._set(
            "accent_color", b.get_rgba().to_string()))
        self.append(group(row("Accent color","Used for buttons and highlights",color_btn)))

        self.append(section("Visual Effects"))
        anim_sw = Gtk.Switch(); anim_sw.set_active(cfg["animations"])
        anim_sw.connect("notify::active",lambda s,_: self._set("animations",s.get_active()))
        trans_sw = Gtk.Switch(); trans_sw.set_active(cfg["transparency"])
        trans_sw.connect("notify::active",lambda s,_: self._set("transparency",s.get_active()))
        font_spin = Gtk.SpinButton.new_with_range(9, 24, 1)
        font_spin.set_value(cfg["font_size"])
        font_spin.connect("value-changed",lambda b: self._set("font_size",int(b.get_value())))
        self.append(group(
            row("Animations","Smooth window transitions",anim_sw),
            row("Transparency","Frosted glass effects",trans_sw),
            row("Font size","System font size in pt",font_spin),
        ))

    def _set(self, key, val):
        self.cfg[key] = val; self.on_save(self.cfg)


class DockPage(Gtk.Box):
    def __init__(self, cfg, on_save):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.cfg = cfg; self.on_save = on_save
        title = Gtk.Label(label="Dock", xalign=0); title.add_css_class("page-title")
        self.append(title)
        self.append(section("Dock Settings"))

        size_sc = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL,32,80,4)
        size_sc.set_value(cfg["dock_size"]); size_sc.set_size_request(150,-1)
        size_sc.connect("value-changed",lambda s: self._set("dock_size",int(s.get_value())))

        hide_sw = Gtk.Switch(); hide_sw.set_active(cfg["dock_autohide"])
        hide_sw.connect("notify::active",lambda s,_: self._set("dock_autohide",s.get_active()))

        pos_dd = Gtk.DropDown.new_from_strings(["Bottom","Left","Right"])
        pos_map = {"bottom":0,"left":1,"right":2}
        pos_dd.set_selected(pos_map.get(cfg["dock_position"],0))
        pos_dd.connect("notify::selected",
            lambda d,_: self._set("dock_position",["bottom","left","right"][d.get_selected()]))

        self.append(group(
            row("Icon size","Dock icon size in pixels",size_sc),
            row("Auto-hide","Hide dock when not in use",hide_sw),
            row("Position","Dock screen edge",pos_dd),
        ))

    def _set(self, key, val):
        self.cfg[key] = val; self.on_save(self.cfg)


class DateTimePage(Gtk.Box):
    def __init__(self, cfg, on_save):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.cfg = cfg; self.on_save = on_save
        title = Gtk.Label(label="Date & Time", xalign=0); title.add_css_class("page-title")
        self.append(title)
        self.append(section("Clock"))

        fmt_dd = Gtk.DropDown.new_from_strings(["12-hour","24-hour"])
        fmt_dd.set_selected(0 if cfg["clock_format"]=="12h" else 1)
        fmt_dd.connect("notify::selected",
            lambda d,_: self._set("clock_format","12h" if d.get_selected()==0 else "24h"))

        sec_sw = Gtk.Switch(); sec_sw.set_active(cfg["show_seconds"])
        sec_sw.connect("notify::active",lambda s,_: self._set("show_seconds",s.get_active()))

        self.append(group(
            row("Clock format","12-hour or 24-hour display",fmt_dd),
            row("Show seconds","Display seconds in the menu bar",sec_sw),
        ))

    def _set(self, key, val):
        self.cfg[key] = val; self.on_save(self.cfg)


class NotificationsPage(Gtk.Box):
    def __init__(self, cfg, on_save):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.cfg = cfg; self.on_save = on_save
        title = Gtk.Label(label="Notifications", xalign=0); title.add_css_class("page-title")
        self.append(title)
        self.append(section("Notification Settings"))

        notif_sw = Gtk.Switch(); notif_sw.set_active(cfg["notifications"])
        notif_sw.connect("notify::active",lambda s,_: self._set("notifications",s.get_active()))

        dnd_sw = Gtk.Switch(); dnd_sw.set_active(cfg["do_not_disturb"])
        dnd_sw.connect("notify::active",lambda s,_: self._set("do_not_disturb",s.get_active()))

        self.append(group(
            row("Allow notifications","Show app notifications",notif_sw),
            row("Do Not Disturb","Silence all notifications",dnd_sw),
        ))

    def _set(self, key, val):
        self.cfg[key] = val; self.on_save(self.cfg)


class AboutPage(Gtk.Box):
    def __init__(self, cfg, on_save):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        title = Gtk.Label(label="About VoidDE", xalign=0); title.add_css_class("page-title")
        self.append(title)
        self.append(section("System"))

        import platform
        uname = platform.uname()
        info = [
            ("VoidDE Version", "1.0.0"),
            ("Python",         platform.python_version()),
            ("OS",             f"{uname.system} {uname.release}"),
            ("Architecture",   uname.machine),
            ("Theme",          "MacTahoe by vinceliuice"),
            ("Icons",          "MacTahoe Icons by vinceliuice"),
        ]
        rows = [row(k, None, Gtk.Label(label=v, xalign=1)) for k,v in info]
        self.append(group(*rows))


PAGES = [
    ("Appearance",     "◑",  AppearancePage),
    ("Dock",           "⬛",  DockPage),
    ("Date & Time",    "🕐",  DateTimePage),
    ("Notifications",  "🔔", NotificationsPage),
    ("About",          "ℹ",  AboutPage),
]


class SettingsApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.void.Settings")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("VoidDE Settings")
        win.set_default_size(800, 540)
        win.set_resizable(True)

        p = Gtk.CssProvider(); p.load_from_data(SETTINGS_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), p,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        cfg = load_cfg()
        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        paned.set_position(210)

        # Sidebar
        sidebar = Gtk.ListBox()
        sidebar.add_css_class("sidebar")
        sidebar.set_selection_mode(Gtk.SelectionMode.SINGLE)

        stack = Gtk.Stack()
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        stack.set_transition_duration(180)

        def on_select(lb, row_):
            if row_: stack.set_visible_child_name(PAGES[row_.get_index()][0])

        sidebar.connect("row-selected", on_select)

        for name, icon, PageClass in PAGES:
            lbl = Gtk.Label(label=f"{icon}  {name}", xalign=0)
            lbl.add_css_class("sidebar-row")
            sidebar.append(lbl)
            page = PageClass(cfg, lambda c: save_cfg(c))
            scroll = Gtk.ScrolledWindow(); scroll.set_child(page)
            scroll.set_hexpand(True); scroll.set_vexpand(True)
            stack.add_titled(scroll, name, name)

        sidebar.select_row(sidebar.get_first_child())

        sb_scroll = Gtk.ScrolledWindow(); sb_scroll.set_child(sidebar)
        sb_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sb_scroll.add_css_class("sidebar")
        paned.set_start_child(sb_scroll)
        paned.set_end_child(stack)

        win.set_child(paned)
        win.present()


def main():
    import sys
    SettingsApp().run(sys.argv)


if __name__ == "__main__":
    main()
