"""
VoidDE Terminal (apps/terminal.py)
macOS Terminal.app-style terminal emulator using VTE.
Features: tabs, profiles, transparency, custom font.
100% AI-generated for VoidDE.
"""

import gi
gi.require_version("Gtk","4.0")
gi.require_version("Gdk","4.0")
try:
    gi.require_version("Vte","3.91")
    from gi.repository import Vte
    HAS_VTE = True
except Exception:
    HAS_VTE = False

from gi.repository import Gtk, Gdk, GLib, Pango
import os, logging

log = logging.getLogger("voidde.terminal")

TERM_CSS = b"""
window.voidde-terminal {
    background-color: rgba(18,18,20,0.96);
}
notebook tab {
    background: rgba(255,255,255,0.05);
    color: rgba(245,245,247,0.70);
    border-radius: 8px 8px 0 0;
    padding: 5px 14px;
    font-size: 12px;
}
notebook tab:checked {
    background: rgba(255,255,255,0.12);
    color: #f5f5f7;
}
"""

BG_COLOR = "#121214"
FG_COLOR = "#f5f5f7"
FONT     = "SF Mono 13"

PALETTE = [
    "#1c1c1e","#ff453a","#30d158","#ffd60a",
    "#0a84ff","#bf5af2","#5ac8fa","#ebebf5",
    "#636366","#ff6961","#34c759","#ffd426",
    "#409cff","#da8fff","#70d7ff","#ffffff",
]


class TermTab(Gtk.Box):
    """One terminal tab with a VTE widget."""

    def __init__(self, cwd=None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_hexpand(True); self.set_vexpand(True)

        if not HAS_VTE:
            lbl = Gtk.Label(label=(
                "VTE not installed.\n"
                "Install: sudo apt install gir1.2-vte-3.91 python3-gi\n"
                "Then restart VoidDE Terminal."))
            lbl.set_valign(Gtk.Align.CENTER)
            self.append(lbl)
            return

        self.term = Vte.Terminal()
        self.term.set_scrollback_lines(10000)
        self.term.set_font(Pango.FontDescription.from_string(FONT))
        self.term.set_color_background(self._rgba(BG_COLOR))
        self.term.set_color_foreground(self._rgba(FG_COLOR))

        palette = [self._rgba(c) for c in PALETTE]
        self.term.set_colors(self._rgba(FG_COLOR), self._rgba(BG_COLOR), palette)

        scroll = Gtk.ScrolledWindow()
        scroll.set_child(self.term)
        scroll.set_hexpand(True); scroll.set_vexpand(True)
        self.append(scroll)

        env = list(os.environ.copy().items())
        env_list = [f"{k}={v}" for k,v in env]
        env_list.append("TERM=xterm-256color")

        shell = os.environ.get("SHELL", "/bin/bash")
        self.term.spawn_async(
            Vte.PtyFlags.DEFAULT,
            cwd or os.path.expanduser("~"),
            [shell],
            env_list,
            GLib.SpawnFlags.DEFAULT,
            None, None, -1, None, None
        )

    def _rgba(self, hex_: str) -> Gdk.RGBA:
        r = Gdk.RGBA()
        r.parse(hex_)
        return r


class TerminalWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title("VoidDE Terminal")
        self.set_default_size(900, 580)
        self.add_css_class("voidde-terminal")

        p = Gtk.CssProvider(); p.load_from_data(TERM_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), p,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self._build()

    def _build(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # Toolbar
        tb = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        tb.set_margin_top(6); tb.set_margin_bottom(6)
        tb.set_margin_start(10); tb.set_margin_end(10)

        new_tab = Gtk.Button(label="＋ New Tab")
        new_tab.set_has_frame(False)
        new_tab.connect("clicked", lambda _: self._new_tab())
        tb.append(new_tab)
        vbox.append(tb)

        # Notebook (tabs)
        self.nb = Gtk.Notebook()
        self.nb.set_tab_pos(Gtk.PositionType.TOP)
        self.nb.set_scrollable(True)
        self.nb.set_hexpand(True); self.nb.set_vexpand(True)
        vbox.append(self.nb)

        self.set_child(vbox)
        self._new_tab()

    def _new_tab(self):
        tab  = TermTab()
        label= Gtk.Label(label="Terminal")
        self.nb.append_page(tab, label)
        self.nb.set_current_page(self.nb.get_n_pages()-1)
        tab.show()


class TerminalApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.void.Terminal")

    def do_activate(self):
        TerminalWindow(self).present()


def main():
    import sys
    TerminalApp().run(sys.argv)


if __name__ == "__main__":
    main()
