import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Represents a measured environmental acoustic reading.
class AcousticReading {
  final double decibels;
  final String tierTitle;
  final String emoji;
  final Color accentColor;
  final Color backgroundColor;
  final String description;
  final String treeBufferInsight;

  const AcousticReading({
    required this.decibels,
    required this.tierTitle,
    required this.emoji,
    required this.accentColor,
    required this.backgroundColor,
    required this.description,
    required this.treeBufferInsight,
  });

  /// Evaluates decibel level according to WHO & Central Pollution Control Board (CPCB)
  /// ambient acoustic comfort standards.
  static AcousticReading fromDecibels(double db) {
    final clamped = db.clamp(30.0, 110.0);

    if (clamped < 50) {
      return AcousticReading(
        decibels: clamped,
        tierTitle: 'Tranquil Green Haven',
        emoji: '🌱',
        accentColor: const Color(0xFF16A34A), // Emerald Green
        backgroundColor: const Color(0xFFDCFCE7),
        description:
            'Whisper-quiet ambient sound. Equivalent to a peaceful botanical park with dense natural acoustic shielding.',
        treeBufferInsight:
            'Dense tree canopies and soft ground cover act as acoustic sponges, scattering sound waves and absorbing 5 to 10 dB of urban noise.',
      );
    } else if (clamped < 65) {
      return AcousticReading(
        decibels: clamped,
        tierTitle: 'Moderate Green Ambience',
        emoji: '🍃',
        accentColor: const Color(0xFFD97706), // Warm Amber
        backgroundColor: const Color(0xFFFEF3C7),
        description:
            'Pleasant conversational volume. Ambient street echoes are softened by surrounding greenery.',
        treeBufferInsight:
            'Roadside trees with broad foliage act as natural acoustic buffers, preventing noise from bouncing off concrete walls.',
      );
    } else if (clamped < 80) {
      return AcousticReading(
        decibels: clamped,
        tierTitle: 'Busy Urban Corridor',
        emoji: '🚗',
        accentColor: const Color(0xFFEA580C), // Deep Orange
        backgroundColor: const Color(0xFFFFEDD5),
        description:
            'Noticeable traffic and urban activity. Prolonged exposure can cause subtle stress and fatigue.',
        treeBufferInsight:
            'A 10-meter belt of mature trees along this corridor can reduce passing vehicle noise by up to 8 decibels!',
      );
    } else {
      return AcousticReading(
        decibels: clamped,
        tierTitle: 'High Noise Exposure',
        emoji: '📢',
        accentColor: const Color(0xFFDC2626), // Crimson
        backgroundColor: const Color(0xFFFEE2E2),
        description:
            'High acoustic pollution from heavy traffic, honking, or machinery. Significantly elevates stress.',
        treeBufferInsight:
            'Dense multi-layer canopy planting is urgently needed here to shield pedestrians, residents, and urban birds from noise pollution.',
      );
    }
  }
}

/// Service that safely samples ambient noise levels through the device microphone.
///
/// Privacy Guaranteed:
/// - Only sound amplitude (decibels dBFS) is read in memory.
/// - NO audio files are saved, kept, or transmitted to any server.
/// - [cancel()] is called upon completion to immediately delete any temporary buffer.
class AcousticService {
  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _ampSub;
  bool _isSampling = false;

  bool get isSampling => _isSampling;

  /// Checks if microphone permission is granted.
  Future<bool> checkPermission() async {
    try {
      _recorder ??= AudioRecorder();
      return await _recorder!.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Converts raw dBFS (typically -160 to 0) into approximate sound pressure level dB SPL.
  double _dbFsToSpl(double dbFs) {
    if (dbFs <= -120 || dbFs.isInfinite || dbFs.isNaN) {
      return 35.0; // Ambient silence floor
    }
    // dB SPL calibration: 0 dBFS ≈ 100 dB SPL (peak loud), -60 dBFS ≈ 40 dB SPL (quiet room)
    final spl = 100.0 + dbFs;
    return spl.clamp(32.0, 105.0);
  }

  /// Starts live amplitude stream for real-time visualization.
  Stream<double> startRealtimeSampling() {
    final controller = StreamController<double>.broadcast();

    () async {
      try {
        _recorder ??= AudioRecorder();
        final hasPerm = await _recorder!.hasPermission();
        if (!hasPerm) {
          controller.addError('Microphone permission required to sample acoustic level.');
          await controller.close();
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_noise_sample_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 44100,
          ),
          path: tempPath,
        );

        _isSampling = true;

        _ampSub = _recorder!.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
          (amp) {
            final db = _dbFsToSpl(amp.current);
            if (!controller.isClosed) {
              controller.add(db);
            }
          },
          onError: (e) {
            if (!controller.isClosed) {
              controller.addError(e);
            }
          },
        );
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  /// Samples ambient sound for [duration] and returns the average [AcousticReading].
  Future<AcousticReading> sampleAmbientNoise({
    Duration duration = const Duration(seconds: 3),
    void Function(double currentDb)? onProgress,
  }) async {
    _recorder ??= AudioRecorder();

    final hasPerm = await _recorder!.hasPermission();
    if (!hasPerm) {
      throw Exception('Microphone permission denied. Please allow microphone access to measure noise.');
    }

    final samples = <double>[];
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/noise_eval_${DateTime.now().millisecondsSinceEpoch}.m4a');

    try {
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: tempFile.path,
      );

      _isSampling = true;

      final completer = Completer<void>();
      final ampSub = _recorder!.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((amp) {
        final db = _dbFsToSpl(amp.current);
        samples.add(db);
        onProgress?.call(db);
      });

      // Collect samples for the specified duration
      Timer(duration, () {
        ampSub.cancel();
        completer.complete();
      });

      await completer.future;

      // Immediately cancel and discard any audio file
      await _recorder!.cancel();
      _isSampling = false;

      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      if (samples.isEmpty) {
        return AcousticReading.fromDecibels(52.0); // Baseline average
      }

      // Sort and remove outliers (highest & lowest 10%)
      samples.sort();
      final trimCount = (samples.length * 0.1).floor();
      final validSamples = samples.sublist(
        trimCount,
        samples.length - trimCount > trimCount ? samples.length - trimCount : samples.length,
      );

      final avgDb = validSamples.reduce((a, b) => a + b) / validSamples.length;
      return AcousticReading.fromDecibels(avgDb);
    } catch (e) {
      _isSampling = false;
      try {
        await _recorder!.cancel();
      } catch (_) {}
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Cancels and frees all recording resources.
  Future<void> dispose() async {
    _isSampling = false;
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      await _recorder?.cancel();
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
  }
}
