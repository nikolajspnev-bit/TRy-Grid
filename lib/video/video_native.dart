import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Infos zu einem Video (Größe so, wie es angezeigt wird).
class VideoProbe {
  VideoProbe(this.width, this.height, this.durationMs);
  final int width;
  final int height;
  final int durationMs;
}

/// Verbindung zu den Video Bausteinen in der App (Android und iPhone).
class VideoNative {
  static const _ch = MethodChannel('try_grid/video');

  static Future<VideoProbe> probe(String path) async {
    final m = (await _ch.invokeMapMethod<String, dynamic>('probe', {'path': path}))!;
    return VideoProbe(
      (m['width'] as num).toInt(),
      (m['height'] as num).toInt(),
      (m['durationMs'] as num).toInt(),
    );
  }

  static Future<int> openReader(String path, int maxSide) async =>
      (await _ch.invokeMethod<int>('openReader', {'path': path, 'maxSide': maxSide}))!;

  static Future<void> closeReader(int id) => _ch.invokeMethod('closeReader', {'id': id});

  /// Ein Bild als ui.Image (der Aufrufer muss es mit dispose() freigeben).
  static Future<ui.Image> frame(int reader, int timeMs) async {
    final m = (await _ch.invokeMapMethod<String, dynamic>('frame', {'id': reader, 'timeMs': timeMs}))!;
    final w = (m['width'] as num).toInt();
    final h = (m['height'] as num).toInt();
    final bytes = m['rgba'] as Uint8List;
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// Einzelbild ohne offenen Reader (z. B. Vorschau beim Startpunkt).
  static Future<ui.Image> frameAt(String path, int timeMs, {int maxSide = 1600}) async {
    final id = await openReader(path, maxSide);
    try {
      return await frame(id, timeMs);
    } finally {
      await closeReader(id);
    }
  }

  static Future<void> startEncoder(String path, int width, int height, {int fps = 30, int bitrate = 12000000}) =>
      _ch.invokeMethod('startEncoder', {
        'path': path,
        'width': width,
        'height': height,
        'fps': fps,
        'bitrate': bitrate,
      });

  static Future<void> addFrame(Uint8List rgba) => _ch.invokeMethod('addFrame', {'rgba': rgba});

  static Future<String> finishEncoder() async => (await _ch.invokeMethod<String>('finishEncoder'))!;
}
