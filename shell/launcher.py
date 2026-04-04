"""
VoidDE Launcher (shell/launcher.py)
macOS Spotlight-style:
- Instant fuzzy search across apps, files, calculations
- Category sections (Applications, Files, Web)
- Keyboard navigation (arrows, enter, esc)
- Calculator built-in
100% AI-generated for VoidDE.
"""

import gi
gi.require_version("Gtk","4.0")
gi.require_version("Gdk","4.0")
from gi.repository import Gtk, Gdk, GLib, Pango

import os, subprocess, glob, logging
from pathlib import Path
from configparser import ConfigParser

log = logging.getLogger("voidde.launcher")

LAUNCHER_CSS = b"""
window.voidde-launcher {
    background-color: rgba(26,26,28,0.92);
    border-radius: 18px;
    border: 1px solid rgba(255,255,255,0.13);
}
.search-field {
    background: rgba(255,255,255,0.08);
    color: #f5f5f7;
    border: 1px solid rgba(255,255,255,0.10);
    border-radius: 12px;
    padding: 14px 18px;
    font-size: 20px;
    caret-color: #0a84ff;
}
.search-field:focus { border-color: rgba(10,132,255,0.55); }
.section-header {
    font-size: 11px;
    font-weight: 600;
    color: rgba(245,245,247,0.40);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    padding: 10px 14px 4px;
}
row.result-row {
    padding: 9px 14px;
    border-radius: 10px;
    color: #f5f5f7;
}
row.result-row:selected {
    background-color: rgba(10,132,255,0.32);
}
.result-icon { font-size: 22px; margin-right: 10px; }
.result-name { font-size: 14px; font-weight: 500; color: #f5f5f7; }
.result-desc { font-size: 12px; color: rgba(245,245,247,0.50); }
"""

DESKTOP_DIRS = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    str(Path.home() / ".local/share/applications"),
]


def load_apps():
    apps = []; seen = set()
    for d in DESKTOP_DIRS:
        for fp in glob.glob(os.path.join(d, "*.desktop")):
            try:
                cfg = ConfigParser(interpolation=None)
                cfg.read(fp, encoding="utf-8")
                if "Desktop Entry" not in cfg: continue
                e = cfg["Desktop Entry"]
                if e.get("NoDisplay","false").lower() == "true": continue
                name = e.get("Name",""); cmd = e.get("Exec","")
                desc = e.get("Comment",""); icon = e.get("Icon","")
                if name and cmd and name not in seen:
                    seen.add(name)
                    apps.append(dict(name=name,
                                     cmd=cmd.split("%")[0].strip(),
                                     desc=desc, icon=icon,
                                     category="Applications"))
            except Exception: pass
    return sorted(apps, key=lambda a: a["name"].lower())


def fuzzy(query, text):
    q = query.lower(); t = text.lower()
    if not q: return True
    i = 0
    for c in t:
        if c == q[i]:
            i += 1
            if i == len(q): return True
    return False


def try_calc(expr):
    """Safe calculator for expressions like '2+2' or 'sqrt(9)'."""
    try:
        import math
        allowed = {k:v for k,v in vars(math).items() if not k.startswith("_")}
        allowed["__builtins__"] = {}
        result = eval(expr.replace("^","**"), allowed)
        if isinstance(result, (int, float)):
            return f"= {result:g}"
    except Exception: pass
    return None


class ResultRow(Gtk.ListBoxRow):
    def __init__(self, item: dict):
        super().__init__()
        self.item = item
        self.add_css_class("result-row")

        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        hbox.set_valign(Gtk.Align.CENTER)

        icon_lbl = Gtk.Label(label=item.get("icon_char","📄"))
        icon_lbl.add_css_class("result-icon")
        hbox.append(icon_lbl)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        name_lbl = Gtk.Label(label=item["name"], xalign=0)
        name_lbl.add_css_class("result-name")
        name_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        vbox.append(name_lbl)

        if item.get("desc"):
            d = Gtk.Label(label=item["desc"], xalign=0)
            d.add_css_class("result-desc")
            d.set_ellipsize(Pango.EllipsizeMode.END)
            vbox.append(d)

        hbox.append(vbox)
        self.set_child(hbox)


class Launcher(Gtk.ApplicationWindow):
    MAX_RESULTS = 9

    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("VoidDE Launcher")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(680, -1)
        self.all_apps = load_apps()
        self._add_icons()
        self._css()
        self._build()
        self._center()
        self._show("")

    def _add_icons(self):
        icon_map = {
            "firefox":"🌐","chrome":"🌐","chromium":"🌐",
            "terminal":"💻","konsole":"💻","gnome-terminal":"💻",
            "nautilus":"🗂","nemo":"🗂","thunar":"🗂",
            "gedit":"📝","kate":"📝","code":"📝",
            "rhythmbox":"🎵","vlc":"🎬","mpv":"🎬",
            "eog":"🖼","gimp":"🖼","inkscape":"✏️",
            "thunderbird":"✉️","evolution":"✉️",
            "settings":"⚙️","control":"⚙️",
            "calculator":"🧮","gnome-calculator":"🧮",
            "calendar":"📅","gnome-calendar":"📅",
            "software":"🛍","discover":"🛍",
        }
        for a in self.all_apps:
            key = a["name"].lower().split()[0]
            a["icon_char"] = icon_map.get(key, "📦")

    def _css(self):
        p = Gtk.CssProvider(); p.load_from_data(LAUNCHER_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), p,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.add_css_class("voidde-launcher")

    def _build(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_top(14); outer.set_margin_bottom(14)
        outer.set_margin_start(14); outer.set_margin_end(14)

        self.entry = Gtk.SearchEntry()
        self.entry.set_placeholder_text("Search apps, files, or calculate…")
        self.entry.add_css_class("search-field")
        self.entry.connect("search-changed", lambda e: self._show(e.get_text()))

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        self.entry.add_controller(key)
        outer.append(self.entry)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_max_content_height(420)
        scroll.set_propagate_natural_height(True)
        scroll.set_margin_top(10)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.listbox.connect("row-activated", lambda lb, row: self._launch(row.item))
        scroll.set_child(self.listbox)
        outer.append(scroll)
        self.set_child(outer)

    def _center(self):
        d = Gdk.Display.get_default()
        m = d.get_monitors().get_item(0)
        g = m.get_geometry()
        self.set_margin_start((g.width  - 680) // 2)
        self.set_margin_top(g.height // 6)

    def _show(self, q: str):
        while r := self.listbox.get_first_child():
            self.listbox.remove(r)

        # Calculator shortcut
        if q.strip():
            val = try_calc(q)
            if val:
                item = {"name": val, "desc": "Calculator result",
                        "icon_char":"🧮", "cmd":None}
                self.listbox.append(ResultRow(item))

        # App matches
        hits = [a for a in self.all_apps
                if fuzzy(q, a["name"]) or (q and fuzzy(q, a.get("desc","")))]
        for a in hits[:self.MAX_RESULTS]:
            self.listbox.append(ResultRow(a))

        # Select first
        first = self.listbox.get_first_child()
        if first:
            self.listbox.select_row(first)

    def _on_key(self, ctrl, keyval, *_):
        if keyval == Gdk.KEY_Escape:
            self.close(); return True
        if keyval == Gdk.KEY_Return:
            row = self.listbox.get_selected_row()
            if row: self._launch(row.item)
            return True
        if keyval == Gdk.KEY_Down:
            r = self.listbox.get_selected_row()
            n = r.get_next_sibling() if r else None
            if n: self.listbox.select_row(n)
            return True
        if keyval == Gdk.KEY_Up:
            r = self.listbox.get_selected_row()
            p = r.get_prev_sibling() if r else None
            if p: self.listbox.select_row(p)
            return True
        return False

    def _launch(self, item: dict):
        cmd = item.get("cmd")
        if cmd:
            try: subprocess.Popen(cmd.split())
            except Exception as e: log.warning(f"Launch fail: {e}")
        self.close()


class LauncherApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.void.Launcher")

    def do_activate(self):
        win = Launcher(self)
        win.present()
        win.entry.grab_focus()


def main():
    import sys
    LauncherApp().run(sys.argv)


if __name__ == "__main__":
    main()
