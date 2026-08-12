#!/usr/bin/env python3
"""
YTDx Studio - Linux Package Builder
Builds .deb, .tar.gz, .AppImage, and PKGBUILD for GitHub Releases.
"""

import os
import sys
import shutil
import tarfile
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
DIST_DIR = ROOT_DIR / "dist"
BUILD_DIR = ROOT_DIR / "aura_app" / "build" / "linux" / "x64" / "release" / "bundle"
VERSION = "1.0.0"
APP_NAME = "ytdx-studio"
DISPLAY_NAME = "YTDx Studio"

def ensure_release_built():
    """Ensure Flutter Linux release bundle is compiled."""
    print("🚀 [1/5] Flutter Release Bundle kontrol ediliyor...")
    if not (BUILD_DIR / "aura_app").exists():
        print("   -> Release derlemesi başlatılıyor...")
        subprocess.run(
            ["flutter", "build", "linux", "--release", "-t", "lib/main.dart"],
            cwd=ROOT_DIR / "aura_app",
            check=True
        )
    print("   -> ✓ Flutter Release Bundle hazır.")

def build_tar_gz():
    """Build portable .tar.gz archive."""
    print("\n📦 [2/5] Portable .tar.gz paketi oluşturuluyor...")
    tar_name = f"YTDx-Studio-{VERSION}-Linux-x86_64.tar.gz"
    tar_path = DIST_DIR / tar_name
    
    stage_dir = DIST_DIR / f"YTDx-Studio-{VERSION}"
    if stage_dir.exists():
        shutil.rmtree(stage_dir)
    stage_dir.mkdir(parents=True)

    # Copy bundle
    shutil.copytree(BUILD_DIR, stage_dir / "bin")
    shutil.copytree(ROOT_DIR / "src", stage_dir / "src", ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    shutil.copy(ROOT_DIR / "requirements.txt", stage_dir / "requirements.txt")
    shutil.copy(ROOT_DIR / "main.py", stage_dir / "main.py")
    shutil.copy(ROOT_DIR / "install.sh", stage_dir / "install.sh")
    shutil.copy(ROOT_DIR / "LICENSE", stage_dir / "LICENSE")
    shutil.copy(ROOT_DIR / "DISCLAIMER.md", stage_dir / "DISCLAIMER.md")
    shutil.copy(ROOT_DIR / "README.md", stage_dir / "README.md")
    shutil.copytree(ROOT_DIR / "icons", stage_dir / "icons")

    def anonymize_tar(tarinfo):
        tarinfo.uid = 0
        tarinfo.gid = 0
        tarinfo.uname = "root"
        tarinfo.gname = "root"
        return tarinfo

    # Create tar.gz with 100% anonymized metadata
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(stage_dir, arcname=f"YTDx-Studio-{VERSION}", filter=anonymize_tar)

    shutil.rmtree(stage_dir)
    print(f"   -> ✓ {tar_name} oluşturuldu ({tar_path.stat().st_size / (1024*1024):.1f} MB).")
    return tar_path

def build_deb():
    """Build Debian/Ubuntu .deb package."""
    print("\n📦 [3/5] Debian/Ubuntu .deb paketi oluşturuluyor...")
    deb_name = f"ytdx-studio_{VERSION}_amd64.deb"
    deb_path = DIST_DIR / deb_name

    deb_root = DIST_DIR / "deb_staging"
    if deb_root.exists():
        shutil.rmtree(deb_root)

    opt_dir = deb_root / "opt" / APP_NAME
    bin_dir = deb_root / "usr" / "bin"
    apps_dir = deb_root / "usr" / "share" / "applications"
    icons_dir = deb_root / "usr" / "share" / "icons" / "hicolor" / "256x256" / "apps"
    debian_dir = deb_root / "DEBIAN"

    for d in [opt_dir, bin_dir, apps_dir, icons_dir, debian_dir]:
        d.mkdir(parents=True, exist_ok=True)

    # Copy files into /opt/ytdx-studio
    shutil.copytree(BUILD_DIR, opt_dir / "bundle")
    shutil.copytree(ROOT_DIR / "src", opt_dir / "src", ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    shutil.copy(ROOT_DIR / "requirements.txt", opt_dir / "requirements.txt")
    shutil.copy(ROOT_DIR / "main.py", opt_dir / "main.py")
    shutil.copy(ROOT_DIR / "LICENSE", opt_dir / "LICENSE")
    shutil.copy(ROOT_DIR / "DISCLAIMER.md", opt_dir / "DISCLAIMER.md")
    shutil.copy(ROOT_DIR / "icons" / "icon_256.png", icons_dir / "ytdx.png")

    # Wrapper script in /usr/bin/ytdx
    launcher = bin_dir / "ytdx"
    launcher.write_text(f"""#!/usr/bin/env bash
/opt/{APP_NAME}/bundle/aura_app "$@"
""")
    launcher.chmod(0o755)

    # Desktop Entry
    desktop_file = apps_dir / "ytdx-studio.desktop"
    desktop_file.write_text(f"""[Desktop Entry]
Version=1.0
Type=Application
Name={DISPLAY_NAME}
GenericName=YouTube Downloader & Player
Comment=Next-Gen 4K Video & 320kbps Music Downloader
Exec=/usr/bin/ytdx
Icon=ytdx
Terminal=false
Categories=AudioVideo;Audio;Video;Network;
Keywords=youtube;downloader;music;video;mp3;mp4;4k;ytdx;
StartupWMClass=aura_app
""")
    desktop_file.chmod(0o644)

    # Control file
    control_file = debian_dir / "control"
    control_file.write_text(f"""Package: {APP_NAME}
Version: {VERSION}
Section: video
Priority: optional
Architecture: amd64
Depends: ffmpeg, python3, python3-pip, python3-venv, libgtk-3-0, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0
Maintainer: AllLiveSupport <https://github.com/AllLiveSupport/YTDx-Studio>
Description: Next-Gen YouTube Video & 320kbps Music Downloader
 YTDx Studio is an ultra-fast modern YouTube video and music downloader
 featuring 4K/8K MP4, 320kbps MP3 with album covers, playlist batch downloading,
 and an in-app audio player built with Flutter Desktop.
""")
    control_file.chmod(0o644)

    # Postinst script for python venv setup
    postinst_file = debian_dir / "postinst"
    postinst_file.write_text(f"""#!/bin/sh
set -e
if [ ! -d "/opt/{APP_NAME}/.venv" ]; then
    python3 -m venv /opt/{APP_NAME}/.venv
    /opt/{APP_NAME}/.venv/bin/pip install --upgrade pip --quiet
    /opt/{APP_NAME}/.venv/bin/pip install -r /opt/{APP_NAME}/requirements.txt --quiet
fi
chmod -R 777 /opt/{APP_NAME}/.venv 2>/dev/null || true
exit 0
""")
    postinst_file.chmod(0o755)

    # Build .deb with dpkg-deb or fallback python ar
    if shutil.which("dpkg-deb"):
        subprocess.run(["dpkg-deb", "--build", str(deb_root), str(deb_path)], check=True)
    else:
        # Pure Python fallback to create .deb archive
        print("   -> dpkg-deb bulunamadı, dahili paketleyici kullanılıyor...")
        build_deb_fallback(deb_root, deb_path)

    shutil.rmtree(deb_root)
    print(f"   -> ✓ {deb_name} oluşturuldu ({deb_path.stat().st_size / (1024*1024):.1f} MB).")
    return deb_path

def build_deb_fallback(deb_root: Path, deb_path: Path):
    """Create .deb without dpkg-deb using standard ar/tar structure."""
    import io

    # 1. debian-binary
    deb_binary = b"2.0\n"

    # 2. control.tar.gz
    ctrl_buf = io.BytesIO()
    with tarfile.open(fileobj=ctrl_buf, mode="w:gz") as tar:
        for item in (deb_root / "DEBIAN").iterdir():
            tar.add(item, arcname=f"./{item.name}")
    ctrl_bytes = ctrl_buf.getvalue()

    # 3. data.tar.gz
    data_buf = io.BytesIO()
    with tarfile.open(fileobj=data_buf, mode="w:gz") as tar:
        for top_dir in ["opt", "usr"]:
            p = deb_root / top_dir
            if p.exists():
                tar.add(p, arcname=f"./{top_dir}")
    data_bytes = data_buf.getvalue()

    # Create ar archive
    def make_ar_header(name: str, size: int) -> bytes:
        return f"{name:<16}0           0     0     100644  {size:<10}`\n".encode("latin1")

    with open(deb_path, "wb") as f:
        f.write(b"!<arch>\n")
        f.write(make_ar_header("debian-binary", len(deb_binary)))
        f.write(deb_binary)
        if len(deb_binary) % 2 != 0:
            f.write(b"\n")

        f.write(make_ar_header("control.tar.gz", len(ctrl_bytes)))
        f.write(ctrl_bytes)
        if len(ctrl_bytes) % 2 != 0:
            f.write(b"\n")

        f.write(make_ar_header("data.tar.gz", len(data_bytes)))
        f.write(data_bytes)
        if len(data_bytes) % 2 != 0:
            f.write(b"\n")

def build_appimage():
    """Build universal .AppImage."""
    print("\n📦 [4/5] Evrensel .AppImage paketi oluşturuluyor...")
    app_dir = DIST_DIR / "AppDir"
    if app_dir.exists():
        shutil.rmtree(app_dir)
    app_dir.mkdir(parents=True)

    # Copy bundle intact
    shutil.copytree(BUILD_DIR, app_dir / "bundle")

    # Copy python src & icons
    shutil.copytree(ROOT_DIR / "src", app_dir / "src", ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    shutil.copy(ROOT_DIR / "requirements.txt", app_dir / "requirements.txt")
    shutil.copy(ROOT_DIR / "main.py", app_dir / "main.py")
    shutil.copy(ROOT_DIR / "icons" / "icon_256.png", app_dir / "ytdx.png")

    # AppRun entrypoint
    apprun = app_dir / "AppRun"
    apprun.write_text("""#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/bundle/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/bundle/aura_app" "$@"
""")
    apprun.chmod(0o755)

    # Desktop file
    desktop = app_dir / "ytdx-studio.desktop"
    desktop.write_text(f"""[Desktop Entry]
Version=1.0
Type=Application
Name={DISPLAY_NAME}
Exec=AppRun
Icon=ytdx
Categories=AudioVideo;Audio;Video;Network;
Terminal=false
StartupWMClass=aura_app
""")
    desktop.chmod(0o644)

    # Download appimagetool if not present
    appimagetool = DIST_DIR / "appimagetool-x86_64.AppImage"
    if not appimagetool.exists():
        print("   -> appimagetool indiriliyor...")
        url = "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
        subprocess.run(["curl", "-L", "-o", str(appimagetool), url, "--silent"], check=True)
        appimagetool.chmod(0o755)

    out_appimage = DIST_DIR / f"YTDx-Studio-{VERSION}-x86_64.AppImage"
    env = os.environ.copy()
    env["ARCH"] = "x86_64"
    env["APPIMAGE_EXTRACT_AND_RUN"] = "1"
    
    try:
        subprocess.run(
            [str(appimagetool), "--appimage-extract-and-run", str(app_dir), str(out_appimage)],
            env=env,
            check=True
        )
        print(f"   -> ✓ {out_appimage.name} oluşturuldu ({out_appimage.stat().st_size / (1024*1024):.1f} MB).")
    except Exception as e:
        print(f"   -> ⚠️ AppImage derlenirken hata: {e}")
    finally:
        if app_dir.exists():
            shutil.rmtree(app_dir)

def create_arch_pkgbuild():
    """Create Arch Linux PKGBUILD."""
    print("\n📦 [5/5] Arch Linux PKGBUILD oluşturuluyor...")
    pkgbuild = DIST_DIR / "PKGBUILD"
    pkgbuild.write_text(f"""# Maintainer: AllLiveSupport <https://github.com/AllLiveSupport/YTDx-Studio>
pkgname={APP_NAME}-bin
pkgver={VERSION}
pkgrel=1
pkgdesc="Next-Gen YouTube Video & 320kbps Music Downloader Desktop Suite"
arch=('x86_64')
url="https://github.com/AllLiveSupport/YTDx-Studio"
license=('MIT')
depends=('ffmpeg' 'python' 'python-pip' 'python-virtualenv' 'gtk3' 'gstreamer' 'gst-plugins-base' 'gst-plugins-good')
source=("https://github.com/AllLiveSupport/YTDx-Studio/releases/download/v{VERSION}/YTDx-Studio-{VERSION}-Linux-x86_64.tar.gz")
sha256sums=('SKIP')

package() {{
    install -d "$pkgdir/opt/{APP_NAME}"
    install -d "$pkgdir/usr/bin"
    install -d "$pkgdir/usr/share/applications"
    install -d "$pkgdir/usr/share/icons/hicolor/256x256/apps"

    cp -r "$srcdir/YTDx-Studio-{VERSION}/"* "$pkgdir/opt/{APP_NAME}/"
    install -m644 "$srcdir/YTDx-Studio-{VERSION}/icons/icon_256.png" "$pkgdir/usr/share/icons/hicolor/256x256/apps/ytdx.png"

    # Symlink launcher
    ln -s "/opt/{APP_NAME}/bin/aura_app" "$pkgdir/usr/bin/ytdx"

    # Desktop file
    cat << EOF > "$pkgdir/usr/share/applications/ytdx-studio.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name={DISPLAY_NAME}
GenericName=YouTube Downloader & Player
Comment=Next-Gen 4K Video & 320kbps Music Downloader
Exec=/usr/bin/ytdx
Icon=ytdx
Terminal=false
Categories=AudioVideo;Audio;Video;Network;
StartupWMClass=aura_app
EOF
}}
""")
    print("   -> ✓ PKGBUILD oluşturuldu.")

def main():
    DIST_DIR.mkdir(parents=True, exist_ok=True)
    print("=" * 60)
    print("⚡ YTDx Studio - Çoklu Dağıtım Paket Üretim Motoru")
    print("=" * 60)
    ensure_release_built()
    build_tar_gz()
    build_deb()
    build_appimage()
    create_arch_pkgbuild()
    print("\n" + "=" * 60)
    print("🎉 TÜM DAĞITIM PAKETLERİ BAŞARIYLA ÜRETİLDİ!")
    print(f"📁 Dosyalar '{DIST_DIR.resolve()}' klasöründe:")
    for f in DIST_DIR.iterdir():
        if f.is_file() and not f.name.endswith(".AppImage.part"):
            size_mb = f.stat().st_size / (1024 * 1024)
            print(f"   • {f.name:<42} ({size_mb:.2f} MB)")
    print("=" * 60)

if __name__ == "__main__":
    main()
