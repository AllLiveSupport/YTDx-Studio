# Tech Context - YTDx

## Technologies Used
- **Python 3.14+**
- **GUI Toolkit**: PyQt6 (6.11.0), PyQt6-Qt6 (6.11.1)
- **YouTube Extraction Engine**: `pytubefix` (10.11.0)
- **Image Processing**: `Pillow` (12.3.0)
- **Audio Tagging**: `mutagen` (1.48.1)
- **Network / HTTP**: `requests` (2.34.2), `aiohttp`
- **External Binaries**: `ffmpeg` (installed and accessible via system PATH)

## Development Setup & Execution
- Virtual environment: `.venv` in workspace root.
- Automatic Bootstrap: [main.py](file:///home/oimp/Downloads/YTDx-Youtube-Downloader/main.py) automatically redirects system python invocations (`/bin/python main.py` or `python main.py`) to `.venv/bin/python` if packages are not found in the host python.
- VS Code Interpreter: `.vscode/settings.json` configured to use `.venv/bin/python`.
- Run commands:
  - `.venv/bin/python3 main.py`
  - `python3 main.py` (auto-delegated to `.venv`)
