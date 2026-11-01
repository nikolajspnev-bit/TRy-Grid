import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';
import 'video/video_native.dart';
import 'theme.dart';

/// Kacheln mit Filmkorn (grau und farbig), werden einmal beim Start erzeugt.
ui.Image? _grainMono;
ui.Image? _grainColor;

Future<ui.Image> _noiseTile({required bool color, required int seed}) {
  const n = 256;
  final rnd = math.Random(seed);
  double g() =>
      (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble()) / 3 - 0.5;
  int v(double x) => (128 + x * 2 * 110).round().clamp(0, 255);
  final px = Uint8List(n * n * 4);
  for (var i = 0; i < n * n; i++) {
    final m = g();
    px[i * 4] = v(color ? g() : m);
    px[i * 4 + 1] = v(color ? g() : m);
    px[i * 4 + 2] = v(color ? g() : m);
    px[i * 4 + 3] = 255;
  }
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

Future<void> prepareGrain() async {
  _grainMono ??= await _noiseTile(color: false, seed: 7);
  _grainColor ??= await _noiseTile(color: true, seed: 11);
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
  int grainSeed = 0,
}) {
  final unit = size.width / 400 / (d.carousel ? d.slides : 1);
  canvas.drawRect(Offset.zero & size, Paint()..color = d.background);
  final frames = cellFrames(
    d.normalizedRects,
    size,
    d.border * unit,
    d.spacing * unit,
  );
  final radius = d.corners * unit;

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
      final dim = preview && dragFrom == i;
      if (dim) canvas.saveLayer(f, Paint()..color = const Color(0x66FFFFFF));
      final look = original ? null : (slot.look ?? d.look);
      final matrix = look == null ? null : _baseMatrix(look);
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.high
          ..colorFilter = matrix == null ? null : ColorFilter.matrix(matrix),
      );
      if (look != null && look.active) {
        _paintLook(canvas, img, src, dst, f, look, unit, grainSeed);
      }
      if (dim) canvas.restore();
      if (preview && slot.photo.video != null) {
        _paintVideoBadge(canvas, f, slot);
      }
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

/// Unit bezieht sich immer auf die Breite EINER Slide / eines Bildes,
/// damit Effekte im Karussell genauso stark wirken wie in einer Collage.
void _paintLook(
  Canvas canvas,
  ui.Image img,
  Rect src,
  Rect dst,
  Rect cell,
  FilmLook look,
  double unit,
  int grainSeed,
) {
  // Black Mist: weichgezeichnete Kopie aufhellend darüber und leicht angehobene Schatten.
  if (look.mistOn && look.mistAmount > 0) {
    final s = (3 + look.mistSoftness * 12) * unit;
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
        ..color = Color.fromRGBO(
          255,
          255,
          255,
          (look.mistAmount * 0.65).clamp(0, 1),
        ),
    );
    final lift = look.mistLift * look.mistAmount * 0.16;
    if (lift > 0) {
      canvas.drawRect(
        cell,
        Paint()
          ..blendMode = BlendMode.screen
          ..color = Color.fromRGBO(128, 124, 120, lift.clamp(0, 1)),
      );
    }
  }

  // Halation: nur die hellsten Stellen, rot bis orange eingefärbt und weichgezeichnet.
  if (look.halOn && look.halAmount > 0) {
    final t =
        0.4 + look.halThreshold * 0.55; // ab welcher Helligkeit es leuchtet
    final k = 2.4 + look.halAmount * 3;
    final g = 0.5 - look.halWarmth * 0.36; // Wärme: weniger Grün = röter
    final b = 0.16 - look.halWarmth * 0.13;
    List<double> row(double tint) => [
      0.3 * k * tint,
      0.59 * k * tint,
      0.11 * k * tint,
      0,
      -k * t * 255 * tint,
    ];
    final matrix = <double>[...row(1.0), ...row(g), ...row(b), 0, 0, 0, 1, 0];
    final s = (1.5 + look.halRadius * 10) * unit;
    final a = (look.halAmount * 1.3).clamp(0.0, 1.0);
    // Zwei Schichten: enger Kern und weiter Schein, wie bei echtem Film.
    for (final (sigma, alpha) in [(s, a), (s * 2.6, a * 0.7)]) {
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()
          ..colorFilter = ColorFilter.matrix(matrix)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal)
          ..blendMode = BlendMode.screen
          ..color = Color.fromRGBO(255, 255, 255, alpha),
      );
    }
  }

  // Blitz: heller Lichtfleck auf dem Motiv, Licht fällt nach hinten schnell ab.
  if (look.flashOn && look.flashAmount > 0) {
    final a = look.flashAmount;
    final c = Offset(cell.center.dx, cell.top + cell.height * (0.2 + look.flashHeight * 0.5));
    final diag = math.sqrt(cell.width * cell.width + cell.height * cell.height);
    final reach = diag * (0.75 - look.flashFalloff * 0.4);
    // Lichtfleck: aufhellen mit Ineinanderkopieren (macht auch härter).
    canvas.drawRect(
      cell,
      Paint()
        ..blendMode = BlendMode.overlay
        ..shader = ui.Gradient.radial(
          c,
          reach * 0.7,
          [
            Color.fromRGBO(255, 255, 255, (0.8 * a).clamp(0, 1)),
            const Color.fromRGBO(255, 255, 255, 0),
          ],
        ),
    );
    // Abfall: alles außerhalb wird dunkel, wie bei Blitz in der Nacht.
    canvas.drawRect(
      cell,
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = ui.Gradient.radial(
          c,
          reach,
          [
            const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF0A0A0C), (0.85 * a).clamp(0, 1))!,
          ],
          [0, 0.35, 1],
        ),
    );
  }

  // Vignette: Ränder des Fotos abdunkeln.
  if (look.vigOn && look.vigAmount > 0) {
    final inner = (0.75 - look.vigSoftness * 0.55).clamp(0.05, 0.9);
    canvas.drawRect(
      cell,
      Paint()
        ..shader = ui.Gradient.radial(
          cell.center,
          math.sqrt(cell.width * cell.width + cell.height * cell.height) / 2,
          [
            const Color(0x00000000),
            Color.fromRGBO(0, 0, 0, (look.vigAmount * 0.85).clamp(0, 1)),
          ],
          [inner, 1.0],
        ),
    );
  }

  // Körnung: Rauschkachel im Modus Ineinanderkopieren, grau und farbig gemischt.
  if (look.grainOn && look.grainAmount > 0) {
    final scale = math.max(unit * (0.3 + look.grainSize * 1.2), 0.6);
    // Im Video springt das Korn mit jedem Bild an eine andere Stelle.
    final m = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[15] = 1
      ..[12] = ((grainSeed * 97) % 256) * scale
      ..[13] = ((grainSeed * 61) % 256) * scale;
    void layer(ui.Image? tile, double alpha) {
      if (tile == null || alpha <= 0) return;
      canvas.drawRect(
        cell,
        Paint()
          ..shader = ImageShader(tile, TileMode.repeated, TileMode.repeated, m)
          ..blendMode = BlendMode.overlay
          ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)),
      );
    }

    final a = look.grainAmount * 0.9;
    layer(_grainMono, a * (1 - look.grainColor));
    layer(_grainColor, a * look.grainColor);
  }
}

// Farbmatrizen (4 × 5, wie ColorFilter.matrix).
const _identity = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

List<double> _mix(List<double> m, double t) => [
  for (var i = 0; i < 20; i++) _identity[i] + (m[i] - _identity[i]) * t,
];

/// Erst [a], dann [b] anwenden.
List<double> _then(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 5; c++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += b[r * 5 + k] * a[k * 5 + c];
      }
      if (c == 4) v += b[r * 5 + 4];
      out[r * 5 + c] = v;
    }
  }
  return out;
}

List<double> _saturation(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final i = 1 - s;
  return [
    lr * i + s, lg * i, lb * i, 0, 0,
    lr * i, lg * i + s, lb * i, 0, 0,
    lr * i, lg * i, lb * i + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrast(double c, {double lift = 0}) {
  final o = 128 * (1 - c) + lift;
  return [c, 0, 0, 0, o, 0, c, 0, 0, o, 0, 0, c, 0, o, 0, 0, 0, 1, 0];
}

List<double> _channels(double r, double g, double b, {double ro = 0, double go = 0, double bo = 0}) =>
    [r, 0, 0, 0, ro, 0, g, 0, 0, go, 0, 0, b, 0, bo, 0, 0, 0, 1, 0];

/// Eigene Farbstile für "Film Farben".
List<double> _grade(int style) => switch (style) {
  // Warm: goldene Lichter, etwas weniger Blau.
  0 => _then(_channels(1.07, 1.0, 0.86, ro: 6, go: 2, bo: -2), _saturation(0.95)),
  // Kühl: blaue Schatten, klare Lichter.
  1 => _then(_channels(0.92, 1.0, 1.08, go: 2, bo: 10), _saturation(0.92)),
  // Blass: flacher Kontrast, angehobene Schwärzen, wenig Sättigung.
  2 => _then(_contrast(0.78, lift: 18), _then(_saturation(0.75), _channels(1.02, 1.0, 0.97))),
  // Kino: mehr Kontrast, warme Haut, kühle Tiefen.
  3 => _then(_contrast(1.12), _then(_channels(1.04, 0.99, 0.94, bo: 12), _saturation(0.9))),
  // S/W: Schwarzweiß mit etwas Kontrast.
  _ => _then(_saturation(0), _contrast(1.1)),
};

/// Farbmatrix für das Grundbild (Film Farben und Blitz Kontrast) oder null.
List<double>? _baseMatrix(FilmLook look) {
  List<double>? m;
  if (look.gradeOn && look.gradeAmount > 0) {
    m = _mix(_grade(look.gradeStyle), look.gradeAmount);
  }
  if (look.flashOn && look.flashAmount > 0) {
    final a = look.flashAmount;
    final k = look.flashCool * a;
    final flash = _then(
      _contrast(1 + 0.4 * a),
      _channels(1 - 0.06 * k, 1, 1 + 0.08 * k, bo: 6 * k),
    );
    m = m == null ? flash : _then(m, flash);
  }
  return m;
}

/// Kleine Markierung unten links: dieses Feld ist ein Video (mit Länge).
void _paintVideoBadge(Canvas canvas, Rect f, Slot slot) {
  if (f.width < 50 || f.height < 30) return;
  final secs = ((slot.photo.video!.durationMs - slot.videoStartMs) / 1000).clamp(0, 5999).round();
  final label = '▶ ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(fontFamily: kMono, fontSize: 9, color: AppColors.text),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final box = Rect.fromLTWH(f.left + 6, f.bottom - tp.height - 10, tp.width + 10, tp.height + 4);
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, const Radius.circular(4)),
    Paint()..color = const Color(0xAA000000),
  );
  tp.paint(canvas, box.topLeft + const Offset(5, 2));
}

void _paintEmpty(Canvas canvas, Rect f, int i) {
  canvas.drawRect(f, Paint()..color = AppColors.empty);
  if (f.width < 30 || f.height < 24) return;
  // Feine Plus Markierung in der Mitte.
  final arm = (f.shortestSide * 0.06).clamp(4.0, 9.0);
  final plus = Paint()
    ..color = AppColors.muted
    ..strokeWidth = 1;
  canvas.drawLine(f.center - Offset(arm, 0), f.center + Offset(arm, 0), plus);
  canvas.drawLine(f.center - Offset(0, arm), f.center + Offset(0, arm), plus);
  // Nummer klein in der Ecke.
  if (f.width < 44 || f.height < 36) return;
  final tp = TextPainter(
    text: TextSpan(
      text: (i + 1).toString().padLeft(2, '0'),
      style: const TextStyle(
        fontFamily: kMono,
        fontSize: 9,
        letterSpacing: 1,
        color: AppColors.muted,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, f.topLeft + const Offset(7, 6));
}

class CollagePainter extends CustomPainter {
  CollagePainter(
    this.design, {
    this.fullSize,
    this.scrollX = 0,
    this.mini = false,
    this.dragFrom,
    this.dragTarget,
    this.activeSeam,
    this.snapLine,
    this.original = false,
  });
  final Design design;

  /// Eingerastete Position beim Ziehen: wird als orange Hilfslinie gezeigt.
  final Seam? snapLine;

  /// Größe der ganzen Leinwand, wenn nur ein Ausschnitt gezeigt wird (Karussell).
  final Size? fullSize;
  final double scrollX;

  /// Kleine Übersicht: ohne Griffe und Beschriftung.
  final bool mini;
  final int? dragFrom;
  final int? dragTarget;
  final Seam? activeSeam;
  final bool original;

  @override
  void paint(Canvas canvas, Size size) {
    final full = fullSize ?? size;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-scrollX, 0);
    paintCollage(
      canvas,
      full,
      design,
      imageFor: (i) => design.slots[i]?.shown,
      preview: !mini,
      original: original,
      dragFrom: dragFrom,
      dragTarget: dragTarget,
    );
    if (design.carousel) _paintSlideGuides(canvas, full);
    if (!mini && design.carousel) _paintSlivers(canvas, full);
    if (!mini && snapLine != null) _paintSnap(canvas, full, snapLine!);
    if (!mini && dragFrom == null) _paintHandles(canvas, full);
    if (!mini && activeSeam != null) _paintPixelLabels(canvas, full);
    canvas.restore();
  }

  /// Orange Hilfslinie über die ganze Leinwand, wenn eine Linie einrastet.
  void _paintSnap(Canvas canvas, Size size, Seam s) {
    final border = design.border * _unit(size);
    final full = Seam(vertical: s.vertical, pos: s.pos, start: 0, end: 1);
    final cs = seamOnCanvas(full, size, border);
    canvas.drawLine(
      cs.a,
      cs.b,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1,
    );
  }

  /// Karussell: warnt vor sehr schmalen Streifen an einer Slide Kante.
  /// Die sehen beim Wischen auf Instagram wie ein Fehler aus.
  void _paintSlivers(Canvas canvas, Size size) {
    final u = _unit(size);
    final frames = cellFrames(design.normalizedRects, size, design.border * u, design.spacing * u);
    final n = design.slides;
    final slideW = size.width / n;
    final limit = slideW * 0.06;
    final warn = Paint()..color = AppColors.accent.withValues(alpha: 0.45);
    for (final f in frames) {
      for (var k = 1; k < n; k++) {
        final x = slideW * k;
        if (f.left >= x || f.right <= x) continue;
        if (x - f.left < limit) {
          canvas.drawRect(Rect.fromLTRB(f.left, f.top, x, f.bottom), warn);
        }
        if (f.right - x < limit) {
          canvas.drawRect(Rect.fromLTRB(x, f.top, f.right, f.bottom), warn);
        }
      }
    }
  }

  /// Karussell: gestrichelte Linien, wo eine Slide endet, plus Nummer.
  void _paintSlideGuides(Canvas canvas, Size size) {
    final n = design.slides;
    final line = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = mini ? 1 : 1.2;
    for (var k = 1; k < n; k++) {
      final x = size.width * k / n;
      const dash = 6.0;
      for (var y = 0.0; y < size.height; y += dash * 2) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + dash, size.height)),
          line,
        );
      }
    }
    if (mini) return;
    for (var k = 0; k < n; k++) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${k + 1}/$n',
          style: const TextStyle(
            fontFamily: kMono,
            fontSize: 10,
            color: AppColors.text,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = Rect.fromLTWH(
        size.width * k / n + 6,
        6,
        tp.width + 8,
        tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        Paint()..color = const Color(0xAA000000),
      );
      tp.paint(canvas, box.topLeft + const Offset(4, 2));
    }
  }

  /// Kleine Griffe auf den Trennlinien, an denen man ziehen kann.
  void _paintHandles(Canvas canvas, Size size) {
    final border = design.border * _unit(size);
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
      // Griff: kleiner Ring, beim Ziehen orange gefüllt.
      canvas.drawCircle(m, 7.5, Paint()..color = const Color(0xCC111111));
      canvas.drawCircle(
        m,
        5.5,
        Paint()
          ..style = isActive ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = isActive ? AppColors.accent : AppColors.text,
      );
    }
  }

  double _unit(Size full) =>
      full.width / 400 / (design.carousel ? design.slides : 1);

  /// Beim Ziehen: Größe jedes Feldes in Pixeln (bezogen auf den 4K Export).
  void _paintPixelLabels(Canvas canvas, Size size) {
    final out = design.canvasSize(uhd: true);
    final ou = _unit(out);
    final real = cellFrames(
      design.normalizedRects,
      out,
      design.border * ou,
      design.spacing * ou,
    );
    final u = _unit(size);
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

/// Erstellt die fertigen Bilder als PNG. Eine Collage ergibt ein Bild,
/// ein Karussell ein Bild pro Slide.
Future<List<Uint8List>> exportCollage(Design d, {required bool uhd, bool overview = false}) async {
  await prepareGrain();
  final size = d.canvasSize(uhd: uhd);
  final slide = d.slideSize(uhd: uhd);
  final unit = slide.width / 400;
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
    images[i] = await decodeForExport(slot, frames[i]);
  }

  final count = d.carousel ? d.slides : 1;
  final results = <Uint8List>[];
  for (var k = 0; k < count; k++) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & slide);
    canvas.translate(-k * slide.width, 0);
    paintCollage(canvas, size, d, imageFor: (i) => images[i]);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      slide.width.toInt(),
      slide.height.toInt(),
    );
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    results.add(data!.buffer.asUint8List());
  }
  // Gesamtbild: alle Slides in einem Bild (z. B. zum Zeigen), max. 4096 px breit.
  if (d.carousel && overview) {
    final scale = math.min(1.0, 4096 / size.width);
    final w = (size.width * scale).round(), h = (size.height * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.scale(scale);
    paintCollage(canvas, size, d, imageFor: (i) => images[i]);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    results.add(data!.buffer.asUint8List());
  }
  for (final img in images.values) {
    img.dispose();
  }
  return results;
}

/// Lange Seite, die ein Foto im Feld [frame] braucht.
int neededSide(Slot slot, Rect frame) {
  final dst = imageRect(slot.photo.width, slot.photo.height, frame, slot.zoom, slot.offsetX, slot.offsetY);
  return math.max(dst.width, dst.height).ceil();
}

/// Foto (oder Video Startbild) in der Größe, die der Export braucht.
Future<ui.Image> decodeForExport(Slot slot, Rect frame) async {
  final needed = neededSide(slot, frame);
  final v = slot.photo.video;
  if (v != null) {
    return VideoNative.frameAt(v.path, slot.videoStartMs, maxSide: needed);
  }
  final codec = await ui.instantiateImageCodecWithSize(
    await ui.ImmutableBuffer.fromUint8List(slot.photo.bytes),
    getTargetSize: (w, h) {
      final longSide = math.max(w, h);
      if (needed >= longSide) return ui.TargetImageSize(width: w, height: h);
      return w >= h ? ui.TargetImageSize(width: needed) : ui.TargetImageSize(height: needed);
    },
  );
  final img = (await codec.getNextFrame()).image;
  codec.dispose();
  return img;
}

/// Kleines Vorschaubild (PNG) für "Meine Collagen", aus den Vorschau Fotos.
Future<Uint8List> renderThumb(Design d, {double longSide = 480}) async {
  await prepareGrain();
  final ratio = d.canvasRatio;
  final size = ratio >= 1 ? Size(longSide, longSide / ratio) : Size(longSide * ratio, longSide);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  paintCollage(canvas, size, d, imageFor: (i) => d.slots[i]?.shown);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
