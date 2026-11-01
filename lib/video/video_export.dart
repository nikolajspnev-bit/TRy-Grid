import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models.dart';
import '../painter.dart';
import 'video_native.dart';

/// Rendert die Collage als MP4 (1080p, 30 Bilder pro Sekunde, ohne Ton).
/// Kürzere Videos laufen in Schleife, Fotos bleiben stehen.
Future<String> exportVideoCollage(
  Design d, {
  required double seconds,
  required String outPath,
  void Function(double progress)? onProgress,
}) async {
  await prepareGrain();
  final base = d.canvasSize(uhd: false);
  // Video Encoder brauchen gerade Zahlen.
  final w = base.width.round() & ~1;
  final h = base.height.round() & ~1;
  final size = ui.Size(w.toDouble(), h.toDouble());
  final unit = size.width / 400;
  final frames = cellFrames(d.normalizedRects, size, d.border * unit, d.spacing * unit);

  final stills = <int, ui.Image>{};
  final readers = <int, int>{};
  try {
    for (var i = 0; i < frames.length; i++) {
      final slot = d.slots[i];
      if (slot == null || frames[i].isEmpty) continue;
      final v = slot.photo.video;
      if (v != null) {
        readers[i] = await VideoNative.openReader(v.path, neededSide(slot, frames[i]));
      } else {
        stills[i] = await decodeForExport(slot, frames[i]);
      }
    }

    const fps = 30;
    final total = (seconds * fps).round().clamp(1, 60 * fps);
    await VideoNative.startEncoder(outPath, w, h, fps: fps);
    for (var f = 0; f < total; f++) {
      final t = f * 1000 ~/ fps;
      final moving = <int, ui.Image>{};
      for (final e in readers.entries) {
        final slot = d.slots[e.key]!;
        final v = slot.photo.video!;
        final clip = (v.durationMs - slot.videoStartMs).clamp(1, 1 << 30);
        moving[e.key] = await VideoNative.frame(e.value, slot.videoStartMs + t % clip);
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Offset.zero & size);
      paintCollage(canvas, size, d, imageFor: (i) => moving[i] ?? stills[i], grainSeed: f);
      final picture = recorder.endRecording();
      final image = await picture.toImage(w, h);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      for (final img in moving.values) {
        img.dispose();
      }
      await VideoNative.addFrame(Uint8List.view(data!.buffer));
      onProgress?.call((f + 1) / total);
    }
    return await VideoNative.finishEncoder();
  } finally {
    for (final id in readers.values) {
      await VideoNative.closeReader(id);
    }
    for (final img in stills.values) {
      img.dispose();
    }
  }
}

/// Längstes Video in der Collage (ab Startpunkt), in Sekunden.
double longestClipSeconds(Design d) {
  var best = 0;
  for (final s in d.slots) {
    final v = s?.photo.video;
    if (s == null || v == null) continue;
    final len = v.durationMs - s.videoStartMs;
    if (len > best) best = len;
  }
  return best / 1000;
}
