# VoidDE

> A complete macOS-replica Linux Desktop Environment.  
> Built in Python · GTK4 · MacTahoe theme · 100% AI-generated.

---

## Features

| Component | Description |
|---|---|
| Window Manager | Full X11 WM with EWMH, keyboard shortcuts, tiling |
| Top Panel | macOS menu bar: app menu, global menu, clock, battery, wifi |
| Dock | Floating dock with magnification, running dots, right-click menus |
| Launcher | Spotlight-style fuzzy search with built-in calculator |
| File Manager | Finder-style: sidebar, breadcrumbs, search, right-click menus |
| Terminal | Tabbed terminal emulator with VTE |
| Settings | Full System Preferences: appearance, dock, date/time, notifications |
| Notifications | macOS-style banner notifications (top-right) |
| Compositor | picom: shadows, blur, transparency, rounded corners |
| Wallpaper | Static, dynamic (time-of-day), slideshow |
| Theme | MacTahoe GTK theme by vinceliuice |
| Icons | MacTahoe icon theme by vinceliuice |

---

## Install

```bash
git clone https://github.com/yourusername/voidde
cd voidde
bash install.sh          # dark mode (default)
bash install.sh --light  # light mode
```

Log out → select **VoidDE** at login screen → log in.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Super + T` | Terminal |
| `Super + Q` | Close window |
| `Super + M` | Maximize |
| `Super + F` | Fullscreen |
| `Super + D` | Tile all windows |
| `Super + Space` | Spotlight launcher |
| `Alt + LMB drag` | Move window |
| `Alt + RMB drag` | Resize window |

---

## Project Structure

```
voidde/
├── core/
│   ├── wm.py              X11 Window Manager (EWMH)
│   ├── session.py         Session Manager + autostart
│   ├── compositor.py      Window effects (opacity, shadows)
│   └── notifications.py   Notification daemon
├── shell/
│   ├── panel.py           Top menu bar
│   ├── dock.py            App dock
│   ├── launcher.py        Spotlight launcher
│   └── wallpaper.py       Wallpaper manager
├── apps/
│   ├── settings.py        System Preferences
│   ├── files.py           Finder-style file manager
│   └── terminal.py        VTE terminal emulator
├── config/
│   ├── picom.conf         Compositor config
│   └── gtk-settings.ini   GTK theme settings
├── scripts/
│   └── voidde-session     Session entry point
├── packaging/
│   └── voidde.desktop     Display manager entry
└── install.sh             One-command installer
```

---

## Credits

- **MacTahoe GTK theme** by [vinceliuice](https://github.com/vinceliuice/MacTahoe-gtk-theme)
- **MacTahoe icon theme** by [vinceliuice](https://github.com/vinceliuice/MacTahoe-icon-theme)
- **VoidDE code** — 100% AI-generated

## License

GPL-2.0 — Free and open source forever.
