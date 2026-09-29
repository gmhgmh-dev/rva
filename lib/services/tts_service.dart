import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_assistant_state_machine.dart';

/// Service responsible for speech synthesis using `flutter_tts` in Latvian ("lv-LV").
/// Includes safety fallbacks, queued announcements, and a stream for UI display.
class TtsService {
  final FlutterTts _flutterTts;
  final StreamController<String> _spokenTextController = StreamController<String>.broadcast();
  final List<String> _speechQueue = <String>[];
  bool _isSpeaking = false;
  bool _isInitialized = false;

  String? _currentEngine;
  String? _currentVoiceName;
  String? _currentVoiceLocale;
  double _currentSpeechRate = 0.5;
  double _currentPitch = 1.0;
  bool _audioDucking = true;

  TtsService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts();

  Stream<String> get spokenTextStream => _spokenTextController.stream;
  String? get currentEngine => _currentEngine;
  String? get currentVoiceName => _currentVoiceName;
  String? get currentVoiceLocale => _currentVoiceLocale;
  double get currentSpeechRate => _currentSpeechRate;
  double get currentPitch => _currentPitch;
  bool get audioDucking => _audioDucking;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (_currentEngine != null && _currentEngine!.isNotEmpty) {
        try {
          await _flutterTts.setEngine(_currentEngine!);
        } catch (e) {
          debugPrint('TTS setEngine error: $e');
        }
      }

      // Configure Latvian language
      await _flutterTts.setLanguage("lv-LV");
      await _flutterTts.setSpeechRate(_currentSpeechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(_currentPitch);

      if (_currentVoiceName != null && _currentVoiceName!.isNotEmpty) {
        try {
          await _flutterTts.setVoice({
            'name': _currentVoiceName!,
            'locale': _currentVoiceLocale ?? 'lv-LV',
          });
        } catch (e) {
          debugPrint('TTS setVoice error: $e');
        }
      }

      // Configure Audio Ducking & Navigation Audio Attributes (lowers background music/radio volume during speech)
      if (_audioDucking) {
        try {
          await _flutterTts.setAudioAttributesForNavigation();
        } catch (e) {
          debugPrint('TTS setAudioAttributesForNavigation error: $e');
        }

        try {
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.duckOthers,
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            ],
            IosTextToSpeechAudioMode.voicePrompt,
          );
        } catch (e) {
          debugPrint('TTS iOS audio category error: $e');
        }
      }

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _processQueue();
      });

      _flutterTts.setErrorHandler((dynamic message) {
        debugPrint('TTS Error: $message');
        _isSpeaking = false;
        _processQueue();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS init error (mock or unsupported platform): $e');
    }
  }

  /// Dynamically applies new engine, voice, rate, pitch, or ducking settings.
  Future<void> applySettings({
    String? engine,
    String? voiceName,
    String? voiceLocale,
    double? speechRate,
    double? pitch,
    bool? audioDucking,
  }) async {
    if (speechRate != null) _currentSpeechRate = speechRate;
    if (pitch != null) _currentPitch = pitch;
    if (audioDucking != null) _audioDucking = audioDucking;
    _currentVoiceName = voiceName;
    _currentVoiceLocale = voiceLocale;
    final engineChanged = engine != null && engine != _currentEngine;
    if (engine != null) {
      _currentEngine = engine;
    }

    try {
      if (engineChanged && engine.isNotEmpty) {
        try {
          await _flutterTts.setEngine(engine);
        } catch (e) {
          debugPrint('TTS setEngine error: $e');
        }
      }

      await _flutterTts.setLanguage("lv-LV");
      await _flutterTts.setSpeechRate(_currentSpeechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(_currentPitch);

      if (voiceName != null && voiceName.isNotEmpty) {
        try {
          await _flutterTts.setVoice({
            'name': voiceName,
            'locale': voiceLocale ?? 'lv-LV',
          });
        } catch (e) {
          debugPrint('TTS setVoice error: $e');
        }
      }
    } catch (e) {
      debugPrint('TTS applySettings error: $e');
    }
  }

  /// Returns a list of installed TTS engine package names on the device (Android).
  Future<List<String>> getAvailableEngines() async {
    try {
      final dynamic engines = await _flutterTts.getEngines;
      if (engines is List) {
        return engines.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error getting TTS engines: $e');
    }
    return <String>[];
  }

  /// Returns the default TTS engine package name on the device (Android).
  Future<String?> getDefaultEngine() async {
    try {
      final dynamic defaultEngine = await _flutterTts.getDefaultEngine;
      return defaultEngine?.toString();
    } catch (e) {
      debugPrint('Error getting default TTS engine: $e');
      return null;
    }
  }

  /// Returns all available voices for the current TTS engine.
  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final dynamic voices = await _flutterTts.getVoices;
      if (voices is List) {
        final List<Map<String, String>> result = [];
        for (final v in voices) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? '';
            if (name.isNotEmpty || locale.isNotEmpty) {
              result.add({'name': name, 'locale': locale});
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('Error getting TTS voices: $e');
    }
    return <Map<String, String>>[];
  }

  /// Returns voices filtered for Latvian language ("lv", "lav", "latvian").
  Future<List<Map<String, String>>> getLatvianVoices() async {
    final allVoices = await getAvailableVoices();
    return allVoices.where((v) {
      final locale = (v['locale'] ?? '').toLowerCase();
      final name = (v['name'] ?? '').toLowerCase();
      return locale.contains('lv') ||
          locale.contains('lav') ||
          name.contains('latvian') ||
          name.contains('latvie');
    }).toList();
  }

  /// Speaks a test announcement to verify speech engine and voice settings.
  Future<void> testVoice({String? phrase}) async {
    final text = phrase ?? 'Šis ir balss pārbaudes paziņojums. Atļautais ātrums 50 kilometri stundā.';
    await speak(text);
  }

  /// Formats human-readable label for well-known Android TTS engines.
  static String formatEngineName(String enginePackage) {
    switch (enginePackage) {
      case 'com.google.android.tts':
        return 'Google Runas pakalpojumi (Ieteicams)';
      case 'lv.tilde.balss':
        return 'Tildes Balss (Izcila LV kvalitāte)';
      case 'com.samsung.SMT':
        return 'Samsung Runas dzinējs';
      case 'com.rhvoice':
        return 'RHVoice (Atvērtais kods)';
      case 'com.svox.pico':
        return 'SVOX Pico';
      default:
        final parts = enginePackage.split('.');
        if (parts.isNotEmpty) {
          final last = parts.last;
          if (last.isNotEmpty) {
            final capitalized = last[0].toUpperCase() + last.substring(1);
            return '$capitalized ($enginePackage)';
          }
        }
        return enginePackage;
    }
  }

  /// Speaks the given text or enqueues it if already speaking.
  Future<void> speak(String text) async {
    _spokenTextController.add(text);
    _speechQueue.add(text);
    if (!_isSpeaking) {
      _processQueue();
    }
  }

  /// Speaks dynamic street and speed limit announcement:
  /// "Atrodaties uz [street_name]. Atļautais ātrums [max_speed] kilometri stundā."
  Future<void> speakStreetInfo(String? streetName, int maxSpeed) async {
    final text = VoiceAssistantStateMachine.formatStreetAnnouncement(
      streetName: streetName,
      maxSpeed: maxSpeed,
    );
    await speak(text);
  }

  /// Speaks living street zone entry:
  /// "Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā."
  Future<void> speakLivingStreetZone() async {
    await speak(VoiceAssistantStateMachine.formatLivingStreetAnnouncement());
  }

  /// Speaks speed limit zone entry:
  /// "Iebraucāt [speedLimit] kilometru stundā ātruma ierobežojuma zonā."
  Future<void> speakSpeedZone(int speedLimit) async {
    await speak(VoiceAssistantStateMachine.formatSpeedZoneAnnouncement(speedLimit));
  }

  /// Speaks 30 km/h speed zone entry:
  /// "Iebraucāt 30 kilometru stundā ātruma ierobežojuma zonā."
  Future<void> speak30SpeedZone() async {
    await speak(VoiceAssistantStateMachine.formatSpeedZoneAnnouncement(30));
  }

  Future<void> _processQueue() async {
    if (_speechQueue.isEmpty) {
      _isSpeaking = false;
      return;
    }

    _isSpeaking = true;
    final text = _speechQueue.removeAt(0);

    try {
      if (!_isInitialized) {
        await init();
      }
      final result = await _flutterTts.speak(text);
      if (result != 1) {
        // Fallback if TTS engine rejects the text immediately
        _isSpeaking = false;
        _processQueue();
      }
    } catch (e) {
      debugPrint('Error speaking text: $e');
      _isSpeaking = false;
      _processQueue();
    }
  }

  Future<void> stop() async {
    _speechQueue.clear();
    _isSpeaking = false;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  void dispose() {
    _speechQueue.clear();
    _spokenTextController.close();
  }
}
