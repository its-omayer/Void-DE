#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  VoidDE Full Installer
#  Installs VoidDE + MacTahoe GTK theme + MacTahoe icons + picom compositor
#  Supports: Debian/Ubuntu · Arch Linux · Fedora · openSUSE
#  Usage: bash install.sh [--light] [--no-themes]
# ═══════════════════════════════════════════════════════════════════════════
set -e

VOIDDE_VERSION="1.0.0"
INSTALL_DIR="/usr/share/voidde"
BIN_DIR="/usr/local/bin"
SESSION_DIR="/usr/share/xsessions"
THEME_COLOR="dark"
SKIP_THEMES=false

BLU='\033[0;34m'; GRN='\033[0;32m'; YLW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; RST='\033[0m'

log()  { echo -e "${BLU}[VoidDE]${RST} $*"; }
ok()   { echo -e "${GRN}[  ok  ]${RST} $*"; }
warn() { echo -e "${YLW}[ warn ]${RST} $*"; }
fail() { echo -e "${RED}[ FAIL ]${RST} $*"; exit 1; }
ask()  { echo -e "${BOLD}${YLW}$*${RST}"; }

for arg in "$@"; do
    [[ "$arg" == "--light"     ]] && THEME_COLOR="light"
    [[ "$arg" == "--no-themes" ]] && SKIP_THEMES=true
done

echo -e "${BOLD}${BLU}"
cat << 'LOGO'
 __   __   _   _  ___   ____    ____   _____
 \ \ / /__(_) __| |  _ \|  __|  |  _ \| ____|
  \ V / _ \ |/ _` | | | | |_    | | | |  _|
   | | (_) | | (_| | |_| |  _|  | |_| | |___
   |_|\___/|_|\__,_|____/|___|  |____/|_____|
LOGO
echo -e "${RST}"
echo "  VoidDE v${VOIDDE_VERSION} — macOS-replica Linux Desktop"
echo "  Theme: MacTahoe (vinceliuice) · Icons: MacTahoe"
echo ""

# ── Detect distro ───────────────────────────────────────────────────────
if   command -v apt-get &>/dev/null; then DISTRO="debian"
elif command -v pacman  &>/dev/null; then DISTRO="arch"
elif command -v dnf     &>/dev/null; then DISTRO="fedora"
elif command -v zypper  &>/dev/null; then DISTRO="opensuse"
else fail "Unsupported distro. Install dependencies manually."; fi
log "Detected: $DISTRO"

# ── System dependencies ─────────────────────────────────────────────────
log "Installing system dependencies…"
case $DISTRO in
debian)
    sudo apt-get update -qq
    sudo apt-get install -y \
        python3 python3-pip python3-gi python3-gi-cairo \
        gir1.2-gtk-4.0 gir1.2-gdk-4.0 gir1.2-adw-1 \
        python3-xlib libvte-2.91-gtk4-0 gir1.2-vte-3.91 \
        libnotify4 gir1.2-notify-0.7 \
        picom feh xdotool wmctrl xprop dbus-x11 \
        git curl wget sassc optipng inkscape \
        fonts-inter fonts-noto-core fonts-noto-mono \
        libglib2.0-bin gio-mimeapps
    ;;
arch)
    sudo pacman -Sy --noconfirm \
        python python-pip python-gobject python-cairo \
        gtk4 libadwaita python-xlib vte3 libnotify \
        picom feh xdotool wmctrl xorg-xprop dbus \
        git curl wget sassc optipng inkscape \
        ttf-inter noto-fonts noto-fonts-extra
    ;;
fedora)
    sudo dnf install -y \
        python3 python3-pip python3-gobject python3-cairo \
        gtk4 libadwaita python3-xlib vte291 libnotify \
        picom feh xdotool wmctrl xprop dbus \
        git curl wget sassc optipng inkscape \
        google-noto-fonts-common inter-fonts
    ;;
opensuse)
    sudo zypper install -y \
        python3 python3-pip python3-gobject python3-cairo \
        gtk4 libadwaita python3-xlib vte libnotify \
        picom feh xdotool wmctrl xprop dbus-1 \
        git curl wget sassc optipng inkscape
    ;;
esac
ok "System dependencies installed."

# ── Python packages ─────────────────────────────────────────────────────
log "Installing Python packages…"
pip3 install --user psutil pywayland 2>/dev/null || true
ok "Python packages installed."

# ── MacTahoe GTK Theme ──────────────────────────────────────────────────
if ! $SKIP_THEMES; then
    log "Installing MacTahoe GTK theme…"
    TMP_THEME=$(mktemp -d)
    git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git \
        "$TMP_THEME/MacTahoe-gtk-theme" 2>/dev/null
    cd "$TMP_THEME/MacTahoe-gtk-theme"
    if [[ "$THEME_COLOR" == "light" ]]; then
        bash install.sh -c light -l
    else
        bash install.sh -c dark -l
    fi
    cd -
    rm -rf "$TMP_THEME"
    ok "MacTahoe GTK theme installed."

    log "Installing MacTahoe icon theme…"
    TMP_ICON=$(mktemp -d)
    git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git \
        "$TMP_ICON/MacTahoe-icon-theme" 2>/dev/null
    cd "$TMP_ICON/MacTahoe-icon-theme"
    bash install.sh
    cd -
    rm -rf "$TMP_ICON"
    ok "MacTahoe icon theme installed."

    # Apply GTK settings globally
    GTK3_CFG="$HOME/.config/gtk-3.0/settings.ini"
    GTK4_CFG="$HOME/.config/gtk-4.0/settings.ini"
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    for f in "$GTK3_CFG" "$GTK4_CFG"; do
        cp "$(dirname "$0")/config/gtk-settings.ini" "$f"
    done
    ok "GTK settings applied."
fi

# ── Install VoidDE core ─────────────────────────────────────────────────
log "Installing VoidDE to $INSTALL_DIR…"
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r core shell apps config scripts "$INSTALL_DIR/"
sudo cp -r themes "$INSTALL_DIR/" 2>/dev/null || true
ok "Core files installed."

# ── Install picom config ─────────────────────────────────────────────────
mkdir -p "$HOME/.config/voidde"
cp config/picom.conf "$HOME/.config/voidde/picom.conf"
ok "Picom config installed."

# ── Create launcher scripts ─────────────────────────────────────────────
log "Creating launcher scripts…"
for name in wm session panel dock launcher settings notify wallpaper files terminal; do
    case $name in
        wm)        src="core/wm.py" ;;
        session)   src="core/session.py" ;;
        notify)    src="core/notifications.py" ;;
        panel)     src="shell/panel.py" ;;
        dock)      src="shell/dock.py" ;;
        launcher)  src="shell/launcher.py" ;;
        wallpaper) src="shell/wallpaper.py" ;;
        settings)  src="apps/settings.py" ;;
        files)     src="apps/files.py" ;;
        terminal)  src="apps/terminal.py" ;;
    esac
    sudo tee "$BIN_DIR/voidde-$name" > /dev/null << SCRIPT
#!/usr/bin/env bash
exec python3 $INSTALL_DIR/$src "\$@"
SCRIPT
    sudo chmod +x "$BIN_DIR/voidde-$name"
done

# Session entry point
sudo cp scripts/voidde-session "$BIN_DIR/voidde-session"
sudo chmod +x "$BIN_DIR/voidde-session"
ok "Launcher scripts created."

# ── X session entry ─────────────────────────────────────────────────────
log "Registering session with display manager…"
sudo mkdir -p "$SESSION_DIR"
sudo cp packaging/voidde.desktop "$SESSION_DIR/"
ok "Session registered."

# ── Default user config ─────────────────────────────────────────────────
CFG="$HOME/.config/voidde"
mkdir -p "$CFG/autostart"
[[ -f "$CFG/settings.json" ]] || cat > "$CFG/settings.json" << JSON
{
  "theme": "$THEME_COLOR",
  "accent_color": "#0a84ff",
  "font_size": 13,
  "animations": true,
  "transparency": true,
  "dock_size": 52,
  "dock_autohide": false,
  "dock_position": "bottom",
  "clock_format": "12h",
  "show_seconds": false,
  "hot_corners": true,
  "notifications": true,
  "do_not_disturb": false
}
JSON
ok "User config created."

# ── Update caches ────────────────────────────────────────────────────────
log "Updating icon and font caches…"
sudo gtk-update-icon-cache -f /usr/share/icons/MacTahoe 2>/dev/null || true
sudo gtk-update-icon-cache -f "$HOME/.local/share/icons/MacTahoe" 2>/dev/null || true
fc-cache -f 2>/dev/null || true
ok "Caches updated."

# ── Done ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GRN}══════════════════════════════════════════════════${RST}"
echo -e "${BOLD}${GRN}  VoidDE v${VOIDDE_VERSION} installed successfully!${RST}"
echo -e "${BOLD}${GRN}══════════════════════════════════════════════════${RST}"
echo ""
echo "  Next steps:"
echo "  1. Log out of your current session"
echo "  2. At the login screen, select 'VoidDE'"
echo "  3. Log in and enjoy your macOS-replica desktop!"
echo ""
echo "  Keyboard shortcuts:"
echo "  Super + T         Open terminal"
echo "  Super + Q         Close window"
echo "  Super + M         Maximize window"
echo "  Super + F         Fullscreen"
echo "  Super + D         Tile all windows"
echo "  Super + Space     Open Spotlight launcher"
echo ""
echo "  Apps:"
echo "  voidde-files      File manager (Finder-style)"
echo "  voidde-settings   System Preferences"
echo "  voidde-terminal   Terminal"
echo "  voidde-launcher   Spotlight"
echo ""
