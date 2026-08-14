#!/usr/bin/env bash

# ==============================================================================
#  YTDx Studio - Linux Uninstaller Script
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🧹 YTDx Studio Kaldırılıyor...${NC}"

# Remove desktop entries
rm -f "$HOME/.local/share/applications/ytdx-studio.desktop"
rm -f "$HOME/.local/share/applications/ytdx-downloader.desktop"
rm -f "$HOME/Desktop/ytdx-studio.desktop"
rm -f "$HOME/Masaüstü/ytdx-studio.desktop"

# Remove CLI launcher & icons
rm -f "$HOME/.local/bin/ytdx"
rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/ytdx.png"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

echo -e "${GREEN}✓ YTDx Studio masaüstü simgeleri ve kısayolları sistemden tamamen temizlendi.${NC}"
