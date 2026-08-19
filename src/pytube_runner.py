import sys
import os
import argparse
import time
import subprocess
import re
import shutil
from typing import List, Optional
import requests
from pytubefix import YouTube
from PIL import Image
import mutagen
from mutagen.id3 import ID3, APIC, TIT2, TPE1, TALB
from mutagen.mp4 import MP4, MP4Cover

_last_time = time.time()
_last_bytes = 0

def progress_callback(stream, chunk, bytes_remaining):
    global _last_time, _last_bytes
    total_size = stream.filesize
    bytes_downloaded = total_size - bytes_remaining
    now = time.time()
    elapsed = now - _last_time

    if elapsed >= 0.2 or bytes_remaining == 0:
        diff_bytes = bytes_downloaded - _last_bytes
        speed_bps = (diff_bytes / elapsed) if (elapsed > 0 and diff_bytes > 0) else 0
        _last_time = now
        _last_bytes = bytes_downloaded

        pct = (bytes_downloaded / total_size * 100.0) if total_size > 0 else 0
        mb_down = bytes_downloaded / (1024 * 1024)
        mb_total = total_size / (1024 * 1024) if total_size > 0 else mb_down
        mb_speed = (speed_bps / (1024 * 1024)) if speed_bps > 0 else 3.5

        rem_bytes = max(0, bytes_remaining)
        eta_sec = int(rem_bytes / speed_bps) if speed_bps > 0 else 0
        eta_str = f"{eta_sec // 60:02d}:{eta_sec % 60:02d}" if eta_sec > 0 else "00:01"

        print(f"[download] {pct:.1f}% of {mb_total:.2f}MB at {mb_speed:.2f}MB/s ETA {eta_str}", flush=True)

def sanitize_filename(name: str) -> str:
    clean = re.sub(r'[\\/*?:"<>|]', "", name).strip()
    return clean if clean else "audio_download"

def cleanup_temp_files(output_dir: str, title: str) -> None:
    """Removes any temporary residual files matching title with _temp_raw, _vtemp, or _atemp."""
    try:
        if not os.path.exists(output_dir):
            return
        for f in os.listdir(output_dir):
            if f.startswith(title) and any(tag in f for tag in ["_temp_raw", "_vtemp", "_atemp", "_temp"]):
                full_p = os.path.join(output_dir, f)
                if os.path.isfile(full_p):
                    try:
                        os.remove(full_p)
                    except Exception:
                        pass
    except Exception:
        pass

def get_pytube_instance(url: str) -> YouTube:
    for c in ["ANDROID", "MWEB", "WEB"]:
        try:
            yt = YouTube(url, client=c, on_progress_callback=progress_callback)
            if yt.title and yt.streams:
                return yt
        except Exception:
            continue
    return YouTube(url, on_progress_callback=progress_callback)

def find_ytdlp_executable() -> str:
    py_dir = os.path.dirname(sys.executable)
    candidate = os.path.join(py_dir, "yt-dlp")
    if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
        return candidate
    candidate_win = os.path.join(py_dir, "yt-dlp.exe")
    if os.path.isfile(candidate_win):
        return candidate_win

    found = shutil.which("yt-dlp")
    if found:
        return found

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    venv_candidate = os.path.join(repo_root, ".venv", "bin", "yt-dlp")
    if os.path.isfile(venv_candidate):
        return venv_candidate

    return "yt-dlp"

def fallback_ytdlp(url: str, output_dir: str, is_audio: bool, fmt: str = "mp3", quality: str = "320k") -> bool:
    try:
        print("[status] Otomatik yt-dlp yedek motoruna geçiliyor...", flush=True)
        ytdlp_bin = find_ytdlp_executable()
        cmd = [
            ytdlp_bin,
            "--newline",
            "--no-warnings",
            "--no-check-certificate",
            "--retries", "5",
            "--fragment-retries", "5",
            "--socket-timeout", "30",
            "--extractor-args", "youtube:player_client=android,web",
            "--windows-filenames",
            "-o", os.path.join(output_dir, "%(title)s.%(ext)s")
        ]
        if is_audio:
            cmd.extend([
                "-x",
                "--audio-format", fmt,
                "--audio-quality", "0" if quality == "320k" else "2",
                "--embed-thumbnail",
                "--add-metadata"
            ])
        else:
            cmd.extend([
                "--merge-output-format", "mp4",
                "--embed-thumbnail",
                "--add-metadata"
            ])
        cmd.append(url)
        proc = subprocess.run(cmd)
        return proc.returncode == 0
    except Exception as e:
        print(f"[error] Yedek motor hatası: {e}", flush=True)
        return False

def download_audio(url: str, output_dir: str, fmt: str = "mp3", quality: str = "320k") -> bool:
    title: str = ""
    try:
        print(f"[status] Video bilgileri alınıyor...", flush=True)
        yt = get_pytube_instance(url)
        title = sanitize_filename(yt.title)
        
        # Select best audio stream
        audio_stream = yt.streams.get_audio_only()
        if not audio_stream:
            print("[error] Ses akışı bulunamadı.", flush=True)
            return False

        print(f"[status] Ses akışı indiriliyor: {yt.title}", flush=True)
        temp_filename = f"{title}_temp_raw"
        raw_download = audio_stream.download(output_path=output_dir, filename=temp_filename)
        if not raw_download or not os.path.exists(raw_download):
            print("[error] Ses dosyası indirilemedi.", flush=True)
            return False

        raw_file: str = raw_download
        fmt_clean: str = fmt.lower().strip()
        final_path: str = os.path.join(output_dir, f"{title}.{fmt_clean}")
        if os.path.exists(final_path):
            try:
                os.remove(final_path)
            except Exception:
                pass

        if fmt_clean == "mp3":
            print(f"[status] FFmpeg ile yüksek kalite 320kbps MP3 dönüştürülüyor...", flush=True)
            bitrate: str = quality if (isinstance(quality, str) and quality.endswith("k")) else "320k"
            cmd: List[str] = [
                "ffmpeg", "-y", "-i", raw_file,
                "-vn", "-ar", "44100", "-ac", "2",
                "-b:a", bitrate,
                final_path
            ]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            try:
                os.remove(raw_file)
            except Exception:
                pass

            # Embed thumbnail & metadata into MP3 (ID3)
            try:
                if yt.thumbnail_url:
                    thumb_res = requests.get(yt.thumbnail_url, timeout=10)
                    if thumb_res.status_code == 200:
                        audio = ID3(final_path)
                        audio.add(APIC(encoding=3, mime='image/jpeg', type=3, desc='Cover', data=thumb_res.content))
                        audio.add(TIT2(encoding=3, text=yt.title))
                        audio.add(TPE1(encoding=3, text=yt.author))
                        audio.save(v2_version=3)
            except Exception:
                pass

        elif fmt_clean == "m4a":
            print(f"[status] FFmpeg ile orijinal AAC M4A formatına dönüştürülüyor...", flush=True)
            cmd_m4a: List[str] = [
                "ffmpeg", "-y", "-i", raw_file,
                "-vn", "-c:a", "aac",
                "-b:a", "256k",
                final_path
            ]
            subprocess.run(cmd_m4a, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            try:
                os.remove(raw_file)
            except Exception:
                pass

            # Embed thumbnail & metadata into M4A (MP4 atom)
            try:
                if yt.thumbnail_url:
                    thumb_res = requests.get(yt.thumbnail_url, timeout=10)
                    if thumb_res.status_code == 200:
                        m4a_audio = MP4(final_path)
                        m4a_audio['\xa9nam'] = [yt.title]
                        m4a_audio['\xa9ART'] = [yt.author]
                        m4a_audio['covr'] = [MP4Cover(thumb_res.content, imageformat=MP4Cover.FORMAT_JPEG)]
                        m4a_audio.save()
            except Exception:
                pass

        elif fmt_clean in ["flac", "wav"]:
            print(f"[status] FFmpeg ile {fmt_clean.upper()} formatına dönüştürülüyor...", flush=True)
            cmd_flac: List[str] = ["ffmpeg", "-y", "-i", raw_file, "-vn", final_path]
            subprocess.run(cmd_flac, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            try:
                os.remove(raw_file)
            except Exception:
                pass

        else:
            cmd_gen: List[str] = ["ffmpeg", "-y", "-i", raw_file, "-vn", final_path]
            subprocess.run(cmd_gen, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            try:
                os.remove(raw_file)
            except Exception:
                pass

        cleanup_temp_files(output_dir, title)
        print("[download] 100.0% of finished successfully!", flush=True)
        return True
    except Exception as e:
        cleanup_temp_files(output_dir, title)
        print(f"[warning] Pytubefix akış uyarısı ({e}), otomatik yedek motora geçiliyor...", flush=True)
        return fallback_ytdlp(url, output_dir, is_audio=True, fmt=fmt, quality=quality)

def download_video(url: str, output_dir: str, quality: str = "auto") -> bool:
    title: str = ""
    try:
        print(f"[status] Video bilgileri alınıyor...", flush=True)
        yt = get_pytube_instance(url)
        title = sanitize_filename(yt.title)

        video_stream = None
        if quality != "auto" and bool(quality and quality != "auto"):
            res_str = quality.replace("p", "").strip() + "p"
            # Try specific video stream
            video_stream = yt.streams.filter(res=res_str, only_video=True).first()
            if not video_stream:
                video_stream = yt.streams.filter(res=res_str).first()

        if not video_stream:
            # Get the ABSOLUTE HIGHEST video resolution (4320p, 2160p, 1440p, 1080p, 720p)
            video_streams = yt.streams.filter(only_video=True).order_by('resolution').desc()
            if video_streams and len(video_streams) > 0:
                mp4_streams = [s for s in video_streams if s.mime_type == 'video/mp4']
                video_stream = mp4_streams[0] if mp4_streams else video_streams.first()
            else:
                video_stream = yt.streams.get_highest_resolution()

        if not video_stream:
            print("[error] Uygun video akışı bulunamadı.", flush=True)
            return False

        print(f"[status] En yüksek kalite video indiriliyor ({video_stream.resolution}): {yt.title}", flush=True)

        if getattr(video_stream, 'is_progressive', False):
            video_stream.download(output_path=output_dir, filename=f"{title}.mp4")
        else:
            # Download video stream
            raw_vid = video_stream.download(output_path=output_dir, filename=f"{title}_vtemp.mp4")
            if not raw_vid or not os.path.exists(raw_vid):
                print("[error] Video akışı indirilemedi.", flush=True)
                return False

            temp_vid: str = raw_vid

            # Download audio stream
            audio_stream = yt.streams.get_audio_only()
            raw_aud: Optional[str] = None
            if audio_stream:
                raw_aud = audio_stream.download(output_path=output_dir, filename=f"{title}_atemp.m4a")

            final_path = os.path.join(output_dir, f"{title}.mp4")
            if os.path.exists(final_path):
                try:
                    os.remove(final_path)
                except Exception:
                    pass

            if raw_aud and os.path.exists(raw_aud):
                temp_aud: str = raw_aud
                print(f"[status] FFmpeg ile yüksek kalite ses ve video birleştiriliyor ({video_stream.resolution})...", flush=True)
                cmd_merge: List[str] = [
                    "ffmpeg", "-y",
                    "-i", temp_vid,
                    "-i", temp_aud,
                    "-c:v", "copy",
                    "-c:a", "aac",
                    "-b:a", "192k",
                    final_path
                ]
                subprocess.run(cmd_merge, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                try:
                    os.remove(temp_vid)
                except Exception:
                    pass
                try:
                    os.remove(temp_aud)
                except Exception:
                    pass
            else:
                shutil.move(temp_vid, final_path)

        cleanup_temp_files(output_dir, title)
        print("[download] 100.0% of finished successfully!", flush=True)
        return True
    except Exception as e:
        cleanup_temp_files(output_dir, title)
        print(f"[warning] Pytubefix video uyarısı ({e}), otomatik yedek motora geçiliyor...", flush=True)
        return fallback_ytdlp(url, output_dir, is_audio=False, quality=quality)

def main() -> None:
    parser = argparse.ArgumentParser(description="Standalone Pytubefix Runner")
    parser.add_argument("--url", required=True, help="YouTube URL")
    parser.add_argument("--format", default="mp3", help="Format (mp3, m4a, mp4)")
    parser.add_argument("--quality", default="auto", help="Quality (320k, 1080p, auto)")
    parser.add_argument("--output", default=".", help="Output Dir")
    parser.add_argument("--is-audio", action="store_true", help="Audio mode")

    args = parser.parse_args()
    os.makedirs(args.output, exist_ok=True)

    is_audio = args.is_audio or args.format.lower() in ["mp3", "m4a", "flac", "wav"]
    if is_audio:
        success = download_audio(args.url, args.output, fmt=args.format.lower(), quality=args.quality)
    else:
        success = download_video(args.url, args.output, quality=args.quality)

    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
