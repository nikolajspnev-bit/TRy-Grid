import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Kachel mit Filmkorn, wird einmal beim Start erzeugt.
ui.Image? _grainTile;

Future<void> prepareGrain() async {
  if (_grainTile != null) return;
  const n = 256;
  final rnd = math.Random(7);
  final px = Uint8List(n * n * 4);
  for (var i = 0; i < n * n; i++) {
    // Summe aus drei Zufallswerten ergibt weiches, natürliches Rauschen um Mittelgrau.
    final g = (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble()) / 3;
    final v = (128 + (g - 0.5) * 2 * 110).round().clamp(0, 255);
    px[i * 4] = v;
    px[i * 4 + 1] = v;
    px[i * 4 + 2] = v;
    px[i * 4 + 3] = 255;
  }
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, c.complete);
  _grainTile = await c.future;
}

/// Zeichnet die Collage. Wird für die Vorschau UND den Export benutzt,
/// damit das Ergebnis genau so aussieht wie auf dem Bildschirm.
void paintCollage(
  Canvas canvas,
  Size size,
  Design d, {
  required ui.Image? Function(int index) imageFor,
  bool preview = false,
  bool original = false,
  int? dragFrom,
  int? dragTarget,
}) {
  final unit = size.width / 400;
  canvas.drawRect(Offset.zero & size, Paint()..color = d.background);
  final frames = cellFrames(
    d.normalizedRects,
    size,
    d.border * unit,
    d.spacing * unit,
  );
  final radius = d.corners * unit;
  final look = original ? null : d.look;

  for (var i = 0; i < frames.length; i++) {
    final f = frames[i];
    if (f.isEmpty) continue;
    final r = math.min(radius, math.min(f.width, f.height) / 2);
    final rrect = RRect.fromRectAndRadius(f, Radius.circular(r));
    final slot = d.slots[i];
    final img = slot == null ? null : imageFor(i);

    canvas.save();
    canvas.clipRRect(rrect);
    if (slot != null && img != null) {
      final dst = imageRect(
        slot.photo.width,
        slot.photo.height,
        f,
        slot.zoom,
        slot.offsetX,
        slot.offsetY,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      if (preview && dragFrom == i) {
        canvas.saveLayer(f, Paint()..color = const Color(0x66FFFFFF));
      }
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.high,
      );
      if (look != null && look.active) {
        _paintLook(canvas, img, src, dst, f, look, unit);
      }
      if (preview && dragFrom == i) canvas.restore();
    } else if (preview) {
      _paintEmpty(canvas, f, i);
    }
    canvas.restore();

    if (preview && dragTarget == i && dragFrom != i) {
      canvas.drawRRect(
        rrect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent,
      );
    }
  }
}

/// Halation, Black Mist und Körnung über ein Foto legen.
void _paintLook(
  Canvas canvas,
  ui.Image img,
  Rect src,
  Rect dst,
  Rect cell,
  FilmLook look,
  double unit,
) {
  // Black Mist: weichgezeichnete Kopie aufhellend darüber.
  // Hebt die Schatten an und lässt Lichter weich leuchten.
  if (look.mist > 0) {
    final s = 8 * unit;
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: s,
          sigmaY: s,
          tileMode: TileMode.clamp,
        )
        ..blendMode = BlendMode.screen
        ..color = Color.fromRGBO(255, 255, 255, (look.mist * 0.6).clamp(0, 1)),
    );
  }

  // Halation: nur die hellsten Stellen, rot-orange eingefärbt und weichgezeichnet.
  if (look.halation > 0) {
    const t = 0.6; // ab welcher Helligkeit es leuchtet
    final k = 2.6 + look.halation * 1.6;
    List<double> row(double tint) => [
      0.3 * k * tint,
      0.59 * k * tint,
      0.11 * k * tint,
      0,
      -k * t * 255 * tint,
    ];
    final matrix = <double>[
      ...row(1.0),
      ...row(0.32),
      ...row(0.08),
      0,
      0,
      0,
      1,
      0,
    ];
    final s = (2 + look.halation * 3) * unit;
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()
        ..colorFilter = ColorFilter.matrix(matrix)
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: s,
          sigmaY: s,
          tileMode: TileMode.decal,
        )
        ..blendMode = BlendMode.screen
        ..color = Color.fromRGBO(255, 255, 255, look.halation.clamp(0, 1)),
    );
  }

  // Körnung: Rauschkachel, im Modus Ineinanderkopieren.
  final tile = _grainTile;
  if (look.grain > 0 && tile != null) {
    final scale = math.max(unit * 0.55, 0.6);
    final m = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[15] = 1;
    canvas.drawRect(
      cell,
      Paint()
        ..shader = ImageShader(tile, TileMode.repeated, TileMode.repeated, m)
        ..blendMode = BlendMode.overlay
        ..color = Color.fromRGBO(255, 255, 255, (look.grain * 0.9).clamp(0, 1)),
    );
  }
}

void _paintEmpty(Canvas canvas, Rect f, int i) {
  canvas.drawRect(f, Paint()..color = AppColors.empty);
  final tp = TextPainter(
    text: TextSpan(
      text: '${(i + 1).toString().padLeft(2, '0')} +',
      style: const TextStyle(
        fontFamily: kMono,
        fontSize: 11,
        color: AppColors.muted,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, f.center - Offset(tp.width / 2, tp.height / 2));
}

class CollagePainter extends CustomPainter {
  CollagePainter(
    this.design, {
    this.dragFrom,
    this.dragTarget,
    this.activeSeam,
    this.original = false,
  });
  final Design design;
  final int? dragFrom;
  final int? dragTarget;
  final Seam? activeSeam;
  final bool original;

  @override
  void paint(Canvas canvas, Size size) {
    paintCollage(
      canvas,
      size,
      design,
      imageFor: (i) => design.slots[i]?.photo.preview,
      preview: true,
      original: original,
      dragFrom: dragFrom,
      dragTarget: dragTarget,
    );
    if (dragFrom == null) _paintHandles(canvas, size);
    if (activeSeam != null) _paintPixelLabels(canvas, size);
  }

  /// Kleine Griffe auf den Trennlinien, an denen man ziehen kann.
  void _paintHandles(Canvas canvas, Size size) {
    final border = design.border * size.width / 400;
    final seams = findSeams(design.normalizedRects);
    // Die gezogene Linie finden (gleiche Richtung, nächste Position).
    final active = activeSeam;
    Seam? hot;
    if (active != null) {
      var best = double.infinity;
      for (final s in seams) {
        if (s.vertical != active.vertical ||
            s.start >= active.end ||
            s.end <= active.start) {
          continue;
        }
        final dist = (s.pos - active.pos).abs();
        if (dist < best) {
          best = dist;
          hot = s;
        }
      }
    }
    for (final s in seams) {
      final isActive = identical(s, hot);
      final m = seamOnCanvas(s, size, border).mid;
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: m,
          width: s.vertical ? 5 : 24,
          height: s.vertical ? 24 : 5,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        pill.inflate(1.5),
        Paint()..color = const Color(0xCC000000),
      );
      canvas.drawRRect(
        pill,
        Paint()..color = isActive ? AppColors.accent : const Color(0xFFBDBAB4),
      );
    }
  }

  /// Beim Ziehen: Größe jedes Feldes in Pixeln (bezogen auf den 4K Export).
  void _paintPixelLabels(Canvas canvas, Size size) {
    final out = design.format.exportSize(uhd: true);
    final ou = out.width / 400;
    final real = cellFrames(
      design.normalizedRects,
      out,
      design.border * ou,
      design.spacing * ou,
    );
    final u = size.width / 400;
    final shown = cellFrames(
      design.normalizedRects,
      size,
      design.border * u,
      design.spacing * u,
    );
    for (var i = 0; i < shown.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${real[i].width.round()} × ${real[i].height.round()}',
          style: const TextStyle(
            fontFamily: kMono,
            fontSize: 10,
            color: AppColors.text,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromCenter(
        center: shown[i].center,
        width: tp.width + 10,
        height: tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        Paint()..color = const Color(0xCC000000),
      );
      tp.paint(canvas, box.topLeft + const Offset(5, 3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Erstellt das fertige Bild als PNG in der Größe [size].
Future<Uint8List> exportCollage(Design d, Size size) async {
  await prepareGrain();
  final unit = size.width / 400;
  final frames = cellFrames(
    d.normalizedRects,
    size,
    d.border * unit,
    d.spacing * unit,
  );

  // Jedes Foto nur so groß dekodieren, wie es im Export gebraucht wird.
  final images = <int, ui.Image>{};
  for (var i = 0; i < frames.length; i++) {
    final slot = d.slots[i];
    if (slot == null || frames[i].isEmpty) continue;
    final dst = imageRect(
      slot.photo.width,
      slot.photo.height,
      frames[i],
      slot.zoom,
      slot.offsetX,
      slot.offsetY,
    );
    final needed = math.max(dst.width, dst.height).ceil();
    final codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(slot.photo.bytes),
      getTargetSize: (w, h) {
        final longSide = math.max(w, h);
        if (needed >= longSide) return ui.TargetImageSize(width: w, height: h);
        return w >= h
            ? ui.TargetImageSize(width: needed)
            : ui.TargetImageSize(height: needed);
      },
    );
    images[i] = (await codec.getNextFrame()).image;
    codec.dispose();
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  paintCollage(canvas, size, d, imageFor: (i) => images[i]);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  for (final img in images.values) {
    img.dispose();
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
