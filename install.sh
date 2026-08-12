#!/usr/bin/env bash

# ==============================================================================
#  YTDx Studio - Universal Linux Automated Installer
#  Supported Distros: Ubuntu, Debian, Linux Mint, Arch, Manjaro, Fedora, openSUSE
# ==============================================================================

set -e

# ANSI Color Codes for Beautiful CLI Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

clear

echo -e "${PURPLE}${BOLD}"
cat << "EOF"
 __   ___________ ____         ____  _             _ _       
 \ \ / /_   _|  _ \__ \       / ___|| |_ _   _  __| (_) ___  
  \ V /  | | | | | | ) |____  \___ \| __| | | |/ _` | |/ _ \ 
   | |   | | | |_| |/ //_____|  ___) | |_| |_| | (_| | | (_) |
   |_|   |_| |____/___|       |____/ \__|\__,_|\__,_|_|\___/ 
                                                              
EOF
echo -e "${NC}"
echo -e "${CYAN}${BOLD}⚡ YTDx Studio - Next-Gen YouTube Video & Music Downloader${NC}"
echo -e "${BLUE}==============================================================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ------------------------------------------------------------------------------
# 1. Distro Detection & System Dependencies Installation
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/5]${NC} 🔍 Linux Dağıtımı Tespit Ediliyor..."

DISTRO="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_LIKE=${ID_LIKE:-$ID}
fi

echo -e "   -> Tespit edilen sistem: ${GREEN}${BOLD}${NAME:-$DISTRO}${NC}"

install_system_deps() {
    echo -e "${BLUE}[2/5]${NC} 📦 Gerekli sistem paketleri yükleniyor (FFmpeg, Python, GTK, GStreamer)..."
    
    if command -v apt-get >/dev/null 2>&1; then
        echo -e "   -> ${CYAN}APT (Debian/Ubuntu/Mint/Pop) paket yöneticisi kullanılıyor...${NC}"
        sudo apt-get update -qq
        sudo apt-get install -y ffmpeg python3 python3-pip python3-venv libgtk-3-0 libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libgstreamer-plugins-good1.0-0 xdg-utils
    elif command -v pacman >/dev/null 2>&1; then
        echo -e "   -> ${CYAN}Pacman (Arch/Manjaro/EndeavourOS) paket yöneticisi kullanılıyor...${NC}"
        sudo pacman -Sy --noconfirm --needed ffmpeg python python-pip python-virtualenv gtk3 gstreamer gst-plugins-base gst-plugins-good xdg-utils
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "   -> ${CYAN}DNF (Fedora/RHEL/Alma/Rocky) paket yöneticisi kullanılıyor...${NC}"
        sudo dnf install -y ffmpeg python3 python3-pip python3-virtualenv gtk3 gstreamer1 gstreamer1-plugins-base gstreamer1-plugins-good xdg-utils
    elif command -v zypper >/dev/null 2>&1; then
        echo -e "   -> ${CYAN}Zypper (openSUSE) paket yöneticisi kullanılıyor...${NC}"
        sudo zypper install -y ffmpeg python3 python3-pip python3-virtualenv gtk3 gstreamer gstreamer-plugins-base gstreamer-plugins-good xdg-utils
    else
        echo -e "${YELLOW}⚠️ Bilinmeyen paket yöneticisi. Lütfen 'ffmpeg' ve 'python3' paketlerinin kurulu olduğundan emin olun.${NC}"
    fi
}

install_system_deps

# ------------------------------------------------------------------------------
# 2. Python Virtual Environment Setup (.venv)
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[3/5]${NC} 🐍 Python Sanal Ortamı (.venv) Hazırlanıyor..."

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    echo -e "   -> ${GREEN}Yeni .venv sanal ortamı oluşturuldu.${NC}"
else
    echo -e "   -> ${GREEN}Mevcut .venv sanal ortamı doğrulandı.${NC}"
fi

echo -e "   -> Gerekli Python kütüphaneleri kuruluyor (pytubefix, yt-dlp, mutagen, Pillow)..."
.venv/bin/pip install --upgrade pip --quiet
.venv/bin/pip install -r requirements.txt --quiet
echo -e "   -> ${GREEN}✓ Python bağımlılıkları başarıyla yüklendi.${NC}"

# ------------------------------------------------------------------------------
# 3. Application Release Binary Verification / Build
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[4/5]${NC} 🚀 YTDx Studio Uygulama Motoru Doğrulanıyor..."

RELEASE_BIN="$SCRIPT_DIR/aura_app/build/linux/x64/release/bundle/aura_app"

if [ ! -f "$RELEASE_BIN" ]; then
    if command -v flutter >/dev/null 2>&1; then
        echo -e "   -> Flutter SDK bulundu. Bağımlılıklar alınıyor ve Release sürümü derleniyor..."
        (
            cd "$SCRIPT_DIR/aura_app"
            flutter pub get
            flutter build linux --release -t lib/main.dart
        )
    else
        echo -e "${YELLOW}⚠️ Release paketi bulunamadı ve Flutter SDK yüklü değil.${NC}"
        echo -e "   -> Uygulama derlemek için Flutter SDK gereklidir: https://docs.flutter.dev/get-started/install/linux${NC}"
    fi
fi

if [ -f "$RELEASE_BIN" ]; then
    chmod +x "$RELEASE_BIN"
fi
chmod +x "$SCRIPT_DIR/main.py"

# ------------------------------------------------------------------------------
# 4. Desktop Entry & System Launcher Integration
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}[5/5]${NC} 🖥️ Masaüstü Simgesi & Sistem Kısayolu Entegre Ediliyor..."

APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$APPS_DIR"
mkdir -p "$ICONS_DIR"
mkdir -p "$BIN_DIR"

# Copy Icon
if [ -f "$SCRIPT_DIR/icons/icon_256.png" ]; then
    cp "$SCRIPT_DIR/icons/icon_256.png" "$ICONS_DIR/ytdx.png"
elif [ -f "$SCRIPT_DIR/icons/app_icon.png" ]; then
    cp "$SCRIPT_DIR/icons/app_icon.png" "$ICONS_DIR/ytdx.png"
fi

# Create .desktop file
DESKTOP_FILE="$APPS_DIR/ytdx-studio.desktop"
cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=YTDx Studio
GenericName=YouTube Downloader & Player
Comment=Next-Gen 4K Video & 320kbps Music Downloader
Exec=python3 "$SCRIPT_DIR/main.py"
Icon=$ICONS_DIR/ytdx.png
Terminal=false
Categories=AudioVideo;Audio;Video;Network;
Keywords=youtube;downloader;music;video;mp3;mp4;4k;ytdx;
StartupWMClass=aura_app
EOF

chmod +x "$DESKTOP_FILE"

# Place shortcut directly on Desktop screen
DESKTOP_PATH="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [ -d "$DESKTOP_PATH" ]; then
    cp "$DESKTOP_FILE" "$DESKTOP_PATH/ytdx-studio.desktop"
    chmod +x "$DESKTOP_PATH/ytdx-studio.desktop"
    gio set "$DESKTOP_PATH/ytdx-studio.desktop" metadata::trusted true 2>/dev/null || true
fi
if [ -d "$HOME/Masaüstü" ] && [ "$DESKTOP_PATH" != "$HOME/Masaüstü" ]; then
    cp "$DESKTOP_FILE" "$HOME/Masaüstü/ytdx-studio.desktop"
    chmod +x "$HOME/Masaüstü/ytdx-studio.desktop"
    gio set "$HOME/Masaüstü/ytdx-studio.desktop" metadata::trusted true 2>/dev/null || true
fi

# Create Terminal CLI command 'ytdx'
cat << EOF > "$BIN_DIR/ytdx"
#!/usr/bin/env bash
python3 "$SCRIPT_DIR/main.py" "\$@"
EOF
chmod +x "$BIN_DIR/ytdx"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# Done!
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}==============================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 TEBRİKLER! YTDx Studio Kurulumu Başarıyla Tamamlandı!${NC}"
echo -e "${GREEN}${BOLD}==============================================================${NC}"
echo ""
echo -e "🚀 Uygulamayı başlatmak için:"
echo -e "   1. Linux ${BOLD}Uygulama Menünüzden 'YTDx Studio'${NC} simgesine tıklayın."
echo -e "   2. Veya terminalden doğrudan ${CYAN}${BOLD}ytdx${NC} komutunu çalıştırın."
echo -e "   3. Veya bu klasörde ${CYAN}${BOLD}python3 main.py${NC} komutunu verin."
echo ""
echo -e "${CYAN}Keyifli indirmeler ve dinlemeler dileriz! ✨${NC}"
echo ""
