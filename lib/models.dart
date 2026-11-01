import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Maximale Anzahl Felder in einer Collage.
const int kMaxSlots = 12;

/// Seitenverhältnisse der Leinwand.
enum AspectFormat {
  story('9:16', 'Story', 9 / 16),
  portrait('4:5', 'Feed hoch', 4 / 5),
  classic('3:4', 'Instagram 3:4', 3 / 4),
  photo('2:3', 'Foto', 2 / 3),
  square('1:1', 'Quadrat', 1),
  landscape('1.91:1', 'Quer', 1.91),
  wide('16:9', 'Breitbild', 16 / 9);

  const AspectFormat(this.label, this.description, this.ratio);
  final String label;
  final String description;

  /// Breite geteilt durch Höhe.
  final double ratio;

  /// Exportgröße. 4K: lange Seite 3840 px. Sonst: kurze Seite 1080 px.
  Size exportSize({required bool uhd}) {
    if (uhd) {
      return ratio <= 1
          ? Size((3840 * ratio).roundToDouble(), 3840)
          : Size(3840, (3840 / ratio).roundToDouble());
    }
    return ratio <= 1
        ? Size(1080, (1080 / ratio).roundToDouble())
        : Size((1080 * ratio).roundToDouble(), 1080);
  }
}

/// Film Look für alle Fotos. Werte 0 bis 1.
class FilmLook {
  double halation = 0;
  double mist = 0;
  double grain = 0;

  bool get active => halation > 0 || mist > 0 || grain > 0;

  FilmLook copy() => FilmLook()
    ..halation = halation
    ..mist = mist
    ..grain = grain;
}

enum LayoutMode { grid, bento }

/// Ein geladenes Foto. [bytes] ist das Original für den Export,
/// [preview] eine verkleinerte Version für die Anzeige.
class Photo {
  Photo({required this.bytes, required this.preview});
  final Uint8List bytes;
  final ui.Image preview;

  double get width => preview.width.toDouble();
  double get height => preview.height.toDouble();
}

/// Ein belegtes Feld: Foto plus Zuschnitt.
class Slot {
  Slot(this.photo, {this.zoom = 1, this.offsetX = 0, this.offsetY = 0});
  final Photo photo;

  /// 1 = Feld ist genau gefüllt, größer = hineingezoomt.
  double zoom;

  /// -1 bis 1, verschiebt den Ausschnitt innerhalb des Überstands.
  double offsetX;
  double offsetY;

  Slot copy() => Slot(photo, zoom: zoom, offsetX: offsetX, offsetY: offsetY);
}

/// Der komplette Zustand einer Collage.
class Design {
  AspectFormat format = AspectFormat.story;
  LayoutMode mode = LayoutMode.grid;
  int frames = 4;
  int columns = 2;
  int bentoSeed = 1;
  FilmLook look = FilmLook();

  /// Rand, Ecken und Abstand in Einheiten von Leinwandbreite / 400.
  double border = 0;
  double corners = 0;
  double spacing = 0;
  Color background = Colors.black;
  List<Slot?> slots = List<Slot?>.filled(kMaxSlots, null);

  /// Von Hand verschobene Trennlinien. Gilt nur für das Layout,
  /// für das sie gemacht wurden ([_customKey]).
  List<Rect>? _custom;
  String? _customKey;

  String get _layoutKey => mode == LayoutMode.bento
      ? 'b$frames-$bentoSeed-${format.name}'
      : 'g$frames-$columns';

  bool get hasCustomLayout => _custom != null && _customKey == _layoutKey;

  set customRects(List<Rect>? rects) {
    _custom = rects;
    _customKey = rects == null ? null : _layoutKey;
  }

  Design clone() => Design()
    ..format = format
    ..mode = mode
    ..frames = frames
    ..columns = columns
    ..bentoSeed = bentoSeed
    ..look = look.copy()
    ..border = border
    ..corners = corners
    ..spacing = spacing
    ..background = background
    ..slots = slots.map((s) => s?.copy()).toList()
    .._custom = _custom
    .._customKey = _customKey;

  /// Felder als Anteile der Innenfläche.
  List<Rect> get normalizedRects {
    if (hasCustomLayout) return _custom!;
    if (mode == LayoutMode.bento) {
      return bentoRects(frames, bentoSeed, format.ratio);
    }
    return gridRects(frames, columns);
  }

  int get visibleCount => normalizedRects.length;
}

/// Bento: teilt zufällig (aber wiederholbar über [seed]) immer das
/// größte Feld, bis [count] Felder da sind. "Mischen" ändert den seed.
List<Rect> bentoRects(int count, int seed, double ratio) {
  final n = count.clamp(1, kMaxSlots);
  final rnd = math.Random(seed);
  final rects = <Rect>[const Rect.fromLTWH(0, 0, 1, 1)];
  while (rects.length < n) {
    var bi = 0;
    var best = -1.0;
    for (var i = 0; i < rects.length; i++) {
      final r = rects[i];
      final a = r.width * r.height * (1 + rnd.nextDouble() * 0.35);
      if (a > best) {
        best = a;
        bi = i;
      }
    }
    final r = rects.removeAt(bi);
    final t = 0.36 + rnd.nextDouble() * 0.28;
    final w = r.width * ratio;
    final h = r.height;
    final vertical = w > h * 1.15
        ? true
        : (h > w * 1.15 ? false : rnd.nextBool());
    if (vertical) {
      final x = r.left + r.width * t;
      rects.add(Rect.fromLTRB(r.left, r.top, x, r.bottom));
      rects.add(Rect.fromLTRB(x, r.top, r.right, r.bottom));
    } else {
      final y = r.top + r.height * t;
      rects.add(Rect.fromLTRB(r.left, r.top, r.right, y));
      rects.add(Rect.fromLTRB(r.left, y, r.right, r.bottom));
    }
  }
  rects.sort((a, b) {
    if ((a.top - b.top).abs() > 0.001) return a.top.compareTo(b.top);
    return a.left.compareTo(b.left);
  });
  return rects;
}

/// Raster: letzte Reihe wird auf volle Breite verteilt.
List<Rect> gridRects(int count, int columns) {
  final n = count.clamp(1, kMaxSlots);
  final c = columns.clamp(1, n);
  final rows = (n / c).ceil();
  final rects = <Rect>[];
  for (var r = 0; r < rows; r++) {
    final inRow = math.min(c, n - r * c);
    for (var i = 0; i < inRow; i++) {
      rects.add(Rect.fromLTWH(i / inRow, r / rows, 1 / inRow, 1 / rows));
    }
  }
  return rects;
}

/// Pixelrahmen aller Felder auf einer Leinwand der Größe [canvas].
List<Rect> cellFrames(
  List<Rect> norm,
  Size canvas,
  double border,
  double spacing,
) {
  final inner = Rect.fromLTWH(
    border,
    border,
    canvas.width - 2 * border,
    canvas.height - 2 * border,
  );
  if (inner.width <= 0 || inner.height <= 0) {
    return List<Rect>.filled(norm.length, Rect.zero);
  }
  final half = spacing / 2;
  const eps = 0.001;
  return norm.map((n) {
    final l = n.left < eps ? 0.0 : half;
    final t = n.top < eps ? 0.0 : half;
    final r = n.right > 1 - eps ? 0.0 : half;
    final b = n.bottom > 1 - eps ? 0.0 : half;
    return Rect.fromLTWH(
      inner.left + n.left * inner.width + l,
      inner.top + n.top * inner.height + t,
      math.max(0, n.width * inner.width - l - r),
      math.max(0, n.height * inner.height - t - b),
    );
  }).toList();
}

/// Wo das Bild gezeichnet wird, damit es [cell] füllt (wie "Füllen"),
/// inklusive Zoom und Verschiebung.
Rect imageRect(
  double imgW,
  double imgH,
  Rect cell,
  double zoom,
  double offsetX,
  double offsetY,
) {
  if (imgW <= 0 || imgH <= 0 || cell.isEmpty) return cell;
  final scale =
      math.max(cell.width / imgW, cell.height / imgH) * math.max(zoom, 1);
  final w = imgW * scale;
  final h = imgH * scale;
  final ox = w - cell.width;
  final oy = h - cell.height;
  return Rect.fromLTWH(
    cell.left - ox / 2 + offsetX * ox / 2,
    cell.top - oy / 2 + offsetY * oy / 2,
    w,
    h,
  );
}

/// Eine Trennlinie zwischen zwei benachbarten Feldern (Werte 0 bis 1).
class Seam {
  const Seam({
    required this.vertical,
    required this.pos,
    required this.start,
    required this.end,
  });

  /// true = senkrechte Linie (verschiebt nach links/rechts).
  final bool vertical;
  final double pos;
  final double start;
  final double end;
}

const double _eps = 0.002;
const double kMinCell = 0.1;

double _overlap(double a0, double a1, double b0, double b1) =>
    math.min(a1, b1) - math.max(a0, b0);

/// Alle Trennlinien, an denen man ziehen kann.
List<Seam> findSeams(List<Rect> rects) {
  final seams = <Seam>[];
  for (final a in rects) {
    for (final b in rects) {
      if (identical(a, b)) continue;
      if ((a.right - b.left).abs() < _eps) {
        final o0 = math.max(a.top, b.top), o1 = math.min(a.bottom, b.bottom);
        if (o1 - o0 > _eps) {
          seams.add(Seam(vertical: true, pos: a.right, start: o0, end: o1));
        }
      }
      if ((a.bottom - b.top).abs() < _eps) {
        final o0 = math.max(a.left, b.left), o1 = math.min(a.right, b.right);
        if (o1 - o0 > _eps) {
          seams.add(Seam(vertical: false, pos: a.bottom, start: o0, end: o1));
        }
      }
    }
  }
  return seams;
}

/// Verschiebt eine Trennlinie um [delta]. Alle Felder, die an dieser Linie
/// zusammenhängen, passen sich an: eins wird größer, das Nachbarfeld kleiner.
List<Rect> moveSeam(List<Rect> rects, Seam s, double delta) {
  double lo(Rect r) => s.vertical ? r.top : r.left;
  double hi(Rect r) => s.vertical ? r.bottom : r.right;
  bool before(Rect r) =>
      ((s.vertical ? r.right : r.bottom) - s.pos).abs() < _eps;
  bool after(Rect r) => ((s.vertical ? r.left : r.top) - s.pos).abs() < _eps;

  // Zusammenhängende Gruppe entlang der Linie finden.
  var spanLo = s.start, spanHi = s.end;
  final group = <int>{};
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < rects.length; i++) {
      if (group.contains(i)) continue;
      final r = rects[i];
      if ((before(r) || after(r)) &&
          _overlap(lo(r), hi(r), spanLo, spanHi) > _eps) {
        group.add(i);
        spanLo = math.min(spanLo, lo(r));
        spanHi = math.max(spanHi, hi(r));
        changed = true;
      }
    }
  }

  // Begrenzen, damit kein Feld zu klein wird.
  var d = delta;
  for (final i in group) {
    final r = rects[i];
    final size = s.vertical ? r.width : r.height;
    if (before(r)) d = math.max(d, kMinCell - size);
    if (after(r)) d = math.min(d, size - kMinCell);
  }

  return [
    for (var i = 0; i < rects.length; i++)
      if (!group.contains(i))
        rects[i]
      else if (before(rects[i]))
        s.vertical
            ? Rect.fromLTRB(
                rects[i].left,
                rects[i].top,
                rects[i].right + d,
                rects[i].bottom,
              )
            : Rect.fromLTRB(
                rects[i].left,
                rects[i].top,
                rects[i].right,
                rects[i].bottom + d,
              )
      else
        s.vertical
            ? Rect.fromLTRB(
                rects[i].left + d,
                rects[i].top,
                rects[i].right,
                rects[i].bottom,
              )
            : Rect.fromLTRB(
                rects[i].left,
                rects[i].top + d,
                rects[i].right,
                rects[i].bottom,
              ),
  ];
}

/// Pixelposition einer Trennlinie auf der Leinwand: Mittelpunkt und Linie.
({Offset mid, Offset a, Offset b}) seamOnCanvas(
  Seam s,
  Size canvas,
  double border,
) {
  final w = canvas.width - 2 * border, h = canvas.height - 2 * border;
  Offset p(double x, double y) => Offset(border + x * w, border + y * h);
  final m = (s.start + s.end) / 2;
  return s.vertical
      ? (mid: p(s.pos, m), a: p(s.pos, s.start), b: p(s.pos, s.end))
      : (mid: p(m, s.pos), a: p(s.start, s.pos), b: p(s.end, s.pos));
}
