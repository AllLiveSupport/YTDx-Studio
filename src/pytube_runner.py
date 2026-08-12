import sys
import os
import argparse
import time
import subprocess
import re
import requests
from pytubefix import YouTube
from PIL import Image
import mutagen
from mutagen.id3 import ID3, APIC, TIT2, TPE1, TALB

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

def sanitize_filename(name):
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def download_audio(url, output_dir, fmt="mp3", quality="320k"):
    try:
        print(f"[status] Pytubefix video bilgileri alınıyor...", flush=True)
        yt = YouTube(url, on_progress_callback=progress_callback)
        title = sanitize_filename(yt.title)
        
        # Audio stream
        audio_stream = yt.streams.get_audio_only()
        if not audio_stream:
            print("[error] Ses akışı bulunamadı.", flush=True)
            return False

        print(f"[status] Ses akışı indiriliyor: {yt.title}", flush=True)
        raw_file = audio_stream.download(output_path=output_dir, filename=f"{title}_temp.m4a")

        final_path = os.path.join(output_dir, f"{title}.{fmt}")
        if os.path.exists(final_path):
            try: os.remove(final_path)
            except: pass

        if fmt == "mp3":
            print(f"[status] FFmpeg ile yüksek kalite MP3 dönüştürülüyor...", flush=True)
            cmd = [
                "ffmpeg", "-y", "-i", raw_file,
                "-vn", "-ar", "44100", "-ac", "2",
                "-b:a", "320k",
                final_path
            ]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            try: os.remove(raw_file)
            except: pass

            # Embed thumbnail & metadata
            try:
                if yt.thumbnail_url:
                    thumb_res = requests.get(yt.thumbnail_url, timeout=10)
                    if thumb_res.status_code == 200:
                        audio = ID3(final_path)
                        audio.add(APIC(encoding=3, mime='image/jpeg', type=3, desc='Cover', data=thumb_res.content))
                        audio.add(TIT2(encoding=3, text=yt.title))
                        audio.add(TPE1(encoding=3, text=yt.author))
                        audio.save(v2_version=3)
            except Exception as e:
                pass
        else:
            # m4a
            os.rename(raw_file, final_path)

        print("[download] 100.0% of finished successfully!", flush=True)
        return True
    except Exception as e:
        print(f"[error] Pytubefix ses indirme hatası: {e}", flush=True)
        return False

def download_video(url, output_dir, quality="auto"):
    try:
        print(f"[status] Pytubefix video bilgileri alınıyor...", flush=True)
        yt = YouTube(url, on_progress_callback=progress_callback)
        title = sanitize_filename(yt.title)

        video_stream = None
        if quality != "auto" and quality.isNotEmpty if hasattr(quality, 'isNotEmpty') else bool(quality and quality != "auto"):
            res_str = str(quality).replace("p", "").strip() + "p"
            # Try specific video stream
            video_stream = yt.streams.filter(res=res_str, only_video=True).first()
            if not video_stream:
                video_stream = yt.streams.filter(res=res_str).first()

        if not video_stream:
            # Get the ABSOLUTE HIGHEST video resolution (4320p, 2160p, 1440p, 1080p, 720p)
            video_streams = yt.streams.filter(only_video=True).order_by('resolution').desc()
            if video_streams and len(video_streams) > 0:
                # Prefer mp4 container if available
                mp4_streams = [s for s in video_streams if s.mime_type == 'video/mp4']
                video_stream = mp4_streams[0] if mp4_streams else video_streams.first()
            else:
                video_stream = yt.streams.get_highest_resolution()

        if not video_stream:
            print("[error] Uygun video akışı bulunamadı.", flush=True)
            return False

        print(f"[status] En yüksek kalite video indiriliyor ({video_stream.resolution}): {yt.title}", flush=True)

        if getattr(video_stream, 'is_progressive', False):
            final_file = video_stream.download(output_path=output_dir, filename=f"{title}.mp4")
        else:
            # Download video stream
            temp_vid = video_stream.download(output_path=output_dir, filename=f"{title}_vtemp.mp4")

            # Download audio stream
            audio_stream = yt.streams.get_audio_only()
            temp_aud = audio_stream.download(output_path=output_dir, filename=f"{title}_atemp.m4a") if audio_stream else None

            final_path = os.path.join(output_dir, f"{title}.mp4")
            if os.path.exists(final_path):
                try: os.remove(final_path)
                except: pass

            if temp_aud and os.path.exists(temp_aud):
                print(f"[status] FFmpeg ile yüksek kalite ses ve video birleştiriliyor ({video_stream.resolution})...", flush=True)
                cmd = [
                    "ffmpeg", "-y",
                    "-i", temp_vid,
                    "-i", temp_aud,
                    "-c:v", "copy",
                    "-c:a", "aac",
                    "-b:a", "192k",
                    final_path
                ]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                try: os.remove(temp_vid)
                except: pass
                try: os.remove(temp_aud)
                except: pass
            else:
                os.rename(temp_vid, final_path)

        print("[download] 100.0% of finished successfully!", flush=True)
        return True
    except Exception as e:
        print(f"[error] Pytubefix video indirme hatası: {e}", flush=True)
        return False

def main():
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
