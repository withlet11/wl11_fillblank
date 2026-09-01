// Copyright 2026 WITHLET11 <withlet11@gmail.com>
// SPDX-License-Identifier: MIT

import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.stopped;

  TtsState get state => _state;

  Function()? onStart;
  Function()? onComplete;
  Function(String)? onError;

  Future<void> initTts({
    String language = 'en-US',
    double volume = 1.0,
    double pitch = 1.0,
    double rate = 0.5, // 0.0 to 1.0 (0.5 is normal speed)
  }) async {
    await _flutterTts.setLanguage(language);
    await _flutterTts.setVolume(volume);
    await _flutterTts.setPitch(pitch);
    await _flutterTts.setSpeechRate(rate);

    // iOS specific audio category setup
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      ],
    );

    // Handlers for state changes
    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      onComplete?.call();
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
      onComplete?.call();
    });

    _flutterTts.setPauseHandler(() {
      _state = TtsState.stopped;
      onComplete?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      onError?.call(msg);
      onComplete?.call();
    });
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _state = TtsState.stopped;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _state = TtsState.paused;
  }

  void dispose() {
    _flutterTts.stop();
  }
}