import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/download_task.dart';

enum CustomPlayerState { stopped, playing, paused }

class PlayerProvider extends ChangeNotifier {
  Process? _nativeProcess;
  Timer? _posTicker;
  int _currentPlaybackSessionId = 0;

  DownloadTask? _currentTask;
  CustomPlayerState _playerState = CustomPlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 0.85;
  bool _isLooping = false;
  bool _isVisible = false;

  PlayerProvider() {
    // Kill any orphaned audio processes on app startup
    cleanupAllAudioProcesses();

    // Hook OS termination signals on Linux/macOS
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        ProcessSignal.sigint.watch().listen((_) => cleanupAllAudioProcesses());
        ProcessSignal.sigterm.watch().listen((_) => cleanupAllAudioProcesses());
      } catch (_) {}
    }
  }

  /// Kills any lingering ffplay or mpv playback processes
  static void cleanupAllAudioProcesses() {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        Process.runSync('killall', ['-9', 'ffplay']);
      } else if (Platform.isWindows) {
        Process.runSync('taskkill', ['/F', '/IM', 'ffplay.exe']);
      }
    } catch (_) {}
  }

  DownloadTask? get currentTask => _currentTask;
  CustomPlayerState get playerState => _playerState;
  bool get isPlaying => _playerState == CustomPlayerState.playing;
  bool get isPaused => _playerState == CustomPlayerState.paused;
  bool get isVisible => _isVisible && _currentTask != null;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get isLooping => _isLooping;

  Future<void> playTask(DownloadTask task, {Duration? startPosition}) async {
    if (task.filePath == null || !File(task.filePath!).existsSync()) {
      return;
    }

    _currentTask = task;
    _isVisible = true;
    _position = startPosition ?? Duration.zero;

    // Parse duration from video metadata as initial duration
    if (task.video.duration.isNotEmpty) {
      final parts = task.video.duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      if (parts.length == 2) {
        _duration = Duration(minutes: parts[0], seconds: parts[1]);
      } else if (parts.length == 3) {
        _duration = Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    }

    notifyListeners();
    _startNativePlayback(File(task.filePath!).absolute.path, _position);
  }

  void _startNativePlayback(String filePath, Duration startPos) {
    _killNativeProcess();
    final sessionId = ++_currentPlaybackSessionId;

    _playerState = CustomPlayerState.playing;
    _position = startPos;
    notifyListeners();

    try {
      final startSec = startPos.inSeconds;
      final volInt = (_volume * 100).toInt().clamp(0, 100);

      // Start ffplay with stats output on stderr
      Process.start(
        'ffplay',
        [
          '-nodisp',
          '-autoexit',
          '-stats',
          if (startSec > 0) ...['-ss', '$startSec'],
          '-volume', '$volInt',
          filePath,
        ],
        mode: ProcessStartMode.normal,
      ).then((proc) {
        if (sessionId != _currentPlaybackSessionId) {
          try { proc.kill(ProcessSignal.sigkill); } catch (_) {}
          return;
        }

        _nativeProcess = proc;
        _startTicker(sessionId);

        // Parse continuous real-time playback position from ffplay stderr
        proc.stderr.transform(utf8.decoder).listen((chunk) {
          if (sessionId != _currentPlaybackSessionId) return;

          final match = RegExp(r'(\d+\.?\d*)\s+M-A:').firstMatch(chunk);
          if (match != null) {
            final secDouble = double.tryParse(match.group(1) ?? '');
            if (secDouble != null && secDouble > 0) {
              _position = Duration(milliseconds: (secDouble * 1000).toInt());
              if (_playerState != CustomPlayerState.playing) {
                _playerState = CustomPlayerState.playing;
              }
              notifyListeners();
            }
          }
        });

        proc.exitCode.then((code) {
          if (sessionId != _currentPlaybackSessionId) return; // Ignore previous killed session!

          _posTicker?.cancel();
          if (_playerState == CustomPlayerState.playing) {
            if (_isLooping && _currentTask != null) {
              playTask(_currentTask!, startPosition: Duration.zero);
            } else {
              _position = _duration > Duration.zero ? _duration : Duration.zero;
              _playerState = CustomPlayerState.stopped;
              notifyListeners();
            }
          }
        });
      }).catchError((_) {
        if (sessionId != _currentPlaybackSessionId) return;
        // Fallback to mpv if ffplay is not found
        Process.start(
          'mpv',
          [
            '--no-video',
            '--really-quiet',
            if (startSec > 0) ...['--start=$startSec'],
            '--volume=$volInt',
            filePath,
          ],
        ).then((proc) {
          if (sessionId != _currentPlaybackSessionId) {
            try { proc.kill(ProcessSignal.sigkill); } catch (_) {}
            return;
          }
          _nativeProcess = proc;
          _startTicker(sessionId);
        }).catchError((_) {});
      });
    } catch (_) {}
  }

  void _startTicker(int sessionId) {
    _posTicker?.cancel();
    _posTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sessionId != _currentPlaybackSessionId) return;

      if (_playerState == CustomPlayerState.playing) {
        _position += const Duration(seconds: 1);
        if (_duration > Duration.zero && _position >= _duration) {
          if (_isLooping && _currentTask != null) {
            playTask(_currentTask!, startPosition: Duration.zero);
          } else {
            _position = _duration;
            _playerState = CustomPlayerState.stopped;
            _killNativeProcess();
          }
        }
        notifyListeners();
      }
    });
  }

  void _killNativeProcess() {
    _posTicker?.cancel();
    try {
      _nativeProcess?.kill(ProcessSignal.sigkill);
    } catch (_) {}
    _nativeProcess = null;
    cleanupAllAudioProcesses();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      // Pause process instantly via SIGSTOP
      if (_nativeProcess != null && (Platform.isLinux || Platform.isMacOS)) {
        try {
          _nativeProcess!.kill(ProcessSignal.sigstop);
          _posTicker?.cancel();
          _playerState = CustomPlayerState.paused;
          notifyListeners();
          return;
        } catch (_) {}
      }
      _killNativeProcess();
      _playerState = CustomPlayerState.paused;
      notifyListeners();
    } else if (isPaused) {
      // Resume process instantly via SIGCONT
      if (_nativeProcess != null && (Platform.isLinux || Platform.isMacOS)) {
        try {
          _nativeProcess!.kill(ProcessSignal.sigcont);
          _startTicker(_currentPlaybackSessionId);
          _playerState = CustomPlayerState.playing;
          notifyListeners();
          return;
        } catch (_) {}
      }
      if (_currentTask?.filePath != null) {
        _startNativePlayback(_currentTask!.filePath!, _position);
      }
    } else if (_currentTask != null) {
      await playTask(_currentTask!);
    }
  }

  Future<void> seek(Duration newPos) async {
    _position = newPos;
    notifyListeners();

    if (_currentTask?.filePath != null && File(_currentTask!.filePath!).existsSync()) {
      _startNativePlayback(_currentTask!.filePath!, newPos);
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    notifyListeners();
    if (isPlaying && _currentTask?.filePath != null) {
      _startNativePlayback(_currentTask!.filePath!, _position);
    }
  }

  void toggleLoop() {
    _isLooping = !_isLooping;
    notifyListeners();
  }

  Future<void> stop() async {
    _killNativeProcess();
    _playerState = CustomPlayerState.stopped;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> closePlayer() async {
    await stop();
    _isVisible = false;
    _currentTask = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _killNativeProcess();
    super.dispose();
  }
}
