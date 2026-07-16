import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Layer 1 (passive) step reads — doc §2.4.
///
/// Reads today's authoritative step total from HealthKit / Health Connect.
/// NO GPS and NO location permission. Every call is time-bounded so a stuck
/// platform request can never hang the app; on any failure it returns null and
/// the caller falls back to the simulator.
class HealthService {
  final Health _health = Health();
  bool _configured = false;
  bool _authorized = false;

  Future<bool> _ensureConfigured() async {
    if (_configured) return true;
    try {
      await _health.configure().timeout(const Duration(seconds: 10));
      _configured = true;
      return true;
    } catch (e) {
      debugPrint('Health.configure() failed: $e');
      return false;
    }
  }

  /// Request step permission once. Returns true if granted. Safe to call from
  /// an explicit "Connect" action; time-bounded so it can't hang.
  Future<bool> requestPermission() async {
    try {
      if (!await _ensureConfigured()) return false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await Permission.activityRecognition
              .request()
              .timeout(const Duration(seconds: 15));
        } catch (_) {/* ignore */}
      }
      final granted = await _health
          .requestAuthorization(
            [HealthDataType.STEPS],
            permissions: [HealthDataAccess.READ],
          )
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
      _authorized = granted;
      return granted;
    } catch (e) {
      debugPrint('requestPermission() failed: $e');
      return false;
    }
  }

  /// Today's cumulative steps, or null if health data can't be read.
  /// Does NOT prompt for permission unless it hasn't been granted yet.
  Future<int?> getTodaySteps() async {
    try {
      if (!await _ensureConfigured()) return null;
      if (!_authorized) {
        final granted = await requestPermission();
        if (!granted) return null;
      }
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      return await _health
          .getTotalStepsInInterval(midnight, now)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
    } catch (e) {
      debugPrint('getTodaySteps() failed, falling back to simulator: $e');
      return null;
    }
  }
}
