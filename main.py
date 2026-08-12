#!/usr/bin/env python3
"""
YTDx Downloader - Universal Desktop Launcher
Launches the high-performance YTDx Downloader application.
"""

import os
import sys
import subprocess
import platform

def find_app_binary():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    system = platform.system().lower()

    if system == "linux":
        candidates = [
            os.path.join(base_dir, "aura_app", "build", "linux", "x64", "release", "bundle", "aura_app"),
            os.path.join(base_dir, "aura_app", "build", "linux", "x64", "debug", "bundle", "aura_app"),
            os.path.join(base_dir, "build", "linux", "x64", "release", "bundle", "aura_app"),
        ]
    elif system == "windows":
        candidates = [
            os.path.join(base_dir, "aura_app", "build", "windows", "x64", "runner", "Release", "aura_app.exe"),
            os.path.join(base_dir, "aura_app", "build", "windows", "x64", "runner", "Debug", "aura_app.exe"),
        ]
    elif system == "darwin":  # macOS
        candidates = [
            os.path.join(base_dir, "aura_app", "build", "macos", "Build", "Products", "Release", "aura_app.app", "Contents", "MacOS", "aura_app"),
        ]
    else:
        candidates = []

    for path in candidates:
        if os.path.exists(path):
            return path
    return None

def main():
    binary = find_app_binary()
    if binary:
        print(f"[*] Launching YTDx Downloader: {binary}")
        sys.exit(subprocess.call([binary] + sys.argv[1:]))
    else:
        print("[!] Pre-compiled binary not found. Running with Flutter CLI...")
        aura_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aura_app")
        if os.path.exists(aura_dir):
            sys.exit(subprocess.call(["flutter", "run", "-d", "linux"], cwd=aura_dir))
        else:
            print("[X] Error: Could not find application directory.")
            sys.exit(1)

if __name__ == "__main__":
    main()
