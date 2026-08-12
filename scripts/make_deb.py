#!/usr/bin/env python3
"""
Custom pure-python .deb package builder for YTDx Studio.
Creates fully compliant Debian/Ubuntu .deb binary package without needing dpkg installed.
"""

import os
import tarfile
import io
import struct
import shutil
from pathlib import Path

def create_deb_package(root_dir: Path, output_deb_path: Path):
    output_deb_path.parent.mkdir(parents=True, exist_ok=True)
    
    # 1. debian-binary
    debian_binary = b"2.0\n"
    
    # 2. control.tar.gz
    control_tar_io = io.BytesIO()
    with tarfile.open(fileobj=control_tar_io, mode="w:gz") as tar:
        control_dir = root_dir / "DEBIAN"
        for file in sorted(control_dir.rglob("*")):
            if file.is_file():
                arcname = file.relative_to(control_dir).as_posix()
                ti = tar.gettarinfo(file, arcname=f"./{arcname}")
                ti.uid = 0
                ti.gid = 0
                ti.uname = "root"
                ti.gname = "root"
                if file.name == "postinst" or file.name == "prerm" or file.name == "postrm":
                    ti.mode = 0o755
                else:
                    ti.mode = 0o644
                with open(file, "rb") as f:
                    tar.addfile(ti, f)
    control_tar_bytes = control_tar_io.getvalue()
    
    # 3. data.tar.gz
    data_tar_io = io.BytesIO()
    with tarfile.open(fileobj=data_tar_io, mode="w:gz") as tar:
        for path in sorted(root_dir.rglob("*")):
            if "DEBIAN" in path.parts:
                continue
            arcname = path.relative_to(root_dir).as_posix()
            ti = tar.gettarinfo(path, arcname=f"./{arcname}")
            ti.uid = 0
            ti.gid = 0
            ti.uname = "root"
            ti.gname = "root"
            if path.is_file():
                with open(path, "rb") as f:
                    tar.addfile(ti, f)
            elif path.is_dir():
                tar.addfile(ti)
            elif path.is_symlink():
                tar.addfile(ti)
    data_tar_bytes = data_tar_io.getvalue()
    
    # Assemble standard 'ar' archive (Debian .deb specification)
    def ar_header(name: str, size: int, mode: int = 0o100644):
        # Format: Name(16) Mtime(12) UID(6) GID(6) Mode(8) Size(10) Magic(2)
        name_field = f"{name:<16}"[:16]
        mtime_field = f"{0:<12}"[:12]
        uid_field = f"{0:<6}"[:6]
        gid_field = f"{0:<6}"[:6]
        mode_field = f"{oct(mode)[2:]:<8}"[:8]
        size_field = f"{size:<10}"[:10]
        header = f"{name_field}{mtime_field}{uid_field}{gid_field}{mode_field}{size_field}`\n"
        return header.encode("ascii")

    with open(output_deb_path, "wb") as deb:
        deb.write(b"!<arch>\n")
        
        # Add debian-binary
        deb.write(ar_header("debian-binary", len(debian_binary)))
        deb.write(debian_binary)
        if len(debian_binary) % 2 != 0:
            deb.write(b"\n")
            
        # Add control.tar.gz
        deb.write(ar_header("control.tar.gz", len(control_tar_bytes)))
        deb.write(control_tar_bytes)
        if len(control_tar_bytes) % 2 != 0:
            deb.write(b"\n")
            
        # Add data.tar.gz
        deb.write(ar_header("data.tar.gz", len(data_tar_bytes)))
        deb.write(data_tar_bytes)
        if len(data_tar_bytes) % 2 != 0:
            deb.write(b"\n")

    print(f"✓ Created Debian package: {output_deb_path} ({output_deb_path.stat().st_size / (1024*1024):.2f} MB)")

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3:
        print("Usage: make_deb.py <staging_dir> <output.deb>")
        sys.exit(1)
    create_deb_package(Path(sys.argv[1]), Path(sys.argv[2]))
