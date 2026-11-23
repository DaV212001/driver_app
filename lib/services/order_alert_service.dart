import 'dart:async';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player_plus/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Centralized service responsible for managing ringing sounds and vibrations
/// when notifications and job offers come in for delivery orders.
class OrderAlertService {
  OrderAlertService._();
  static final OrderAlertService instance = OrderAlertService._();

  final Logger _logger = Logger();

  static const String _prefSoundKey = 'driver_order_sound_enabled';
  static const String _prefVibrationKey = 'driver_order_vibration_enabled';
  static const String orderAlertChannelKey = 'driver_order_alerts';
  static const int orderAlertNotificationId = 8888;
  static const MethodChannel _alertChannel = MethodChannel('com.amn.driver_app/alert');

  final RxBool isRinging = false.obs;
  final RxBool soundEnabled = true.obs;
  final RxBool vibrationEnabled = true.obs;

  Timer? _vibrationFallbackTimer;
  Timer? _autoStopTimer;

  bool _initialized = false;

  /// Initialize persistent sound/vibration preferences
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (!Get.testMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
        final prefs = await SharedPreferences.getInstance();
        soundEnabled.value = prefs.getBool(_prefSoundKey) ?? true;
        vibrationEnabled.value = prefs.getBool(_prefVibrationKey) ?? true;
      }
      _initialized = true;
    } catch (e) {
      _logger.w('OrderAlertService preferences init warning: $e');
    }
  }

  /// Start playing the phone ringing sound and rhythmically vibrating
  /// when an incoming order notification or job offer appears.
  Future<void> startRinging({Duration? autoStopAfter}) async {
    final stopDuration = autoStopAfter ?? const Duration(seconds: 120);

    // Refresh auto-stop timer
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(stopDuration, stopRinging);

    if (isRinging.value) return;
    isRinging.value = true;
    _logger.i('🔔 Starting Order Alert: Phone Ringtone & Vibration');

    // Skip native hardware interaction in test mode
    if (Get.testMode || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    // 1. Play phone ringtone
    if (soundEnabled.value) {
      try {
        await FlutterRingtonePlayer().playRingtone(
          looping: true,
          asAlarm: true,
        );
      } catch (e) {
        _logger.w('Primary ringtone failed, trying notification sound fallback: $e');
        try {
          await FlutterRingtonePlayer().playNotification(
            looping: true,
            asAlarm: true,
          );
        } catch (err) {
          _logger.e('Failed to play alert sound: $err');
        }
      }
    }

    // 2. Hardware vibration (phone ringing pulse pattern: wait 0ms, buzz 1000ms, pause 600ms, repeat)
    if (vibrationEnabled.value) {
      try {
        // Immediate haptic touch response
        HapticFeedback.heavyImpact();

        final hasVibe = await Vibration.hasVibrator();
        if (hasVibe) {
          final hasCustom = await Vibration.hasCustomVibrationsSupport();
          if (hasCustom) {
            // Repeat index 0: loops continuously until cancel()
            await Vibration.vibrate(
              pattern: [0, 1000, 600, 1000, 600, 1000, 600, 1000],
              repeat: 0,
            );
          } else {
            // Fallback for devices without custom vibration patterns: periodic pulses
            _vibrationFallbackTimer?.cancel();
            await Vibration.vibrate(duration: 900);
            _vibrationFallbackTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) async {
              if (isRinging.value && vibrationEnabled.value) {
                await Vibration.vibrate(duration: 900);
              }
            });
          }
        }
      } catch (e) {
        _logger.w('Device vibration exception (might be running in simulator or desktop): $e');
      }
    }
  }

  /// Stop ringing sound and cancel hardware vibration immediately.
  /// Unconditionally silences hardware, native audio players across isolates,
  /// and cancels active order alert notifications.
  Future<void> stopRinging() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _vibrationFallbackTimer?.cancel();
    _vibrationFallbackTimer = null;

    isRinging.value = false;
    _logger.i('🔕 Stopped Order Alert');

    if (Get.testMode || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    // 1. Stop Flutter ringtone player
    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      _logger.d('Stop sound notice: $e');
    }

    // 2. Stop vibration
    try {
      await Vibration.cancel();
    } catch (e) {
      _logger.d('Stop vibration notice: $e');
    }

    // 3. Cancel active order notifications in the system tray
    try {
      await AwesomeNotifications().cancelNotificationsByChannelKey(orderAlertChannelKey);
      await AwesomeNotifications().cancel(orderAlertNotificationId);
    } catch (e) {
      _logger.d('Cancel notification notice: $e');
    }

    // 4. Force native audio focus reset to silence any background isolate MediaPlayer
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _alertChannel.invokeMethod('stopRingtone');
      } catch (_) {}
    }
  }

  /// Toggle or set sound preference
  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSoundKey, enabled);
    } catch (_) {}

    if (!enabled && isRinging.value) {
      try {
        await FlutterRingtonePlayer().stop();
      } catch (_) {}
    }
  }

  /// Toggle or set vibration preference
  Future<void> setVibrationEnabled(bool enabled) async {
    vibrationEnabled.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefVibrationKey, enabled);
    } catch (_) {}

    if (!enabled && isRinging.value) {
      _vibrationFallbackTimer?.cancel();
      try {
        await Vibration.cancel();
      } catch (_) {}
    }
  }

  /// Plays a short 3-second preview ring and vibration for user verification in Settings
  Future<void> testAlert() async {
    await stopRinging();
    await startRinging(autoStopAfter: const Duration(seconds: 3));
  }
}
