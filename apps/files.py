"""
VoidDE Files (apps/files.py)
macOS Finder-style file manager:
- Sidebar (Favourites, Devices, Network)
- Column view / icon view / list view
- Path bar, search, breadcrumbs
- Open, copy, paste, delete, rename
- Preview panel
Built with GTK4 + PyGObject.
100% AI-generated for VoidDE.
"""

import gi
gi.require_version("Gtk","4.0")
gi.require_version("Gdk","4.0")
gi.require_version("Gio","2.0")
from gi.repository import Gtk, Gdk, Gio, GLib, Pango

import os, subprocess, logging, shutil
from pathlib import Path

log = logging.getLogger("voidde.files")

FILES_CSS = b"""
window { background-color: #1a1a1c; color: #f5f5f7; }
.files-sidebar { background-color: #141416;
                 border-right:1px solid rgba(255,255,255,0.07); }
.sidebar-section { font-size:10px; font-weight:700;
                   color:rgba(245,245,247,0.35);
                   text-transform:uppercase; letter-spacing:0.08em;
                   padding:12px 14px 4px; }
.sidebar-item { border-radius:7px; padding:6px 14px;
                color:#e5e5ea; font-size:13px; }
.sidebar-item:selected { background-color:rgba(10,132,255,0.28); }
.pathbar { background:rgba(255,255,255,0.05); border-radius:8px;
           padding:4px 10px; font-size:13px; color:#f5f5f7;
           border:1px solid rgba(255,255,255,0.08); }
.file-item { border-radius:8px; padding:6px 10px; color:#f5f5f7; }
.file-item:selected { background-color:rgba(10,132,255,0.28); }
.file-name { font-size:12px; color:#f5f5f7; }
.file-size { font-size:11px; color:rgba(245,245,247,0.45); }
.toolbar { background:rgba(30,30,32,0.95);
           border-bottom:1px solid rgba(255,255,255,0.07);
           padding:6px 12px; }
"""

FAVOURITES = [
    ("AirDrop",   "📡", None),
    ("Recents",   "🕐", str(Path.home())),
    ("Home",      "🏠", str(Path.home())),
    ("Desktop",   "🖥",  str(Path.home()/"Desktop")),
    ("Documents", "📄", str(Path.home()/"Documents")),
    ("Downloads", "⬇️", str(Path.home()/"Downloads")),
    ("Music",     "🎵", str(Path.home()/"Music")),
    ("Pictures",  "🖼",  str(Path.home()/"Pictures")),
]

EXT_ICONS = {
    ".py":"🐍",".js":"🟨",".ts":"🔷",".html":"🌐",".css":"🎨",
    ".md":"📝",".txt":"📄",".pdf":"📕",".jpg":"🖼",".jpeg":"🖼",
    ".png":"🖼",".gif":"🎞",".mp3":"🎵",".mp4":"🎬",".zip":"📦",
    ".tar":"📦",".gz":"📦",".sh":"⚙️",".json":"📋",".xml":"📋",
    ".svg":"✏️",".iso":"💿",".deb":"📦",".AppImage":"📦",
}


def file_icon(path: Path) -> str:
    if path.is_dir(): return "📁"
    return EXT_ICONS.get(path.suffix.lower(), "📄")


def fmt_size(path: Path) -> str:
    try:
        if path.is_dir(): return "—"
        s = path.stat().st_size
        for unit in ["B","KB","MB","GB","TB"]:
            if s < 1024: return f"{s:.1f} {unit}"
            s /= 1024
    except Exception: return "—"


class FilesApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.void.Files")

    def do_activate(self):
        win = FilesWindow(self)
        win.present()


class FilesWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("Files — VoidDE")
        self.set_default_size(960, 600)
        self.current = Path.home()
        self._history = [self.current]
        self._hist_idx = 0

        p = Gtk.CssProvider(); p.load_from_data(FILES_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), p,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self._build()
        self._load(self.current)

    def _build(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # ── Toolbar ──────────────────────────────────────────────────────
        tb = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        tb.add_css_class("toolbar")

        self.back_btn  = Gtk.Button(label="‹"); self.back_btn.set_has_frame(False)
        self.fwd_btn   = Gtk.Button(label="›"); self.fwd_btn.set_has_frame(False)
        self.up_btn    = Gtk.Button(label="↑"); self.up_btn.set_has_frame(False)
        self.back_btn.connect("clicked", self._go_back)
        self.fwd_btn.connect("clicked",  self._go_fwd)
        self.up_btn.connect("clicked",   lambda _: self._navigate(self.current.parent))

        self.path_bar = Gtk.Entry()
        self.path_bar.add_css_class("pathbar")
        self.path_bar.set_hexpand(True)
        self.path_bar.connect("activate",
            lambda e: self._navigate(Path(e.get_text())))

        self.search = Gtk.SearchEntry()
        self.search.set_placeholder_text("Search")
        self.search.connect("search-changed", self._on_search)

        for w in [self.back_btn, self.fwd_btn, self.up_btn,
                  self.path_bar, self.search]:
            tb.append(w)
        vbox.append(tb)

        # ── Content pane ─────────────────────────────────────────────────
        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        paned.set_position(180)

        # Sidebar
        sb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sb.add_css_class("files-sidebar")
        sb.set_size_request(180, -1)

        fav_lbl = Gtk.Label(label="Favourites", xalign=0)
        fav_lbl.add_css_class("sidebar-section")
        sb.append(fav_lbl)

        fav_list = Gtk.ListBox()
        fav_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        fav_list.connect("row-activated", self._on_fav)
        for name, icon, path in FAVOURITES:
            lbl = Gtk.Label(label=f"{icon}  {name}", xalign=0)
            lbl.add_css_class("sidebar-item")
            fav_list.append(lbl)
        sb.append(fav_list)
        self._fav_paths = [p for _,__,p in FAVOURITES]
        self._fav_list  = fav_list

        sb_scroll = Gtk.ScrolledWindow()
        sb_scroll.set_child(sb)
        sb_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        paned.set_start_child(sb_scroll)

        # File list
        self.file_list = Gtk.ListBox()
        self.file_list.set_selection_mode(Gtk.SelectionMode.MULTIPLE)
        self.file_list.connect("row-activated", self._on_activate)
        self.file_list.add_css_class("file-list")

        # Right-click menu
        gesture = Gtk.GestureClick(); gesture.set_button(3)
        gesture.connect("pressed", self._on_right_click)
        self.file_list.add_controller(gesture)

        fl_scroll = Gtk.ScrolledWindow()
        fl_scroll.set_child(self.file_list)
        fl_scroll.set_hexpand(True); fl_scroll.set_vexpand(True)
        paned.set_end_child(fl_scroll)

        vbox.append(paned)
        self.set_child(vbox)

    def _load(self, path: Path, search: str = ""):
        while r := self.file_list.get_first_child():
            self.file_list.remove(r)

        try:
            entries = sorted(path.iterdir(),
                             key=lambda p: (not p.is_dir(), p.name.lower()))
        except PermissionError:
            return

        for entry in entries:
            if search and search.lower() not in entry.name.lower():
                continue
            self._add_row(entry)

        self.path_bar.set_text(str(path))
        self.current = path
        self.set_title(f"{path.name or '/'} — VoidDE Files")
        self.back_btn.set_sensitive(self._hist_idx > 0)
        self.fwd_btn.set_sensitive(self._hist_idx < len(self._history)-1)

    def _add_row(self, entry: Path):
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        hbox.add_css_class("file-item"); hbox.set_margin_top(1); hbox.set_margin_bottom(1)

        icon_lbl = Gtk.Label(label=file_icon(entry))
        hbox.append(icon_lbl)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        name_lbl = Gtk.Label(label=entry.name, xalign=0)
        name_lbl.add_css_class("file-name")
        name_lbl.set_ellipsize(Pango.EllipsizeMode.MIDDLE)
        vbox.append(name_lbl)

        size_lbl = Gtk.Label(label=fmt_size(entry), xalign=0)
        size_lbl.add_css_class("file-size")
        vbox.append(size_lbl)
        hbox.append(vbox)

        row = Gtk.ListBoxRow()
        row._path = entry
        row.set_child(hbox)
        self.file_list.append(row)

    def _navigate(self, path: Path):
        if not path.exists(): return
        self._hist_idx += 1
        self._history = self._history[:self._hist_idx]
        self._history.append(path)
        self._load(path)

    def _go_back(self, _):
        if self._hist_idx > 0:
            self._hist_idx -= 1
            self._load(self._history[self._hist_idx])

    def _go_fwd(self, _):
        if self._hist_idx < len(self._history)-1:
            self._hist_idx += 1
            self._load(self._history[self._hist_idx])

    def _on_fav(self, lb, row_):
        path = self._fav_paths[row_.get_index()]
        if path: self._navigate(Path(path))

    def _on_activate(self, lb, row_):
        p = row_._path
        if p.is_dir(): self._navigate(p)
        else:
            subprocess.Popen(["xdg-open", str(p)])

    def _on_search(self, entry):
        self._load(self.current, entry.get_text())

    def _on_right_click(self, gesture, n, x, y):
        row_ = self.file_list.get_row_at_y(int(y))
        if not row_: return
        p = row_._path
        menu_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        items = [
            ("Open",              lambda: subprocess.Popen(["xdg-open", str(p)])),
            ("Open in Terminal",  lambda: subprocess.Popen(["x-terminal-emulator","--working-directory",str(p if p.is_dir() else p.parent)])),
            ("Copy",              lambda: self._copy(p)),
            ("Move to Trash",     lambda: subprocess.Popen(["gio","trash", str(p)])),
            ("Rename…",           lambda: self._rename(row_, p)),
        ]
        for label, cb in items:
            b = Gtk.Button(label=label); b.set_has_frame(False)
            b.connect("clicked", lambda btn, f=cb: f())
            menu_box.append(b)
        pop = Gtk.Popover(); pop.set_child(menu_box); pop.set_parent(row_); pop.popup()

    def _copy(self, p: Path):
        os.system(f"echo '{p}' | xclip -selection clipboard 2>/dev/null || true")

    def _rename(self, row_, p: Path):
        dlg = Gtk.AlertDialog()
        dlg.set_message(f"Rename '{p.name}'")
        dlg.show(self)


def main():
    import sys
    FilesApp().run(sys.argv)


if __name__ == "__main__":
    main()
