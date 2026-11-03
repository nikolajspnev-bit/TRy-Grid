import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Maximale Anzahl Felder in einer Collage.
const int kMaxSlots = 20;

/// Seitenverhältnisse der Leinwand.
enum AspectFormat {
  story('9:16', 'Story', 9 / 16),
  portrait('4:5', 'Feed hoch', 4 / 5),
  classic('3:4', 'Instagram', 3 / 4),
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

/// Film Look für alle Fotos. Jeder Effekt lässt sich ein- und ausschalten,
/// alle Werte gehen von 0 bis 1 (angelehnt an das TRy Film Look Plugin).
class FilmLook {
  bool halOn = false;
  double halAmount = 0.7;
  double halRadius = 0.45;
  double halThreshold = 0.4;
  double halWarmth = 0.5;

  bool mistOn = false;
  double mistAmount = 0.4;
  double mistSoftness = 0.5;
  double mistLift = 0.3;

  bool grainOn = false;
  double grainAmount = 0.35;
  double grainSize = 0.3;
  double grainColor = 0.15;

  bool vigOn = false;
  double vigAmount = 0.4;
  double vigSoftness = 0.6;

  /// Blitz: wie ein direkter Aufsteckblitz (helle Mitte, harter Kontrast,
  /// dunkler Hintergrund, leicht kühl).
  bool flashOn = false;
  double flashAmount = 0.6;
  double flashFalloff = 0.5;
  double flashHeight = 0.4;
  double flashCool = 0.4;

  /// Film Farben: Farbstil aus [kGradeNames] mit Stärke.
  bool gradeOn = false;
  int gradeStyle = 0;
  double gradeAmount = 0.7;

  /// Anamorph: lange waagerechte Lichtstreifen an hellen Stellen (blau oder gelb).
  bool anaOn = false;
  double anaAmount = 0.6;
  double anaLength = 0.6;
  double anaThreshold = 0.55;
  double anaThickness = 0.3;
  int anaColor = 0; // 0 = Blau, 1 = Gelb

  bool get active => halOn || mistOn || grainOn || vigOn || flashOn || gradeOn || anaOn;

  FilmLook copy() => FilmLook()
    ..halOn = halOn
    ..halAmount = halAmount
    ..halRadius = halRadius
    ..halThreshold = halThreshold
    ..halWarmth = halWarmth
    ..mistOn = mistOn
    ..mistAmount = mistAmount
    ..mistSoftness = mistSoftness
    ..mistLift = mistLift
    ..grainOn = grainOn
    ..grainAmount = grainAmount
    ..grainSize = grainSize
    ..grainColor = grainColor
    ..vigOn = vigOn
    ..vigAmount = vigAmount
    ..vigSoftness = vigSoftness
    ..flashOn = flashOn
    ..flashAmount = flashAmount
    ..flashFalloff = flashFalloff
    ..flashHeight = flashHeight
    ..flashCool = flashCool
    ..gradeOn = gradeOn
    ..gradeStyle = gradeStyle
    ..gradeAmount = gradeAmount
    ..anaOn = anaOn
    ..anaAmount = anaAmount
    ..anaLength = anaLength
    ..anaThreshold = anaThreshold
    ..anaThickness = anaThickness
    ..anaColor = anaColor;
}

extension FilmLookJson on FilmLook {
  Map<String, dynamic> toJson() => {
    'halOn': halOn, 'halAmount': halAmount, 'halRadius': halRadius,
    'halThreshold': halThreshold, 'halWarmth': halWarmth,
    'mistOn': mistOn, 'mistAmount': mistAmount, 'mistSoftness': mistSoftness, 'mistLift': mistLift,
    'grainOn': grainOn, 'grainAmount': grainAmount, 'grainSize': grainSize, 'grainColor': grainColor,
    'vigOn': vigOn, 'vigAmount': vigAmount, 'vigSoftness': vigSoftness,
    'flashOn': flashOn, 'flashAmount': flashAmount, 'flashFalloff': flashFalloff,
    'flashHeight': flashHeight, 'flashCool': flashCool,
    'gradeOn': gradeOn, 'gradeStyle': gradeStyle, 'gradeAmount': gradeAmount,
    'anaOn': anaOn, 'anaAmount': anaAmount, 'anaLength': anaLength,
    'anaThreshold': anaThreshold, 'anaThickness': anaThickness, 'anaColor': anaColor,
  };
}

FilmLook filmLookFromJson(Map<String, dynamic> j) {
  final l = FilmLook();
  bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
  double n(String k, double d) => j[k] is num ? (j[k] as num).toDouble() : d;
  return l
    ..halOn = b('halOn', l.halOn)
    ..halAmount = n('halAmount', l.halAmount)
    ..halRadius = n('halRadius', l.halRadius)
    ..halThreshold = n('halThreshold', l.halThreshold)
    ..halWarmth = n('halWarmth', l.halWarmth)
    ..mistOn = b('mistOn', l.mistOn)
    ..mistAmount = n('mistAmount', l.mistAmount)
    ..mistSoftness = n('mistSoftness', l.mistSoftness)
    ..mistLift = n('mistLift', l.mistLift)
    ..grainOn = b('grainOn', l.grainOn)
    ..grainAmount = n('grainAmount', l.grainAmount)
    ..grainSize = n('grainSize', l.grainSize)
    ..grainColor = n('grainColor', l.grainColor)
    ..vigOn = b('vigOn', l.vigOn)
    ..vigAmount = n('vigAmount', l.vigAmount)
    ..vigSoftness = n('vigSoftness', l.vigSoftness)
    ..flashOn = b('flashOn', l.flashOn)
    ..flashAmount = n('flashAmount', l.flashAmount)
    ..flashFalloff = n('flashFalloff', l.flashFalloff)
    ..flashHeight = n('flashHeight', l.flashHeight)
    ..flashCool = n('flashCool', l.flashCool)
    ..gradeOn = b('gradeOn', l.gradeOn)
    ..gradeStyle = j['gradeStyle'] is int ? j['gradeStyle'] as int : l.gradeStyle
    ..gradeAmount = n('gradeAmount', l.gradeAmount)
    ..anaOn = b('anaOn', l.anaOn)
    ..anaAmount = n('anaAmount', l.anaAmount)
    ..anaLength = n('anaLength', l.anaLength)
    ..anaThreshold = n('anaThreshold', l.anaThreshold)
    ..anaThickness = n('anaThickness', l.anaThickness)
    ..anaColor = j['anaColor'] is int ? j['anaColor'] as int : l.anaColor;
}

/// Farben für Anamorph.
const kAnaColorNames = ['Blau', 'Gelb'];

/// Namen der Film Farben (eigene Stile, keine Nachbauten).
const kGradeNames = ['Warm', 'Kühl', 'Blass', 'Kino', 'S/W'];

/// Karussell Aufteilung.
enum CarouselSplit { flow, perSlide, bridge }

/// Formate, die im Karussell als einzelne Slide möglich sind.
const kSlideFormats = [
  AspectFormat.portrait,
  AspectFormat.classic,
  AspectFormat.square,
];

enum LayoutMode { grid, bento }

/// Ein geladenes Foto. [bytes] ist das Original für den Export,
/// [preview] eine verkleinerte Version für die Anzeige.
class Photo {
  Photo({required this.bytes, required this.preview, this.video});
  final Uint8List bytes;
  final ui.Image preview;

  /// Gesetzt, wenn das Feld ein Video ist. [bytes] und [preview] sind dann
  /// das erste Bild des Videos.
  final VideoSource? video;

  double get width => preview.width.toDouble();
  double get height => preview.height.toDouble();

  /// Kennung aus dem Inhalt, damit gleiche Fotos nur einmal gespeichert werden.
  late final String key = video != null ? 'v-${video!.name}' : _fingerprint(bytes);
}

/// Ein Video im App Speicher.
class VideoSource {
  VideoSource({required this.name, required this.path, required this.durationMs});

  /// Dateiname im App Speicher (bleibt gleich), [path] ist der volle Pfad.
  final String name;
  final String path;
  final int durationMs;
}

String _fingerprint(Uint8List b) {
  var h = 0x811c9dc5;
  // Bei großen Dateien reicht jedes vierte Byte, das ist deutlich schneller.
  final step = b.length > 2000000 ? 4 : 1;
  for (var i = 0; i < b.length; i += step) {
    h ^= b[i];
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return '${b.length.toRadixString(16)}-${h.toRadixString(16)}';
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

  /// Eigener Film Look nur für dieses Foto. null = Look von "Alle".
  FilmLook? look;

  /// Video: ab wann es abgespielt wird, und das Bild an dieser Stelle.
  int videoStartMs = 0;
  ui.Image? startFrame;

  /// Bild für die Vorschau.
  ui.Image get shown => startFrame ?? photo.preview;

  Slot copy() => Slot(photo, zoom: zoom, offsetX: offsetX, offsetY: offsetY)
    ..look = look?.copy()
    ..videoStartMs = videoStartMs
    ..startFrame = startFrame;
}

/// Der komplette Zustand einer Collage.
class Design {
  AspectFormat format = AspectFormat.story;
  LayoutMode mode = LayoutMode.grid;
  int frames = 4;
  int columns = 2;
  int bentoSeed = 1;

  /// Karussell: mehrere Slides nebeneinander, die Collage läuft über alle.
  bool carousel = false;
  int slides = 3;
  AspectFormat slideFormat = AspectFormat.portrait;
  CarouselSplit split = CarouselSplit.flow;
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

  String get _layoutKey {
    final base = mode == LayoutMode.bento
        ? 'b$frames-$bentoSeed-${canvasRatio.toStringAsFixed(3)}'
        : 'g$frames-$columns';
    return carousel ? '$base-c$slides-${split.name}' : base;
  }

  /// Mindestzahl Felder, die eine Karussell Aufteilung braucht.
  int get minFramesForSplit => !carousel
      ? 1
      : switch (split) {
          CarouselSplit.flow => 1,
          CarouselSplit.perSlide => slides,
          CarouselSplit.bridge => 2 * slides - 1,
        };

  bool get hasVideo => slots.any((s) => s?.photo.video != null);

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
    ..carousel = carousel
    ..slides = slides
    ..slideFormat = slideFormat
    ..split = split
    ..look = look.copy()
    ..border = border
    ..corners = corners
    ..spacing = spacing
    ..background = background
    ..slots = slots.map((s) => s?.copy()).toList()
    .._custom = _custom
    .._customKey = _customKey;

  /// Speichern: alles außer den Fotos selbst (die kommen über [Photo.key]).
  Map<String, dynamic> toJson() => {
    'v': 1,
    'format': format.name,
    'mode': mode.name,
    'frames': frames,
    'columns': columns,
    'bentoSeed': bentoSeed,
    'carousel': carousel,
    'slides': slides,
    'slideFormat': slideFormat.name,
    'split': split.name,
    'look': look.toJson(),
    'border': border,
    'corners': corners,
    'spacing': spacing,
    'background': background.toARGB32(),
    'slots': [
      for (final s in slots)
        s == null
            ? null
            : {
                'photo': s.photo.key,
                'zoom': s.zoom,
                'offsetX': s.offsetX,
                'offsetY': s.offsetY,
                if (s.videoStartMs > 0) 'start': s.videoStartMs,
                if (s.look != null) 'look': s.look!.toJson(),
              },
    ],
    if (_custom != null)
      'custom': [for (final r in _custom!) [r.left, r.top, r.right, r.bottom]],
    if (_customKey != null) 'customKey': _customKey,
  };

  static Design fromJson(Map<String, dynamic> j, Map<String, Photo> photos) {
    T pick<T extends Enum>(List<T> values, Object? name, T d) =>
        values.firstWhere((v) => v.name == name, orElse: () => d);
    double n(String k, double d) => j[k] is num ? (j[k] as num).toDouble() : d;
    final d = Design()
      ..format = pick(AspectFormat.values, j['format'], AspectFormat.story)
      ..mode = pick(LayoutMode.values, j['mode'], LayoutMode.grid)
      ..frames = (j['frames'] as num?)?.toInt() ?? 4
      ..columns = (j['columns'] as num?)?.toInt() ?? 2
      ..bentoSeed = (j['bentoSeed'] as num?)?.toInt() ?? 1
      ..carousel = j['carousel'] == true
      ..slides = (j['slides'] as num?)?.toInt() ?? 3
      ..slideFormat = pick(AspectFormat.values, j['slideFormat'], AspectFormat.portrait)
      ..split = pick(CarouselSplit.values, j['split'], CarouselSplit.flow)
      ..border = n('border', 0)
      ..corners = n('corners', 0)
      ..spacing = n('spacing', 0)
      ..background = Color((j['background'] as num?)?.toInt() ?? 0xFF000000);
    if (j['look'] is Map) d.look = filmLookFromJson((j['look'] as Map).cast<String, dynamic>());
    final list = (j['slots'] as List?) ?? const [];
    for (var i = 0; i < list.length && i < kMaxSlots; i++) {
      final s = list[i];
      if (s is! Map) continue;
      final photo = photos[s['photo']];
      if (photo == null) continue;
      d.slots[i] = Slot(
        photo,
        zoom: (s['zoom'] as num?)?.toDouble() ?? 1,
        offsetX: (s['offsetX'] as num?)?.toDouble() ?? 0,
        offsetY: (s['offsetY'] as num?)?.toDouble() ?? 0,
      )
        ..look = s['look'] is Map ? filmLookFromJson((s['look'] as Map).cast<String, dynamic>()) : null
        ..videoStartMs = (s['start'] as num?)?.toInt() ?? 0;
    }
    if (j['custom'] is List) {
      d._custom = [
        for (final r in j['custom'] as List)
          Rect.fromLTRB(
            (r[0] as num).toDouble(),
            (r[1] as num).toDouble(),
            (r[2] as num).toDouble(),
            (r[3] as num).toDouble(),
          ),
      ];
      d._customKey = j['customKey'] as String?;
    }
    return d;
  }

  /// Alle Foto Kennungen, die in dieser Collage stecken.
  static Set<String> photoKeysIn(Map<String, dynamic> j) => {
    for (final s in (j['slots'] as List?) ?? const [])
      if (s is Map && s['photo'] is String) s['photo'] as String,
  };

  /// Felder als Anteile der Innenfläche.
  List<Rect> get normalizedRects {
    if (hasCustomLayout) return _custom!;
    if (carousel && split != CarouselSplit.flow) return _splitRects();
    if (mode == LayoutMode.bento) {
      return bentoRects(frames, bentoSeed, canvasRatio);
    }
    return gridRects(frames, columns);
  }

  /// Karussell: Leinwand in Abschnitte teilen und jeden Abschnitt eigen füllen.
  /// "Pro Slide": jede Slide für sich. "Brücke": an jeder Slide Kante ein Foto,
  /// das über beide Slides läuft (Wischen wirkt nahtlos).
  List<Rect> _splitRects() {
    final n = slides;
    final sw = 1 / n;
    final segments = <(double, double)>[];
    final bridges = <Rect>[];
    if (split == CarouselSplit.perSlide) {
      for (var k = 0; k < n; k++) {
        segments.add((k * sw, (k + 1) * sw));
      }
    } else {
      final half = sw * 0.25; // Brücke ist eine halbe Slide breit
      var x = 0.0;
      for (var k = 1; k < n; k++) {
        final b0 = k * sw - half, b1 = k * sw + half;
        segments.add((x, b0));
        bridges.add(Rect.fromLTRB(b0, 0, b1, 1));
        x = b1;
      }
      segments.add((x, 1));
    }
    // Restliche Felder nach Breite auf die Abschnitte verteilen.
    final rest = math.max(frames - bridges.length, segments.length);
    final counts = List<int>.filled(segments.length, 1);
    var left = rest - segments.length;
    while (left > 0) {
      var bi = 0;
      var best = -1.0;
      for (var i = 0; i < segments.length; i++) {
        final w = segments[i].$2 - segments[i].$1;
        final score = w / counts[i];
        if (score > best) {
          best = score;
          bi = i;
        }
      }
      counts[bi]++;
      left--;
    }
    final rects = <Rect>[...bridges];
    for (var i = 0; i < segments.length; i++) {
      final (x0, x1) = segments[i];
      final w = x1 - x0;
      final local = mode == LayoutMode.bento
          ? bentoRects(counts[i], bentoSeed + i * 31, canvasRatio * w)
          : gridRects(counts[i], math.min(columns, counts[i]));
      for (final r in local) {
        rects.add(Rect.fromLTRB(x0 + r.left * w, r.top, x0 + r.right * w, r.bottom));
      }
    }
    rects.sort((a, b) {
      if ((a.left - b.left).abs() > 0.001) return a.left.compareTo(b.left);
      return a.top.compareTo(b.top);
    });
    return rects;
  }

  int get visibleCount => normalizedRects.length;

  /// Seitenverhältnis der ganzen Leinwand (im Karussell: alle Slides zusammen).
  double get canvasRatio =>
      carousel ? slideFormat.ratio * slides : format.ratio;

  /// Größe einer einzelnen Export Datei.
  Size slideSize({required bool uhd}) =>
      (carousel ? slideFormat : format).exportSize(uhd: uhd);

  /// Größe der ganzen Leinwand im Export.
  Size canvasSize({required bool uhd}) {
    final s = slideSize(uhd: uhd);
    return carousel ? Size(s.width * slides, s.height) : s;
  }

  String get formatLabel =>
      carousel ? '$slides× ${slideFormat.label}' : format.label;
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
