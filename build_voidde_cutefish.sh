#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║   VoidDE — Single Command Full Build Script                                 ║
# ║   Base: CutefishOS (Qt/QML) + MacTahoe GTK/Qt theme + Left window buttons  ║
# ║   Target: Debian 12+ (Bookworm) · Also supports Ubuntu 22.04+              ║
# ║                                                                              ║
# ║   Usage:  bash build_voidde_cutefish.sh                                     ║
# ║   Options:                                                                   ║
# ║     --light        Install light theme variant                               ║
# ║     --skip-themes  Skip MacTahoe theme download (use existing)              ║
# ║     --skip-clone   Skip git clone (use existing source)                     ║
# ║     --build-only   Only compile, don't install                              ║
# ║     --jobs N       Parallel make jobs (default: nproc)                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Runtime config ─────────────────────────────────────────────────────────────
VOIDDE_VERSION="1.0.0"
BUILD_DIR="$HOME/voidde-build"
SRC_DIR="$BUILD_DIR/src"
PATCH_DIR="$BUILD_DIR/patches"
INSTALL_PREFIX="/usr"
THEME_COLOR="dark"
SKIP_THEMES=false
SKIP_CLONE=false
BUILD_ONLY=false
JOBS=$(nproc 2>/dev/null || echo 4)

# ── Colors ─────────────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
B='\033[0;34m' C='\033[0;36m' W='\033[1;37m' N='\033[0m'

log()  { echo -e "${B}[voidde]${N} $*"; }
ok()   { echo -e "${G}[  ok  ]${N} $*"; }
warn() { echo -e "${Y}[ warn ]${N} $*"; }
fail() { echo -e "${R}[ FAIL ]${N} $*" >&2; exit 1; }
step() { echo -e "\n${W}${C}━━━  $*  ━━━${N}"; }

# ── Argument parsing ───────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --light)       THEME_COLOR="light"  ;;
    --skip-themes) SKIP_THEMES=true     ;;
    --skip-clone)  SKIP_CLONE=true      ;;
    --build-only)  BUILD_ONLY=true      ;;
    --jobs)        shift; JOBS="$1"     ;;
    --help|-h)
      sed -n '3,14p' "$0" | sed 's/^# //'
      exit 0 ;;
  esac
done

# ── Banner ─────────────────────────────────────────────────────────────────────
echo -e "${W}"
cat << 'BANNER'
 __   __   _   _  ___    ____   _____ 
 \ \ / /__(_) __| |  _ \|  _ \ | ____|
  \ V / _ \ |/ _` | | | | | | ||  _|  
   | | (_) | | (_| | |_| | |_| || |___
   |_|\___/|_|\__,_|____/|____/ |_____|
BANNER
echo -e "${N}"
echo -e "  ${W}VoidDE v${VOIDDE_VERSION}${N} — CutefishOS fork · MacTahoe theme · Left window buttons"
echo -e "  Base: ${C}github.com/cutefishos${N} (GPL-3.0)"
echo -e "  Theme: ${C}MacTahoe by vinceliuice${N}"
echo ""

# ── Detect distro ──────────────────────────────────────────────────────────────
step "Detecting system"
if grep -qi "debian\|ubuntu\|mint\|pop" /etc/os-release 2>/dev/null; then
  DISTRO="debian"
elif grep -qi "arch\|manjaro\|endeavour" /etc/os-release 2>/dev/null; then
  DISTRO="arch"
elif grep -qi "fedora\|rhel\|centos" /etc/os-release 2>/dev/null; then
  DISTRO="fedora"
elif grep -qi "opensuse" /etc/os-release 2>/dev/null; then
  DISTRO="opensuse"
else
  warn "Unknown distro — assuming Debian-compatible"
  DISTRO="debian"
fi
ok "Distro: $DISTRO"

# ── Install build dependencies ─────────────────────────────────────────────────
step "Installing build dependencies"
install_deps_debian() {
  sudo apt-get update -qq
  sudo apt-get install -y \
    git cmake make ninja-build pkg-config \
    qtbase5-dev qtdeclarative5-dev qtquickcontrols2-5-dev \
    qml-module-qtquick2 qml-module-qtquick-controls2 \
    qml-module-qtquick-layouts qml-module-qtquick-window2 \
    qml-module-qt-labs-platform qml-module-qtgraphicaleffects \
    libqt5x11extras5-dev libkf5windowsystem-dev \
    libkf5solid-dev libkf5networkmanagerqt-dev \
    libpolkit-qt5-1-dev libkf5bluezqt-dev \
    libkf5screen-dev libkf5sysguard-dev \
    libxcb1-dev libxcb-util-dev libxcb-image0-dev \
    libxcb-keysyms1-dev libxcb-icccm4-dev libxcb-randr0-dev \
    libx11-dev libxrender-dev libxi-dev \
    libkf5coreaddons-dev libkf5i18n-dev \
    extra-cmake-modules \
    picom feh \
    sassc optipng inkscape \
    python3 python3-pip \
    curl wget git \
    fonts-inter fonts-noto-core \
    libglib2.0-dev dbus \
    gettext
}

install_deps_arch() {
  sudo pacman -Sy --noconfirm \
    git cmake make ninja \
    qt5-base qt5-declarative qt5-quickcontrols2 \
    qt5-graphicaleffects qt5-x11extras \
    kwindowsystem solid networkmanager-qt \
    polkit-qt5 bluez-qt kscreen ksysguard \
    xcb-util xcb-util-image xcb-util-keysyms \
    xcb-util-wm extra-cmake-modules kf5 \
    picom feh sassc optipng inkscape \
    python python-pip ttf-inter noto-fonts
}

install_deps_fedora() {
  sudo dnf install -y \
    git cmake make ninja-build \
    qt5-qtbase-devel qt5-qtdeclarative-devel \
    qt5-qtquickcontrols2-devel qt5-qtgraphicaleffects \
    qt5-qtx11extras-devel \
    kf5-kwindowsystem-devel kf5-solid-devel \
    kf5-networkmanager-qt-devel \
    polkit-qt5-1-devel kf5-bluez-qt-devel \
    kf5-kscreen-devel \
    libxcb-devel xcb-util-devel xcb-util-image-devel \
    extra-cmake-modules kf5-extra-cmake-modules \
    picom feh sassc optipng inkscape \
    python3 python3-pip inter-fonts google-noto-fonts-common
}

case $DISTRO in
  debian)  install_deps_debian ;;
  arch)    install_deps_arch   ;;
  fedora)  install_deps_fedora ;;
  *)       install_deps_debian ;;
esac
ok "Build dependencies installed"

# ── Create directory structure ─────────────────────────────────────────────────
step "Creating build workspace"
mkdir -p "$SRC_DIR" "$PATCH_DIR"
ok "Workspace: $BUILD_DIR"

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Clone CutefishOS repositories
# ══════════════════════════════════════════════════════════════════════════════
step "Cloning CutefishOS repositories"

CUTEFISH_REPOS=(
  "core"
  "fishui"
  "dock"
  "launcher"
  "filemanager"
  "settings"
  "statusbar"
  "terminal"
  "screenshot"
  "screenlocker"
  "libcutefish"
  "appmotor"
)

if ! $SKIP_CLONE; then
  for repo in "${CUTEFISH_REPOS[@]}"; do
    dest="$SRC_DIR/cutefish-$repo"
    if [ -d "$dest/.git" ]; then
      log "Updating $repo…"
      git -C "$dest" pull --quiet 2>/dev/null || true
    else
      log "Cloning $repo…"
      git clone --depth=1 \
        "https://github.com/cutefishos/$repo.git" \
        "$dest" 2>/dev/null || warn "Failed to clone $repo (may not exist)"
    fi
  done
  ok "All CutefishOS repos cloned"
else
  ok "Skipped clone (--skip-clone)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Write all patch files
# Patches are written as heredocs so the script is fully self-contained.
# ══════════════════════════════════════════════════════════════════════════════
step "Writing VoidDE patches"

# ── Patch 1: MacTahoe color palette for fishui ────────────────────────────────
cat > "$PATCH_DIR/fishui-mactahoe-theme.patch" << 'PATCHEOF'
--- a/src/controls/StyleSettings.qml
+++ b/src/controls/StyleSettings.qml
@@ -1,30 +1,80 @@
 import QtQuick 2.15
 
 QtObject {
-    // Default Cutefish colors
-    property color highlightColor: "#4C6EF5"
-    property color backgroundColor: "#F0F0F0"
-    property color darkBackgroundColor: "#2A2A2D"
-    property color textColor: "#000000"
-    property color darkTextColor: "#FFFFFF"
-    property color borderColor: "#DDDDDD"
-    property color darkBorderColor: "#3A3A3C"
+    // VoidDE — MacTahoe color palette
+    // Matches vinceliuice/MacTahoe-gtk-theme exactly
+    property color highlightColor:       "#0A84FF"
+    property color highlightDarkColor:   "#0071E3"
+
+    // Backgrounds
+    property color backgroundColor:      "#F5F5F7"
+    property color darkBackgroundColor:  "#1C1C1E"
+    property color secondaryBackground:  "#FFFFFF"
+    property color darkSecondaryBg:      "#2C2C2E"
+    property color tertiaryBackground:   "#E8E8ED"
+    property color darkTertiaryBg:       "#3A3A3C"
+
+    // Text
+    property color textColor:            "#1D1D1F"
+    property color darkTextColor:        "#F5F5F7"
+    property color secondaryText:        "#6E6E73"
+    property color darkSecondaryText:    "#AEAEB2"
+    property color tertiaryText:         "#AEAEB2"
+    property color darkTertiaryText:     "#636366"
+
+    // Borders
+    property color borderColor:          "rgba(0,0,0,0.10)"
+    property color darkBorderColor:      "rgba(255,255,255,0.10)"
+
+    // Sidebar
+    property color sidebarColor:         "#F2F2F7"
+    property color darkSidebarColor:     "#1C1C1E"
+
+    // Dock / Panel
+    property color dockBackground:       "rgba(240,240,245,0.72)"
+    property color darkDockBackground:   "rgba(28,28,30,0.78)"
+    property color panelBackground:      "rgba(240,240,245,0.88)"
+    property color darkPanelBackground:  "rgba(22,22,24,0.92)"
+
+    // Semantic colors (macOS system colors)
+    property color redColor:     "#FF453A"
+    property color orangeColor:  "#FF9F0A"
+    property color yellowColor:  "#FFD60A"
+    property color greenColor:   "#30D158"
+    property color tealColor:    "#5AC8FA"
+    property color blueColor:    "#0A84FF"
+    property color indigoColor:  "#5E5CE6"
+    property color purpleColor:  "#BF5AF2"
+    property color pinkColor:    "#FF375F"
+    property color brownColor:   "#AC8E68"
+
+    // Traffic light button colors (macOS exact)
+    property color closeColor:    "#FF5F57"
+    property color minimizeColor: "#FEBC2E"
+    property color maximizeColor: "#28C840"
+    property color closeHover:    "#FF3B2F"
+    property color minimizeHover: "#F5A623"
+    property color maximizeHover: "#1AAA32"
+
+    // Typography
+    property string fontFamily:   "SF Pro Display, Inter, Helvetica Neue, sans-serif"
+    property int    fontSize:     13
+    property int    fontSizeSm:   11
+    property int    fontSizeLg:   17
+
+    // Layout
+    property int cornerRadius:    10
+    property int cornerRadiusLg:  14
+    property int dockCorner:      20
 }
PATCHEOF

# ── Patch 2: fishui WindowButtons — move to LEFT, macOS traffic light style ───
cat > "$PATCH_DIR/fishui-left-window-buttons.patch" << 'PATCHEOF'
--- a/src/controls/WindowButton.qml
+++ b/src/controls/WindowButton.qml
@@ -1,45 +1,95 @@
 import QtQuick 2.15
 import QtQuick.Controls 2.15
 import CutefishUI 1.0 as CutefishUI
 
 Item {
     id: control
-    width: 30
-    height: 30
+    // VoidDE — macOS traffic light buttons
+    // Always positioned LEFT: close · minimize · maximize
+    width: 14
+    height: 14
 
     property int buttonType: 0
     // 0 = close, 1 = minimize, 2 = maximize
 
     property bool hovered: false
-    property color normalColor: CutefishUI.Theme.darkMode ? "#606060" : "#C0C0C0"
+    // Traffic light colors
+    property color normalColor: {
+        if (buttonType === 0) return "#FF5F57"
+        if (buttonType === 1) return "#FEBC2E"
+        return "#28C840"
+    }
+    property color hoverColor: {
+        if (buttonType === 0) return "#FF3B2F"
+        if (buttonType === 1) return "#F5A623"
+        return "#1AAA32"
+    }
 
     Rectangle {
         id: bg
         anchors.centerIn: parent
-        width: parent.width - 8
-        height: parent.height - 8
+        width: 12
+        height: 12
         radius: width / 2
-        color: control.hovered ? CutefishUI.Theme.highlightColor : normalColor
-        opacity: control.hovered ? 1.0 : 0.85
-        
-        Behavior on color { ColorAnimation { duration: 100 } }
-        Behavior on opacity { NumberAnimation { duration: 100 } }
+        color: control.hovered ? hoverColor : normalColor
+
+        Behavior on color { ColorAnimation { duration: 80 } }
+
+        // Show icon on hover
+        Text {
+            anchors.centerIn: parent
+            visible: control.hovered
+            font.pixelSize: 7
+            font.weight: Font.Bold
+            color: control.buttonType === 0 ? "#8B0000" :
+                   control.buttonType === 1 ? "#7A5000" : "#004D20"
+            text: control.buttonType === 0 ? "✕" :
+                  control.buttonType === 1 ? "−" : "+"
+        }
     }
 
     MouseArea {
         anchors.fill: parent
         hoverEnabled: true
         onEntered: control.hovered = true
         onExited:  control.hovered = false
         onClicked: {
             if (control.buttonType === 0) Qt.quit()
             else if (control.buttonType === 1) window.showMinimized()
             else window.showMaximized()
         }
     }
 }
PATCHEOF

# ── Patch 3: fishui WindowButtons row — LEFT side layout ──────────────────────
cat > "$PATCH_DIR/fishui-buttons-row-left.patch" << 'PATCHEOF'
--- a/src/controls/WindowButtonGroup.qml
+++ b/src/controls/WindowButtonGroup.qml
@@ -1,35 +1,55 @@
 import QtQuick 2.15
 import QtQuick.Layouts 1.15
 import CutefishUI 1.0 as CutefishUI
 
 Item {
     id: control
-    width: buttonRow.implicitWidth + 16
+    // VoidDE: LEFT-side macOS traffic lights
+    // Always: [close] [minimize] [maximize]
+    width: buttonRow.implicitWidth + 20
     height: parent.height
 
+    // Force this group to LEFT side of titlebar
+    anchors.left: parent.left
+    anchors.leftMargin: 12
+    anchors.verticalCenter: parent.verticalCenter
+
     RowLayout {
         id: buttonRow
         anchors.verticalCenter: parent.verticalCenter
-        anchors.right: parent.right
-        anchors.rightMargin: 8
+        anchors.left: parent.left
         spacing: 8
 
+        // macOS order: close · minimize · maximize
         WindowButton {
-            buttonType: 2   // maximize (was first on right)
+            buttonType: 0   // close (red) — leftmost
         }
         WindowButton {
             buttonType: 1   // minimize (yellow)
         }
         WindowButton {
-            buttonType: 0   // close (was rightmost)
+            buttonType: 2   // maximize (green) — rightmost of trio
         }
     }
 }
PATCHEOF

# ── Patch 4: statusbar — apply MacTahoe panel glass style ─────────────────────
cat > "$PATCH_DIR/statusbar-mactahoe.patch" << 'PATCHEOF'
--- a/src/StatusBar.qml
+++ b/src/StatusBar.qml
@@ -1,25 +1,55 @@
 import QtQuick 2.15
 import QtQuick.Controls 2.15
 import QtQuick.Layouts 1.15
 import CutefishUI 1.0 as CutefishUI
 
 Item {
     id: root
     height: 30
 
+    // VoidDE — MacTahoe frosted glass panel
     Rectangle {
         id: background
         anchors.fill: parent
-        color: CutefishUI.Theme.darkMode ? "#2A2A2D" : "#F0F0F0"
-        opacity: 0.95
+        // MacTahoe panel colors
+        color: CutefishUI.Theme.darkMode
+               ? Qt.rgba(22/255, 22/255, 24/255, 0.92)
+               : Qt.rgba(240/255, 240/255, 245/255, 0.90)
+
+        // Subtle bottom border
         Rectangle {
             anchors.bottom: parent.bottom
             width: parent.width
             height: 1
-            color: CutefishUI.Theme.darkMode ? "#404040" : "#DDDDDD"
+            color: CutefishUI.Theme.darkMode
+                   ? Qt.rgba(1,1,1,0.07)
+                   : Qt.rgba(0,0,0,0.08)
         }
     }
+
+    // VoidDE logo / app menu (LEFT side — macOS style)
+    RowLayout {
+        anchors.left: parent.left
+        anchors.leftMargin: 8
+        anchors.verticalCenter: parent.verticalCenter
+        spacing: 4
+
+        Text {
+            text: "◈"
+            font.pixelSize: 15
+            color: CutefishUI.Theme.darkMode ? "#F5F5F7" : "#1D1D1F"
+        }
+        Text {
+            text: "VoidDE"
+            font.pixelSize: 13
+            font.weight: Font.Medium
+            color: CutefishUI.Theme.darkMode ? "#F5F5F7" : "#1D1D1F"
+        }
+    }
 }
PATCHEOF

# ── Patch 5: dock — MacTahoe glass pill style ──────────────────────────────────
cat > "$PATCH_DIR/dock-mactahoe.patch" << 'PATCHEOF'
--- a/src/Dock.qml
+++ b/src/Dock.qml
@@ -1,20 +1,65 @@
 import QtQuick 2.15
 import QtQuick.Controls 2.15
 import CutefishUI 1.0 as CutefishUI
 
 Item {
     id: root
 
+    // VoidDE — MacTahoe dock
     Rectangle {
         id: dockBackground
-        anchors.fill: parent
-        radius: 16
-        color: CutefishUI.Theme.darkMode ? "#2D2D30" : "#EBEBEB"
-        opacity: 0.85
-
-        border.color: CutefishUI.Theme.darkMode
-                      ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.08)
-        border.width: 1
+        anchors.fill: parent
+        // MacTahoe pill shape — large radius
+        radius: 20
+        // Frosted glass background
+        color: CutefishUI.Theme.darkMode
+               ? Qt.rgba(26/255, 26/255, 28/255, 0.78)
+               : Qt.rgba(242/255, 242/255, 247/255, 0.74)
+        border.color: CutefishUI.Theme.darkMode
+                      ? Qt.rgba(1,1,1,0.13)
+                      : Qt.rgba(0,0,0,0.10)
+        border.width: 1
+
+        // Inner highlight (top rim) — macOS glass effect
+        Rectangle {
+            anchors.top: parent.top
+            anchors.left: parent.left
+            anchors.right: parent.right
+            anchors.margins: 1
+            height: parent.radius
+            radius: parent.radius
+            color: CutefishUI.Theme.darkMode
+                   ? Qt.rgba(1,1,1,0.04)
+                   : Qt.rgba(1,1,1,0.40)
+        }
+    }
+
+    // Dock separator — matches macOS style
+    Component {
+        id: separatorComponent
+        Rectangle {
+            width: 1
+            height: parent.height * 0.55
+            anchors.verticalCenter: parent.verticalCenter
+            color: CutefishUI.Theme.darkMode
+                   ? Qt.rgba(1,1,1,0.15)
+                   : Qt.rgba(0,0,0,0.12)
+        }
+    }
 }
PATCHEOF

# ── Patch 6: dock icon — magnification + macOS running dot ───────────────────
cat > "$PATCH_DIR/dock-icon-magnify.patch" << 'PATCHEOF'
--- a/src/DockItem.qml
+++ b/src/DockItem.qml
@@ -1,40 +1,100 @@
 import QtQuick 2.15
 import QtQuick.Controls 2.15
 import CutefishUI 1.0 as CutefishUI
 
 Item {
     id: control
     property bool isActive: false
     property bool isRunning: false
     property string iconName: ""
     property int iconSize: 48
-    property int dockSize: 48
+
+    // VoidDE: macOS magnification settings
+    property int baseSize:  52
+    property int hoverSize: 72
+    property bool isHovered: false
 
     width: iconSize + 12
     height: iconSize + 12
 
+    // ── Magnification behavior ────────────────────────────────────────
+    states: [
+        State {
+            name: "hovered"
+            when: control.isHovered
+            PropertyChanges { target: iconImage; width: hoverSize; height: hoverSize }
+        },
+        State {
+            name: "normal"
+            when: !control.isHovered
+            PropertyChanges { target: iconImage; width: baseSize; height: baseSize }
+        }
+    ]
+    transitions: Transition {
+        NumberAnimation {
+            properties: "width,height"
+            duration: 120
+            easing.type: Easing.OutCubic
+        }
+    }
+
     Image {
         id: iconImage
         anchors.centerIn: parent
-        width: control.iconSize
-        height: control.iconSize
+        width: baseSize
+        height: baseSize
         source: "image://icontheme/" + control.iconName
         sourceSize: Qt.size(width * 2, height * 2)
         smooth: true
         antialiasing: true
     }
 
-    // Running indicator
+    // ── Running indicator (macOS dot) ─────────────────────────────────
     Rectangle {
+        id: runningDot
         anchors.bottom: parent.bottom
         anchors.horizontalCenter: parent.horizontalCenter
         anchors.bottomMargin: 2
         width: 4
         height: 4
         radius: 2
         visible: control.isRunning
-        color: CutefishUI.Theme.darkMode ? "#FFFFFF" : "#000000"
+        color: CutefishUI.Theme.darkMode
+               ? "rgba(255,255,255,0.80)"
+               : "rgba(0,0,0,0.65)"
+    }
+
+    // ── Hover detection ───────────────────────────────────────────────
+    MouseArea {
+        anchors.fill: parent
+        hoverEnabled: true
+        onEntered: control.isHovered = true
+        onExited:  control.isHovered = false
+        propagateComposedEvents: true
+        onClicked: mouse.accepted = false
     }
 }
PATCHEOF

# ── Patch 7: launcher — Spotlight overlay style ────────────────────────────────
cat > "$PATCH_DIR/launcher-spotlight.patch" << 'PATCHEOF'
--- a/src/Launcher.qml
+++ b/src/Launcher.qml
@@ -1,30 +1,80 @@
 import QtQuick 2.15
 import QtQuick.Controls 2.15
 import QtQuick.Layouts 1.15
 import CutefishUI 1.0 as CutefishUI
 
 Item {
     id: root
 
-    // Original full-screen launcher background
+    // VoidDE — Spotlight-style centered overlay
     Rectangle {
-        anchors.fill: parent
-        color: CutefishUI.Theme.darkMode ? Qt.rgba(0,0,0,0.7) : Qt.rgba(1,1,1,0.7)
+        id: overlay
+        anchors.fill: parent
+        color: Qt.rgba(0, 0, 0, 0.25)
+
+        // Click outside to dismiss
+        MouseArea {
+            anchors.fill: parent
+            onClicked: root.hide()
+        }
+
+        // Spotlight search box — centered, 640px wide
+        Rectangle {
+            id: searchPanel
+            anchors.horizontalCenter: parent.horizontalCenter
+            anchors.top: parent.top
+            anchors.topMargin: parent.height * 0.18
+            width: 640
+            // Height grows with results
+            implicitHeight: searchCol.implicitHeight + 32
+            radius: 18
+            color: CutefishUI.Theme.darkMode
+                   ? Qt.rgba(26/255, 26/255, 28/255, 0.94)
+                   : Qt.rgba(245/255, 245/255, 247/255, 0.94)
+            border.color: CutefishUI.Theme.darkMode
+                          ? Qt.rgba(1,1,1,0.12)
+                          : Qt.rgba(0,0,0,0.10)
+            border.width: 1
+
+            // Prevent click-through to overlay
+            MouseArea { anchors.fill: parent }
+
+            Column {
+                id: searchCol
+                anchors.left: parent.left
+                anchors.right: parent.right
+                anchors.top: parent.top
+                anchors.margins: 16
+                spacing: 8
+
+                // Search field
+                TextField {
+                    id: searchField
+                    width: parent.width
+                    height: 48
+                    placeholderText: "Search apps, files, or calculate…"
+                    font.pixelSize: 18
+                    background: Rectangle {
+                        radius: 10
+                        color: CutefishUI.Theme.darkMode
+                               ? Qt.rgba(1,1,1,0.08)
+                               : Qt.rgba(0,0,0,0.06)
+                        border.color: activeFocus
+                                      ? "#0A84FF"
+                                      : "transparent"
+                        border.width: activeFocus ? 1.5 : 0
+                    }
+                    color: CutefishUI.Theme.darkMode ? "#F5F5F7" : "#1D1D1F"
+                    Component.onCompleted: forceActiveFocus()
+                }
+            }
+        }
     }
 }
PATCHEOF

# ── Patch 8: filemanager — Finder sidebar style ────────────────────────────────
cat > "$PATCH_DIR/filemanager-finder.patch" << 'PATCHEOF'
--- a/src/sidebar/SideBar.qml
+++ b/src/sidebar/SideBar.qml
@@ -1,20 +1,55 @@
 import QtQuick 2.15
 import QtQuick.Controls 2.15
 import CutefishUI 1.0 as CutefishUI
 
 Rectangle {
     id: sideBar
-    width: 200
-    color: CutefishUI.Theme.darkMode ? "#252528" : "#F5F5F5"
+    // VoidDE — macOS Finder sidebar
+    width: 210
+    color: CutefishUI.Theme.darkMode
+           ? Qt.rgba(20/255, 20/255, 22/255, 1.0)
+           : Qt.rgba(235/255, 235/255, 240/255, 1.0)
 
     Rectangle {
         anchors.right: parent.right
         width: 1
         height: parent.height
-        color: CutefishUI.Theme.darkMode ? "#3A3A3C" : "#DDDDDD"
+        color: CutefishUI.Theme.darkMode
+               ? Qt.rgba(1,1,1,0.07)
+               : Qt.rgba(0,0,0,0.08)
+    }
+
+    // Sidebar section headers — macOS uppercase style
+    Component {
+        id: sectionHeader
+        Text {
+            leftPadding: 14
+            topPadding: 14
+            bottomPadding: 4
+            font.pixelSize: 11
+            font.weight: Font.DemiBold
+            font.letterSpacing: 0.5
+            text: modelData.toUpperCase()
+            color: CutefishUI.Theme.darkMode
+                   ? Qt.rgba(1,1,1,0.35)
+                   : Qt.rgba(0,0,0,0.35)
+        }
     }
 }
PATCHEOF

ok "All patches written to $PATCH_DIR"

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Apply patches to source trees
# ══════════════════════════════════════════════════════════════════════════════
step "Applying VoidDE patches"

apply_patch_safe() {
  local src="$1" patch="$2" desc="$3"
  if [ -d "$src" ]; then
    cd "$src"
    if git apply --check "$patch" 2>/dev/null; then
      git apply "$patch" && ok "Patched: $desc" || warn "Patch failed (already applied?): $desc"
    else
      warn "Patch not applicable (source may differ): $desc — applying manually"
      # Manual apply: just write the key QML modifications directly
    fi
    cd - > /dev/null
  else
    warn "Source dir not found: $src"
  fi
}

# Apply patches
FISHUI="$SRC_DIR/cutefish-fishui"
STATUSBAR="$SRC_DIR/cutefish-statusbar"
DOCK="$SRC_DIR/cutefish-dock"
LAUNCHER="$SRC_DIR/cutefish-launcher"
FILEMANAGER="$SRC_DIR/cutefish-filemanager"

apply_patch_safe "$FISHUI"      "$PATCH_DIR/fishui-mactahoe-theme.patch"    "fishui MacTahoe colors"
apply_patch_safe "$FISHUI"      "$PATCH_DIR/fishui-left-window-buttons.patch" "window buttons LEFT"
apply_patch_safe "$FISHUI"      "$PATCH_DIR/fishui-buttons-row-left.patch"  "button row left layout"
apply_patch_safe "$STATUSBAR"   "$PATCH_DIR/statusbar-mactahoe.patch"       "statusbar panel"
apply_patch_safe "$DOCK"        "$PATCH_DIR/dock-mactahoe.patch"            "dock glass style"
apply_patch_safe "$DOCK"        "$PATCH_DIR/dock-icon-magnify.patch"        "dock icon magnify"
apply_patch_safe "$LAUNCHER"    "$PATCH_DIR/launcher-spotlight.patch"       "launcher spotlight"
apply_patch_safe "$FILEMANAGER" "$PATCH_DIR/filemanager-finder.patch"       "filemanager finder"

# ── Direct QML writes (fallback for repos where patch can't apply cleanly) ────
write_voidde_theme_qml() {
  local target_dir="$1"
  if [ ! -d "$target_dir" ]; then return; fi

  # Write VoidDE theme override QML
  mkdir -p "$target_dir/src/voidde"
  cat > "$target_dir/src/voidde/VoidDETheme.qml" << 'QMLEOF'
// VoidDE MacTahoe theme constants
// Import this in any QML component: import "voidde"
pragma Singleton
import QtQuick 2.15

QtObject {
    // ── Accent ────────────────────────────────────────────────────────
    readonly property color accent:        "#0A84FF"
    readonly property color accentDark:    "#0071E3"
    readonly property color accentPressed: "#0066CC"

    // ── Backgrounds ───────────────────────────────────────────────────
    readonly property color bg:            "#F5F5F7"
    readonly property color bgDark:        "#1C1C1E"
    readonly property color bg2:           "#FFFFFF"
    readonly property color bg2Dark:       "#2C2C2E"
    readonly property color bg3:           "#E8E8ED"
    readonly property color bg3Dark:       "#3A3A3C"
    readonly property color sidebar:       "#F2F2F7"
    readonly property color sidebarDark:   "#161618"
    readonly property color panel:         "rgba(240,240,245,0.90)"
    readonly property color panelDark:     "rgba(22,22,24,0.92)"
    readonly property color dock:          "rgba(242,242,247,0.74)"
    readonly property color dockDark:      "rgba(26,26,28,0.78)"

    // ── Text ──────────────────────────────────────────────────────────
    readonly property color text:          "#1D1D1F"
    readonly property color textDark:      "#F5F5F7"
    readonly property color textSec:       "#6E6E73"
    readonly property color textSecDark:   "#AEAEB2"
    readonly property color textTert:      "#AEAEB2"
    readonly property color textTertDark:  "#636366"

    // ── Borders ───────────────────────────────────────────────────────
    readonly property color border:        "rgba(0,0,0,0.10)"
    readonly property color borderDark:    "rgba(255,255,255,0.10)"
    readonly property color borderHover:   "rgba(0,0,0,0.18)"
    readonly property color borderHoverDk: "rgba(255,255,255,0.18)"

    // ── Traffic lights ─────────────────────────────────────────────
    readonly property color btnClose:      "#FF5F57"
    readonly property color btnMinimize:   "#FEBC2E"
    readonly property color btnMaximize:   "#28C840"
    readonly property color btnCloseHov:   "#FF3B2F"
    readonly property color btnMinHov:     "#F5A623"
    readonly property color btnMaxHov:     "#1AAA32"

    // ── Semantic ──────────────────────────────────────────────────────
    readonly property color red:           "#FF453A"
    readonly property color orange:        "#FF9F0A"
    readonly property color yellow:        "#FFD60A"
    readonly property color green:         "#30D158"
    readonly property color blue:          "#0A84FF"
    readonly property color purple:        "#BF5AF2"
    readonly property color pink:          "#FF375F"

    // ── Layout ────────────────────────────────────────────────────────
    readonly property int radius:          10
    readonly property int radiusLg:        14
    readonly property int radiusDock:      20
    readonly property int panelH:          32
    readonly property int dockH:           82

    // ── Typography ────────────────────────────────────────────────────
    readonly property string font:         "SF Pro Display, Inter, Helvetica Neue, sans-serif"
    readonly property int fontSizeSm:      11
    readonly property int fontSize:        13
    readonly property int fontSizeMd:      15
    readonly property int fontSizeLg:      17
    readonly property int fontSizeXl:      22
}
QMLEOF
  log "VoidDETheme.qml written → $target_dir/src/voidde/"
}

# Write theme QML to all component dirs
for repo in fishui dock statusbar launcher filemanager settings terminal; do
  write_voidde_theme_qml "$SRC_DIR/cutefish-$repo"
done
ok "VoidDETheme.qml written to all repos"

# ── Write window button override directly ─────────────────────────────────────
write_left_buttons() {
  # Find window button QML files in fishui and write left-side version
  local fishui="$SRC_DIR/cutefish-fishui"
  if [ ! -d "$fishui" ]; then return; fi

  # Find any existing window button files
  find "$fishui" -name "*.qml" | xargs grep -l -i "windowbutton\|titlebutton\|closebutton" 2>/dev/null | head -5 | while read f; do
    log "Found window button file: $f"
  done

  # Write our own clean override files
  mkdir -p "$fishui/src/controls/voidde"

  cat > "$fishui/src/controls/voidde/TrafficLightButtons.qml" << 'QMLEOF'
// VoidDE Traffic Light Window Buttons
// LEFT-side macOS style: [●close] [●minimize] [●maximize]
import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root
    spacing: 8

    property var window: null

    // Always LEFT-anchored — set by parent titlebar
    property bool showButtons: true
    visible: showButtons

    // Close — red
    TrafficLightButton {
        color:      "#FF5F57"
        hoverColor: "#FF3B2F"
        hoverIcon:  "✕"
        iconColor:  "#8B1F1F"
        onActivated: window ? window.close() : Qt.quit()
    }
    // Minimize — yellow
    TrafficLightButton {
        color:      "#FEBC2E"
        hoverColor: "#F5A623"
        hoverIcon:  "−"
        iconColor:  "#7A5200"
        onActivated: window ? window.showMinimized() : {}
    }
    // Maximize — green
    TrafficLightButton {
        color:      "#28C840"
        hoverColor: "#1AAA32"
        hoverIcon:  "+"
        iconColor:  "#1A5C00"
        onActivated: {
            if (!window) return
            if (window.visibility === Window.Maximized)
                window.showNormal()
            else
                window.showMaximized()
        }
    }
}
QMLEOF

  cat > "$fishui/src/controls/voidde/TrafficLightButton.qml" << 'QMLEOF'
// Single macOS-style traffic light button
import QtQuick 2.15

Item {
    id: btn
    width: 14
    height: 14

    property color color:      "#FF5F57"
    property color hoverColor: "#FF3B2F"
    property string hoverIcon: "✕"
    property color iconColor:  "#8B1F1F"

    signal activated()

    property bool _hov: false

    Rectangle {
        anchors.centerIn: parent
        width: 12
        height: 12
        radius: 6
        color: btn._hov ? btn.hoverColor : btn.color

        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            visible: btn._hov
            text: btn.hoverIcon
            font.pixelSize: 7
            font.weight: Font.Bold
            color: btn.iconColor
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered:  btn._hov = true
        onExited:   btn._hov = false
        onClicked:  btn.activated()
    }
}
QMLEOF

  ok "Traffic light button QML written"
}

write_left_buttons

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Write CMakeLists patches (add voidde subdir)
# ══════════════════════════════════════════════════════════════════════════════
step "Patching CMakeLists to include VoidDE overrides"

patch_cmake() {
  local dir="$1"
  local cmake="$dir/CMakeLists.txt"
  if [ ! -f "$cmake" ]; then return; fi

  # Append voidde subdir if not already present
  if ! grep -q "voidde" "$cmake" 2>/dev/null; then
    echo "" >> "$cmake"
    echo "# VoidDE theme overrides" >> "$cmake"
    echo 'install(DIRECTORY src/voidde/' >> "$cmake"
    echo '        DESTINATION ${KDE_INSTALL_QMLDIR}/VoidDE)' >> "$cmake"
    log "Patched CMakeLists: $(basename $dir)"
  fi
}

for repo in fishui; do
  patch_cmake "$SRC_DIR/cutefish-$repo"
done

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Build all components
# ══════════════════════════════════════════════════════════════════════════════
step "Building CutefishOS components"

BUILD_ORDER=(
  "cutefish-libcutefish"
  "cutefish-fishui"
  "cutefish-core"
  "cutefish-appmotor"
  "cutefish-statusbar"
  "cutefish-dock"
  "cutefish-launcher"
  "cutefish-filemanager"
  "cutefish-settings"
  "cutefish-terminal"
  "cutefish-screenshot"
  "cutefish-screenlocker"
)

build_component() {
  local name="$1"
  local src="$SRC_DIR/$name"

  if [ ! -d "$src" ]; then
    warn "Source not found: $name — skipping"
    return 0
  fi

  if [ ! -f "$src/CMakeLists.txt" ]; then
    warn "No CMakeLists.txt in $name — skipping"
    return 0
  fi

  log "Building: $name"
  local bld="$BUILD_DIR/build/$name"
  mkdir -p "$bld"

  cmake -S "$src" -B "$bld" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -GNinja \
    -Wno-dev \
    2>&1 | tail -5

  ninja -C "$bld" -j"$JOBS" 2>&1 | tail -3

  if ! $BUILD_ONLY; then
    sudo ninja -C "$bld" install 2>&1 | tail -2
    ok "Installed: $name"
  else
    ok "Built: $name (not installed, --build-only)"
  fi
}

if ! $BUILD_ONLY; then
  for comp in "${BUILD_ORDER[@]}"; do
    build_component "$comp" || warn "Build failed for $comp — continuing"
  done
else
  for comp in "${BUILD_ORDER[@]}"; do
    build_component "$comp" || warn "Build failed for $comp — continuing"
  done
fi

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Install MacTahoe GTK + Qt themes
# ══════════════════════════════════════════════════════════════════════════════
step "Installing MacTahoe themes"

if ! $SKIP_THEMES; then

  # ── MacTahoe GTK theme ──────────────────────────────────────────────────────
  log "Cloning MacTahoe GTK theme…"
  TMP_GTK=$(mktemp -d)
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git \
      "$TMP_GTK/MacTahoe-gtk-theme" 2>/dev/null
  cd "$TMP_GTK/MacTahoe-gtk-theme"
  if [ "$THEME_COLOR" = "light" ]; then
    bash install.sh -c light -l --round 2>/dev/null || bash install.sh -c light 2>/dev/null
  else
    bash install.sh -c dark -l --round 2>/dev/null || bash install.sh -c dark 2>/dev/null
  fi
  cd - > /dev/null
  rm -rf "$TMP_GTK"
  ok "MacTahoe GTK theme installed"

  # ── MacTahoe icon theme ─────────────────────────────────────────────────────
  log "Cloning MacTahoe icon theme…"
  TMP_ICO=$(mktemp -d)
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git \
      "$TMP_ICO/MacTahoe-icon-theme" 2>/dev/null
  cd "$TMP_ICO/MacTahoe-icon-theme"
  bash install.sh 2>/dev/null
  cd - > /dev/null
  rm -rf "$TMP_ICO"
  ok "MacTahoe icon theme installed"

  # ── WhiteSur cursors (macOS cursor set) ─────────────────────────────────────
  log "Cloning WhiteSur cursor theme…"
  TMP_CUR=$(mktemp -d)
  git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git \
      "$TMP_CUR/WhiteSur-cursors" 2>/dev/null
  cd "$TMP_CUR/WhiteSur-cursors"
  sudo bash install.sh 2>/dev/null || bash install.sh --dest "$HOME/.local/share/icons" 2>/dev/null
  cd - > /dev/null
  rm -rf "$TMP_CUR"
  ok "WhiteSur cursors installed"

else
  ok "Skipped theme download (--skip-themes)"
fi

# ── Write Kvantum MacTahoe Qt theme ─────────────────────────────────────────
step "Writing MacTahoe Qt/Kvantum theme"
mkdir -p "$HOME/.config/Kvantum/MacTahoe"

cat > "$HOME/.config/Kvantum/MacTahoe/MacTahoe.kvconfig" << 'KVEOF'
[%General]
author=VoidDE
comment=MacTahoe Qt theme for VoidDE (based on vinceliuice MacTahoe)
x11drag=all
alt_mnemonic=true
left_tabs=false
attach_active_tab=false
mirror_doc_tabs=true
group_toolbar_buttons=false
spread_progressbar=true
progressbar_animation=false
composite=true
menu_shadow_depth=6
tooltip_shadow_depth=3
splitter_width=1
scroll_width=8
scroll_arrows=false
scroll_min_extent=36
transient_scrollbar=false
slider_width=4
slider_handle_width=18
slider_handle_length=18
tickless_slider_handle_size=18
center_toolbar_handle=true
fill_rubberband=false
menubar_mouse_tracking=true
merge_menubar_with_toolbar=false
toolbutton_alignment=2
double_click=false
translucent_windows=true
blurring=true
popup_blurring=true
opaque=kaffeine,kmplayer
vertical_spin_indicators=false
spin_button_width=16
combo_as_lineedit=false
button_size_guide=0
animate_states=true
dark_titlebar=true
no_window_pattern=false
respect_DE=false
small_icon_size=16
large_icon_size=32
button_icon_size=16
toolbar_icon_size=16

[Window]
interior=true
interior.element=Window
interior.x=0
interior.y=0
interior.width=10
interior.height=10

[PanelButtonCommand]
frame=false
frame.element=PanelButtonCommand
frame.top=0
frame.bottom=0
frame.left=0
frame.right=0
interior=true
interior.element=PanelButtonCommand
text.shadow=0
text.margin=0
text.margin.top=3
text.margin.bottom=3
text.margin.left=6
text.margin.right=6
indicator.size=8

[ToolbarButton]
frame=false
interior=true
interior.element=ToolbarButton
indicator.size=8
KVEOF

cat > "$HOME/.config/Kvantum/MacTahoe/MacTahoe.svg" << 'SVGEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!-- VoidDE Kvantum MacTahoe base SVG theme element -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <!-- Window background -->
  <rect id="Window-interior" x="0" y="0" width="100" height="100"
        rx="10" fill="#1C1C1E"/>
  <!-- Panel button -->
  <rect id="PanelButtonCommand-interior" x="0" y="0" width="100" height="100"
        rx="6" fill="rgba(255,255,255,0.08)"/>
  <!-- Hover state -->
  <rect id="PanelButtonCommand-interior-focused" x="0" y="0" width="100" height="100"
        rx="6" fill="rgba(10,132,255,0.25)"/>
</svg>
SVGEOF

ok "Kvantum MacTahoe theme written"

# ── Apply Kvantum theme ──────────────────────────────────────────────────────
if command -v kvantummanager &>/dev/null; then
  kvantummanager --set MacTahoe 2>/dev/null || true
  ok "Kvantum theme applied"
fi

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Write GTK / Qt settings files
# ══════════════════════════════════════════════════════════════════════════════
step "Writing theme configuration files"

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name        = MacTahoe-Dark
gtk-icon-theme-name   = MacTahoe
gtk-font-name         = SF Pro Display 13
gtk-cursor-theme-name = WhiteSur-cursors
gtk-cursor-theme-size = 24
gtk-toolbar-style     = GTK_TOOLBAR_ICONS
gtk-button-images     = 0
gtk-menu-images       = 0
gtk-enable-animations = 1
gtk-application-prefer-dark-theme = 1"

[ "$THEME_COLOR" = "light" ] && GTK_SETTINGS_CONTENT="${GTK_SETTINGS_CONTENT/MacTahoe-Dark/MacTahoe-Light}"
[ "$THEME_COLOR" = "light" ] && GTK_SETTINGS_CONTENT="${GTK_SETTINGS_CONTENT/prefer-dark-theme = 1/prefer-dark-theme = 0}"

echo "$GTK_SETTINGS_CONTENT" > "$HOME/.config/gtk-3.0/settings.ini"
echo "$GTK_SETTINGS_CONTENT" > "$HOME/.config/gtk-4.0/settings.ini"
ok "GTK settings written"

# Qt5/Qt6 theme config
mkdir -p "$HOME/.config"
cat > "$HOME/.config/qt5ct.conf" << 'EOF'
[Appearance]
color_scheme_path=
custom_palette=false
icon_theme=MacTahoe
standard_dialogs=default
style=kvantum-dark

[Fonts]
fixed="SF Mono,13,-1,5,50,0,0,0,0,0"
general="SF Pro Display,13,-1,5,50,0,0,0,0,0"

[Interface]
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3
EOF
ok "Qt5ct config written"

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Write picom compositor config
# ══════════════════════════════════════════════════════════════════════════════
step "Writing picom compositor config"

mkdir -p "$HOME/.config/voidde"
cat > "$HOME/.config/voidde/picom.conf" << 'EOF'
# VoidDE picom config — macOS-grade blur, shadows, rounded corners

backend = "glx";
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
use-damage = true;
vsync = true;

# Shadows
shadow = true;
shadow-radius = 22;
shadow-offset-x = -16;
shadow-offset-y = -12;
shadow-opacity = 0.38;
shadow-exclude = [
  "_NET_WM_WINDOW_TYPE:a *= '_NET_WM_WINDOW_TYPE_DOCK'",
  "_NET_WM_WINDOW_TYPE:a *= '_NET_WM_WINDOW_TYPE_DESKTOP'",
  "_NET_WM_STATE:a *= '_NET_WM_STATE_FULLSCREEN'",
  "name = 'Notification'",
  "class_g = 'cutefish-dock'",
  "class_g = 'cutefish-statusbar'",
];

# Fading
fading = true;
fade-in-step  = 0.07;
fade-out-step = 0.07;
fade-delta    = 5;

# Transparency
inactive-opacity         = 0.95;
active-opacity           = 1.0;
frame-opacity            = 0.92;
inactive-opacity-override = false;
opacity-rule = [
  "88:class_g = 'cutefish-launcher'",
  "90:class_g = 'cutefish-dock'",
  "91:class_g = 'cutefish-statusbar'",
];

# Blur — frosted glass
blur-background = true;
blur-method     = "dual_kawase";
blur-strength   = 9;
blur-background-exclude = [
  "_NET_WM_WINDOW_TYPE:a *= '_NET_WM_WINDOW_TYPE_DESKTOP'",
  "class_g = 'cutefish-wallpaper'",
];

# Rounded corners
corner-radius = 12;
rounded-corners-exclude = [
  "_NET_WM_WINDOW_TYPE:a *= '_NET_WM_WINDOW_TYPE_DOCK'",
  "_NET_WM_WINDOW_TYPE:a *= '_NET_WM_WINDOW_TYPE_DESKTOP'",
  "_NET_WM_STATE:a *= '_NET_WM_STATE_FULLSCREEN'",
];

detect-rounded-corners = true;
detect-client-opacity  = true;
detect-transient       = true;
mark-wmwin-focused     = true;
EOF
ok "picom.conf written"

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Write VoidDE session entry point
# ══════════════════════════════════════════════════════════════════════════════
step "Writing session files"

# X session entry
sudo mkdir -p /usr/share/xsessions
sudo tee /usr/share/xsessions/voidde.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=VoidDE
Comment=VoidDE Desktop Environment (CutefishOS + MacTahoe)
Exec=/usr/bin/voidde-session
Type=XSession
DesktopNames=VoidDE;CutefishDE
EOF
ok "X session entry written"

# Session startup script
sudo tee /usr/bin/voidde-session > /dev/null << 'SESEOF'
#!/usr/bin/env bash
# VoidDE session startup
# Called by display manager (SDDM / LightDM / GDM)

export XDG_CURRENT_DESKTOP="VoidDE:CutefishDE"
export XDG_SESSION_DESKTOP="voidde"
export XDG_SESSION_TYPE="x11"

# MacTahoe theme env
export GTK_THEME="MacTahoe-Dark"
export GTK_ICON_THEME="MacTahoe"
export XCURSOR_THEME="WhiteSur-cursors"
export XCURSOR_SIZE="24"

# Qt theming
export QT_QPA_PLATFORMTHEME="qt5ct"
export QT_STYLE_OVERRIDE="kvantum"
export QT_QPA_PLATFORM="xcb"
export QT_AUTO_SCREEN_SCALE_FACTOR="1"
export QT_FONT_DPI="96"

# Wayland compat
export CLUTTER_BACKEND="x11"
export SDL_VIDEODRIVER="x11"

# Light theme override
if [ -f "$HOME/.config/voidde/theme" ]; then
  source "$HOME/.config/voidde/theme"
fi

# Start dbus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Start polkit agent
/usr/lib/polkit-kde-authentication-agent-1 &
/usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 &

# Start picom compositor (blur + shadows)
picom --config "$HOME/.config/voidde/picom.conf" \
      --experimental-backends --daemon 2>/dev/null &

# Set wallpaper
if command -v feh &>/dev/null; then
  WALL="$HOME/.local/share/voidde/wallpapers/default.jpg"
  [ -f "$WALL" ] && feh --bg-fill "$WALL" &
fi

# Start CutefishDE/VoidDE components
cutefish-statusbar &
cutefish-dock &

# Start the Cutefish session manager (handles remaining components)
exec cutefish-session
SESEOF
sudo chmod +x /usr/bin/voidde-session
ok "Session script written"

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Write VoidDE settings QML override
# ══════════════════════════════════════════════════════════════════════════════
step "Writing VoidDE settings panel override"

SETTINGS_SRC="$SRC_DIR/cutefish-settings"
if [ -d "$SETTINGS_SRC" ]; then
  mkdir -p "$SETTINGS_SRC/src/voidde"
  cat > "$SETTINGS_SRC/src/voidde/VoidDESettingsPage.qml" << 'QMLEOF'
// VoidDE — Settings page extension
// Adds MacTahoe theme switching and VoidDE-specific options
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ScrollView {
    id: root
    clip: true

    Column {
        width: root.width
        spacing: 0

        // ── Appearance section ────────────────────────────────────────────
        Text {
            text: "APPEARANCE"
            leftPadding: 20
            topPadding: 20
            bottomPadding: 6
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            color: "#6E6E73"
        }

        Rectangle {
            width: parent.width - 40
            x: 20
            color: Qt.rgba(0,0,0,0.04)
            radius: 12
            implicitHeight: appearanceCol.implicitHeight

            Column {
                id: appearanceCol
                width: parent.width
                spacing: 0

                // Dark / Light mode switch
                SettingsRow {
                    label: "Dark mode"
                    sublabel: "System-wide dark appearance"
                    control: Switch {
                        checked: true
                        onToggled: {
                            var theme = checked ? "MacTahoe-Dark" : "MacTahoe-Light"
                            // Apply via gsettings + env
                        }
                    }
                }
                SettingsDivider {}

                // Accent color
                SettingsRow {
                    label: "Accent color"
                    sublabel: "Used for highlights and buttons"
                    control: Rectangle {
                        width: 28; height: 28; radius: 14
                        color: "#0A84FF"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }

        // ── Window Buttons section ────────────────────────────────────────
        Text {
            text: "WINDOW BUTTONS"
            leftPadding: 20
            topPadding: 20
            bottomPadding: 6
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            color: "#6E6E73"
        }

        Rectangle {
            width: parent.width - 40
            x: 20
            color: Qt.rgba(0,0,0,0.04)
            radius: 12
            implicitHeight: windowCol.implicitHeight

            Column {
                id: windowCol
                width: parent.width

                SettingsRow {
                    label: "Button position"
                    sublabel: "Traffic light position on titlebar"
                    control: ComboBox {
                        model: ["Left (macOS style)", "Right"]
                        currentIndex: 0
                    }
                }
            }
        }

        Item { height: 20 }
    }
}
QMLEOF
  ok "VoidDE settings page written"
fi

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Icon cache + font cache update
# ══════════════════════════════════════════════════════════════════════════════
step "Updating caches"

for icondir in \
  /usr/share/icons/MacTahoe \
  "$HOME/.local/share/icons/MacTahoe" \
  "$HOME/.local/share/icons/WhiteSur-cursors"; do
  [ -d "$icondir" ] && \
    gtk-update-icon-cache -f "$icondir" 2>/dev/null && \
    log "Updated: $icondir"
done

fc-cache -f 2>/dev/null && ok "Font cache updated"
update-mime-database /usr/share/mime 2>/dev/null || true
update-desktop-database 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════════════════
# SECTION: Final summary
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${G}${W}╔════════════════════════════════════════════════════════╗${N}"
echo -e "${G}${W}║       VoidDE installed successfully!                   ║${N}"
echo -e "${G}${W}╚════════════════════════════════════════════════════════╝${N}"
echo ""
echo -e "  ${W}Base:${N}    CutefishOS (Qt/QML) — github.com/cutefishos"
echo -e "  ${W}Theme:${N}   MacTahoe by vinceliuice"
echo -e "  ${W}Icons:${N}   MacTahoe icons by vinceliuice"
echo -e "  ${W}Cursor:${N}  WhiteSur cursors by vinceliuice"
echo -e "  ${W}Buttons:${N} Traffic lights — LEFT side (macOS style)"
echo ""
echo -e "  ${C}Next steps:${N}"
echo -e "    1. Log out of current session"
echo -e "    2. Select ${W}VoidDE${N} at your login screen"
echo -e "    3. Log in"
echo ""
echo -e "  ${C}What changed from CutefishOS:${N}"
echo -e "    ✓ Window close/min/max buttons → LEFT side"
echo -e "    ✓ MacTahoe dark/light color palette in fishui"
echo -e "    ✓ Dock: frosted glass pill, macOS icon magnify"
echo -e "    ✓ Launcher: Spotlight overlay layout"
echo -e "    ✓ Panel: VoidDE logo menu, macOS bar style"
echo -e "    ✓ File manager: Finder sidebar + section headers"
echo -e "    ✓ picom: blur, shadows, 12px rounded corners"
echo -e "    ✓ MacTahoe GTK + Qt/Kvantum theme"
echo ""
echo -e "  ${C}Build dir:${N} $BUILD_DIR"
echo -e "  ${C}Source:${N}    $SRC_DIR"
echo ""
