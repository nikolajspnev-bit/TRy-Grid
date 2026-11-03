import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'color_picker.dart';
import 'crop.dart';
import 'drafts_screen.dart';
import 'export.dart';
import 'models.dart';
import 'painter.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

enum PanelTab { design, fx, photos }

enum FxKind { grade, flash, anamorph, halation, mist, grain, vignette }

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store});
  final CollageStore store;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  CollageStore get store => widget.store;
  PanelTab tab = PanelTab.design;

  // Foto tauschen
  int? dragFrom;
  int? dragTarget;

  // Trennlinie ziehen
  Seam? seam;
  List<Rect> seamBase = const [];
  double seamDelta = 0;

  /// Position, an der die gezogene Linie gerade eingerastet ist.
  double? snapPos;

  // "Halten für Original"
  bool original = false;

  // Karussell: sichtbarer Ausschnitt (0 = ganz links, 1 = ganz rechts).
  double viewFrac = 0;
  bool scrolling = false;

  // Geöffneter Effekt im FX Menü.
  FxKind? fx;

  // Ziel im FX Menü: null = alle Fotos, sonst Index des Feldes.
  int? fxSlot;

  @override
  void initState() {
    super.initState();
    prepareGrain().then((_) => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Expanded(child: _stage()),
              _infoLine(),
              _panel(),
            ],
          ),
        ),
      ),
    );
  }

  // Kopfzeile

  Widget _header() {
    final d = store.design;
    final canExport = store.hasPhotos;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          // Meine Collagen
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DraftsScreen(store: store)),
            ),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.collections_outlined, size: 16),
            ),
          ),
          // Format als umrandeter Chip.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _formatSheet,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.formatLabel, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'TRy', style: TextStyle(fontWeight: FontWeight.w500)),
                    TextSpan(text: ' GRID', style: TextStyle(color: AppColors.muted, letterSpacing: 3)),
                  ],
                ),
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
          // Export als klarer Knopf in Orange.
          GestureDetector(
            onTap: canExport ? () => showExportSheet(context, store) : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
              decoration: BoxDecoration(
                color: canExport ? AppColors.accent : AppColors.line,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Export',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: canExport ? const Color(0xFF111111) : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.north_east,
                    size: 14,
                    color: canExport ? const Color(0xFF111111) : AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Zeile unter der Leinwand: Name (antippen zum Umbenennen) und Größe.
  Widget _infoLine() {
    final d = store.design;
    final size = d.slideSize(uhd: false);
    final px = '${size.width.round()} × ${size.height.round()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
      child: Row(
        children: [
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _rename,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      store.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 11, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            d.carousel ? '${d.slides} Slides · $px' : px,
            style: const TextStyle(fontSize: 11, color: AppColors.muted, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  /// Auswahl: Collage (ein Bild) oder Karussell (mehrere Slides für Instagram).
  Future<void> _formatSheet() {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => ListenableBuilder(
        listenable: store,
        builder: (ctx, _) {
          final d = store.design;
          Widget option(
            AspectFormat f,
            bool selected,
            VoidCallback onTap, {
            String? size,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: selected ? AppColors.line : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Center(
                            child: Container(
                              width: f.ratio >= 1 ? 22 : 22 * f.ratio,
                              height: f.ratio >= 1 ? 22 / f.ratio : 22,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected ? AppColors.accent : AppColors.muted,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${f.description} ${f.label}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (size != null)
                              Text(
                                size,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: AppColors.accent,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          String px(Size s) => '${s.width.round()} × ${s.height.round()}';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Segmented(
                    options: const ['Collage', 'Karussell'],
                    selected: d.carousel ? 1 : 0,
                    onChanged: (i) => store.edit((d) {
                      final toCarousel = i == 1;
                      if (toCarousel == d.carousel) return;
                      d.carousel = toCarousel;
                      if (toCarousel) {
                        // Guter Start: Bento, das über die Slides läuft.
                        d.mode = LayoutMode.bento;
                        if (d.frames < d.slides + 1) d.frames = d.slides + 1;
                      }
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (!d.carousel)
                    for (final f in AspectFormat.values)
                      option(
                        f,
                        f == d.format,
                        () => store.edit((d) => d.format = f),
                        size: px(f.exportSize(uhd: true)),
                      )
                  else ...[
                    const Text(
                      'Eine Collage über mehrere Slides. Beim Wischen auf Instagram läuft sie nahtlos weiter.',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    for (final f in kSlideFormats)
                      option(
                        f,
                        f == d.slideFormat,
                        () => store.edit((d) => d.slideFormat = f),
                        size: 'je Slide ${px(f.exportSize(uhd: false))}',
                      ),
                    const SizedBox(height: 6),
                    RowSlider(
                      label: 'Slides',
                      value: d.slides.toDouble(),
                      min: 2,
                      max: 10,
                      divisions: 8,
                      onStart: store.checkpoint,
                      onChanged: (v) => store.edit(
                        (d) {
                          d.slides = v.round();
                          if (d.frames < d.minFramesForSplit) d.frames = d.minFramesForSplit;
                        },
                        record: false,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Aufteilung',
                      style: TextStyle(fontSize: 11, color: AppColors.muted, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Segmented(
                      options: const ['Durchlaufend', 'Pro Slide', 'Brücke'],
                      selected: d.split.index,
                      onChanged: (i) => store.edit((d) {
                        d.split = CarouselSplit.values[i];
                        if (d.frames < d.minFramesForSplit) d.frames = d.minFramesForSplit;
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (d.split) {
                        CarouselSplit.flow => 'Die Felder laufen frei über alle Slides.',
                        CarouselSplit.perSlide => 'Jede Slide hat ihr eigenes Layout.',
                        CarouselSplit.bridge => 'An jeder Slide Kante liegt ein Foto über beiden Slides. Beim Wischen wirkt es nahtlos.',
                      },
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: store.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Name', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: controller,
          autofocus: true,
          cursorColor: AppColors.accent,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      store.setTitle(result.trim());
    }
  }

  // Leinwand

  Widget _stage() {
    final d = store.design;
    return LayoutBuilder(
      builder: (context, c) {
        const pad = 14.0;
        const stripGap = 10.0;
        final availW = c.maxWidth - pad * 2;
        var availH = c.maxHeight - pad - 6;
        double h, fullW;

        if (!d.carousel) {
          fullW = availW;
          h = fullW / d.canvasRatio;
          if (h > availH) {
            h = availH;
            fullW = h * d.canvasRatio;
          }
        } else {
          // Karussell: große Ansicht mit Ausschnitt, darunter eine kleine Übersicht.
          availH -= 44 + stripGap;
          h = availH;
          final slideW = h * d.slideFormat.ratio;
          if (slideW > availW * 0.82) h = availW * 0.82 / d.slideFormat.ratio;
          fullW = h * d.canvasRatio;
        }
        final viewW = fullW < availW ? fullW : availW;
        final maxScroll = fullW - viewW;
        final scrollX = maxScroll <= 0
            ? 0.0
            : viewFrac.clamp(0.0, 1.0) * maxScroll;

        final full = Size(fullW, h);
        final unit = fullW / 400 / (d.carousel ? d.slides : 1);
        final border = d.border * unit;
        final frames = cellFrames(
          d.normalizedRects,
          full,
          border,
          d.spacing * unit,
        );
        final innerW = fullW - 2 * border, innerH = h - 2 * border;

        // Fingerposition in Leinwand Koordinaten (berücksichtigt den Ausschnitt).
        Offset toCanvas(Offset p) => p + Offset(scrollX, 0);

        int? hit(Offset p) {
          final q = toCanvas(p);
          for (var i = 0; i < frames.length; i++) {
            if (frames[i].contains(q)) return i;
          }
          return null;
        }

        // Nächste Trennlinie unter dem Finger (max. 22 px entfernt).
        Seam? seamAt(Offset p) {
          final q = toCanvas(p);
          Seam? best;
          var bestDist = 22.0;
          for (final s in findSeams(d.normalizedRects)) {
            final cs = seamOnCanvas(s, full, border);
            final along = s.vertical ? q.dy : q.dx;
            final lo = s.vertical ? cs.a.dy : cs.a.dx;
            final hi = s.vertical ? cs.b.dy : cs.b.dx;
            if (along < lo || along > hi) continue;
            final dist = s.vertical
                ? (q.dx - cs.a.dx).abs()
                : (q.dy - cs.a.dy).abs();
            if (dist < bestDist) {
              bestDist = dist;
              best = s;
            }
          }
          return best;
        }

        final canvas = GestureDetector(
          onPanStart: (e) {
            final s = seamAt(e.localPosition);
            if (s == null) {
              scrolling = maxScroll > 0;
              return;
            }
            store.checkpoint();
            HapticFeedback.selectionClick();
            setState(() {
              seam = s;
              seamBase = List.of(d.normalizedRects);
              seamDelta = 0;
            });
          },
          onPanUpdate: (e) {
            final s = seam;
            if (s == null) {
              // Im Karussell: mit dem Finger durch die Slides schieben.
              if (scrolling && maxScroll > 0) {
                setState(
                  () => viewFrac = (viewFrac - e.delta.dx / maxScroll).clamp(
                    0.0,
                    1.0,
                  ),
                );
              }
              return;
            }
            if (innerW <= 0 || innerH <= 0) return;
            seamDelta += s.vertical ? e.delta.dx / innerW : e.delta.dy / innerH;
            // Einrasten: Drittel, Hälfte, Viertel, Slide Kanten und andere Linien.
            final raw = s.pos + seamDelta;
            final tol = 9 / (s.vertical ? innerW : innerH);
            double? best;
            var bestDist = tol;
            for (final t in _snapTargets(d, s, fullW, border, innerW)) {
              final dist = (t - raw).abs();
              if (dist < bestDist) {
                bestDist = dist;
                best = t;
              }
            }
            if (best != null && best != snapPos) HapticFeedback.selectionClick();
            snapPos = best;
            final delta = (best ?? raw) - s.pos;
            store.edit(
              (d) => d.customRects = moveSeam(seamBase, s, delta),
              record: false,
            );
          },
          onPanEnd: (_) => setState(() {
            seam = null;
            snapPos = null;
            scrolling = false;
          }),
          onPanCancel: () => setState(() {
            seam = null;
            snapPos = null;
            scrolling = false;
          }),
          onTapUp: (e) {
            final i = hit(e.localPosition);
            if (i != null) _openSlot(i);
          },
          onLongPressStart: (e) {
            final i = hit(e.localPosition);
            if (i == null || d.slots[i] == null) return;
            HapticFeedback.mediumImpact();
            setState(() {
              dragFrom = i;
              dragTarget = i;
            });
          },
          onLongPressMoveUpdate: (e) {
            if (dragFrom == null) return;
            final i = hit(e.localPosition);
            if (i != dragTarget) {
              if (i != null) HapticFeedback.selectionClick();
              setState(() => dragTarget = i);
            }
          },
          onLongPressEnd: (_) {
            final from = dragFrom;
            final to = dragTarget;
            setState(() {
              dragFrom = null;
              dragTarget = null;
            });
            if (from != null && to != null) store.swap(from, to);
          },
          child: CustomPaint(
            size: Size(viewW, h),
            painter: CollagePainter(
              d,
              fullSize: full,
              scrollX: scrollX,
              dragFrom: dragFrom,
              dragTarget: dragTarget,
              original: original,
              snapLine: seam == null || snapPos == null
                  ? null
                  : Seam(vertical: seam!.vertical, pos: snapPos!, start: 0, end: 1),
              activeSeam: seam == null
                  ? null
                  : Seam(
                      vertical: seam!.vertical,
                      pos: snapPos ?? seam!.pos + seamDelta,
                      start: seam!.start,
                      end: seam!.end,
                    ),
            ),
          ),
        );

        // Sucher Ecken um die Leinwand (Fotografen Look).
        final framed = SizedBox(
          width: viewW + 16,
          height: h + 16,
          child: Stack(
            children: [
              Center(child: canvas),
              const Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _Brackets())),
              ),
            ],
          ),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            if (!d.carousel)
              framed
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  framed,
                  const SizedBox(height: stripGap),
                  _strip(availW, fullW, viewW, scrollX),
                ],
              ),
            if (store.loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Positionen (0 bis 1 der Innenfläche), an denen eine Linie einrastet.
  List<double> _snapTargets(Design d, Seam s, double fullW, double border, double innerW) {
    const parts = [1 / 4, 1 / 3, 1 / 2, 2 / 3, 3 / 4];
    final out = <double>[];
    if (s.vertical && d.carousel) {
      // In Slides denken: Kanten und Teile jeder Slide (in Pixeln umgerechnet).
      final slideW = fullW / d.slides;
      for (var k = 0; k < d.slides; k++) {
        for (final f in [0.0, ...parts]) {
          out.add((slideW * (k + f) - border) / innerW);
        }
      }
    } else {
      out.addAll(parts);
    }
    // Andere Linien in gleicher Richtung, damit Kanten bündig werden.
    for (final o in findSeams(seamBase)) {
      if (o.vertical == s.vertical && (o.pos - s.pos).abs() > 0.002) out.add(o.pos);
    }
    return out.where((t) => t > 0.01 && t < 0.99).toList();
  }

  /// Kleine Übersicht über alle Slides. Antippen oder ziehen springt dorthin.
  Widget _strip(double availW, double fullW, double viewW, double scrollX) {
    final d = store.design;
    var sh = 44.0;
    var sw = sh * d.canvasRatio;
    if (sw > availW) {
      sw = availW;
      sh = sw / d.canvasRatio;
    }
    final scale = sw / fullW;
    final maxScroll = fullW - viewW;

    void jump(double x) {
      if (maxScroll <= 0) return;
      final center = x / scale;
      setState(
        () => viewFrac = ((center - viewW / 2) / maxScroll).clamp(0.0, 1.0),
      );
    }

    return GestureDetector(
      onTapDown: (e) => jump(e.localPosition.dx),
      onHorizontalDragUpdate: (e) => jump(e.localPosition.dx),
      child: SizedBox(
        width: sw,
        height: sh,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: CollagePainter(d, mini: true)),
            ),
            Positioned(
              left: scrollX * scale,
              top: 0,
              width: viewW * scale,
              height: sh,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSlot(int i) async {
    final slot = store.design.slots[i];
    if (slot == null) {
      // Leeres Feld: mehrere Fotos auf einmal, beginnend bei diesem Feld.
      await store.pickPhotos(startAt: i);
      return;
    }
    final d = store.design;
    // Seitenverhältnis des Feldes auf einer Referenzleinwand berechnen.
    final ref = Size(1000, 1000 / d.canvasRatio);
    final unit = ref.width / 400 / (d.carousel ? d.slides : 1);
    final f = cellFrames(
      d.normalizedRects,
      ref,
      d.border * unit,
      d.spacing * unit,
    )[i];
    if (f.isEmpty) return;

    final result = await Navigator.of(context).push<CropResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            CropScreen(slot: slot.copy(), cellAspect: f.width / f.height),
      ),
    );
    if (result == null) return;
    switch (result.action) {
      case CropAction.save:
        store.edit((d) {
          final s = d.slots[i];
          if (s == null) return;
          s.zoom = result.zoom;
          s.offsetX = result.offsetX;
          s.offsetY = result.offsetY;
          s.videoStartMs = result.videoStartMs;
          s.startFrame = result.startFrame;
        });
      case CropAction.replace:
        await store.pickPhotos(intoSlot: i);
      case CropAction.remove:
        store.removePhoto(i);
    }
  }

  // Bedienfeld unten

  Widget _panel() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(18, 0, 14, bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _tabButton(PanelTab.design, 'Layout'),
              _tabButton(PanelTab.fx, 'Look'),
              _tabButton(PanelTab.photos, 'Fotos'),
              const Spacer(),
              if (tab == PanelTab.design && store.design.hasCustomLayout)
                _iconButton(
                  Icons.grid_on,
                  'Gleichmäßig',
                  () => store.edit((d) => d.customRects = null),
                ),
              _iconButton(
                Icons.undo,
                'Rückgängig',
                store.canUndo ? store.undo : null,
              ),
              _iconButton(
                Icons.redo,
                'Wiederholen',
                store.canRedo ? store.redo : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 250,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 4),
              child: switch (tab) {
                PanelTab.design => _designTab(),
                PanelTab.fx => _fxTab(),
                PanelTab.photos => _photosTab(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      color: AppColors.text,
      disabledColor: AppColors.line,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Reiter als Text oben im Bedienfeld, aktiver Reiter mit oranger Linie.
  Widget _tabButton(PanelTab t, String label) {
    final active = tab == t;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => tab = t),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
        margin: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: active ? AppColors.accent : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            color: active ? AppColors.text : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _designTab() {
    final d = store.design;
    final grid = d.mode == LayoutMode.grid;
    return Column(
      children: [
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: StackSlider(
                label: 'Felder',
                value: d.frames,
                min: 1,
                max: kMaxSlots,
                onStart: store.checkpoint,
                onChanged: (v) =>
                    store.edit((d) => d.frames = v, record: false),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: grid
                  ? StackSlider(
                      label: 'Spalten',
                      value: d.columns,
                      min: 1,
                      max: 5,
                      onStart: store.checkpoint,
                      onChanged: (v) =>
                          store.edit((d) => d.columns = v, record: false),
                    )
                  : SizedBox(
                      height: 52,
                      child: TextButton.icon(
                        onPressed: () => store.edit((d) => d.bentoSeed++),
                        icon: const Icon(Icons.shuffle, size: 16),
                        label: const Text(
                          'Mischen',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.text,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        ModeTabs(
          options: const [
            ('Raster', Icons.grid_view),
            ('Bento', Icons.view_quilt_outlined),
          ],
          selected: grid ? 0 : 1,
          onChanged: (i) => store.edit(
            (d) => d.mode = i == 0 ? LayoutMode.grid : LayoutMode.bento,
          ),
        ),
        const SizedBox(height: 6),
        RowSlider(
          label: 'Rand',
          value: d.border,
          max: 40,
          onStart: store.checkpoint,
          onChanged: (v) => store.edit((d) => d.border = v, record: false),
        ),
        RowSlider(
          label: 'Ecken',
          value: d.corners,
          max: 80,
          onStart: store.checkpoint,
          onChanged: (v) => store.edit((d) => d.corners = v, record: false),
        ),
        RowSlider(
          label: 'Abstand',
          value: d.spacing,
          max: 40,
          onStart: store.checkpoint,
          onChanged: (v) => store.edit((d) => d.spacing = v, record: false),
        ),
        _backgroundRow(),
      ],
    );
  }

  Widget _backgroundRow() {
    final d = store.design;
    const swatches = [
      Colors.black,
      Color(0xFF1C1C1C),
      Colors.white,
      Color(0xFFECE8E1),
      AppColors.accent,
    ];
    final custom = !swatches.contains(d.background);

    Widget dot({required Widget child, required bool selected, required VoidCallback onTap, Key? key}) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipOval(child: child),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(
            width: 92,
            child: Text('Hintergrund', style: TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final c in swatches)
                  dot(
                    selected: d.background == c,
                    onTap: () => store.edit((d) => d.background = c),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.line),
                      ),
                    ),
                  ),
                // Farbrad: eigene Farbe oder HEX Code.
                dot(
                  selected: custom,
                  onTap: () async {
                    final c = await showColorPicker(context, d.background);
                    if (c != null) store.edit((d) => d.background = c);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h % 360, 0.85, 1).toColor(),
                            ],
                          ),
                        ),
                      ),
                      if (custom)
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: d.background, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FX: Liste der Effekte. Antippen öffnet die Einstellungen.

  Widget _fxTab() {
    final kind = fx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fxTargets(),
        const SizedBox(height: 8),
        if (kind == null) ..._fxList() else ..._fxDetail(kind),
        const SizedBox(height: 8),
        _holdOriginal(),
      ],
    );
  }

  /// Gilt das Feld noch? Sonst zurück auf "Alle".
  int? get _target {
    final i = fxSlot;
    final d = store.design;
    if (i == null || i >= d.visibleCount || d.slots[i] == null) return null;
    return i;
  }

  /// Look, der gerade bearbeitet wird (für die Anzeige).
  FilmLook get _shownLook {
    final i = _target;
    final d = store.design;
    return i == null ? d.look : (d.slots[i]!.look ?? d.look);
  }

  /// Look zum Ändern. Ein Foto bekommt beim ersten Ändern eine eigene Kopie.
  FilmLook _editLook(Design d) {
    final i = _target;
    if (i == null) return d.look;
    final slot = d.slots[i]!;
    return slot.look ??= d.look.copy();
  }

  /// Zeile oben: "Alle" und kleine Vorschauen der Fotos.
  Widget _fxTargets() {
    final d = store.design;
    final target = _target;
    final filled = [
      for (var i = 0; i < d.visibleCount; i++)
        if (d.slots[i] != null) i,
    ];

    Widget chip({required bool selected, required VoidCallback onTap, required Widget child, Key? key}) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 2 : 1),
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(7), child: child),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              chip(
                selected: target == null,
                onTap: () => setState(() => fxSlot = null),
                child: const Center(child: Text('Alle', style: TextStyle(fontSize: 11))),
              ),
              for (final i in filled)
                chip(
                  selected: target == i,
                  onTap: () => setState(() => fxSlot = i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RawImage(image: d.slots[i]!.shown, fit: BoxFit.cover),
                      // Punkt: dieses Foto hat einen eigenen Look.
                      if (d.slots[i]!.look != null)
                        const Positioned(
                          right: 3,
                          top: 3,
                          child: Icon(Icons.circle, size: 7, color: AppColors.accent),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              target == null
                  ? 'Gilt für alle Fotos'
                  : d.slots[target]!.look == null
                      ? 'Foto ${(target + 1).toString().padLeft(2, '0')} · wie alle'
                      : 'Foto ${(target + 1).toString().padLeft(2, '0')} · eigener Look',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const Spacer(),
            if (target != null && d.slots[target]!.look != null)
              GestureDetector(
                onTap: () => store.edit((d) => d.slots[target]!.look = null),
                child: const Text('Wie alle', style: TextStyle(fontSize: 11, color: AppColors.accent)),
              ),
          ],
        ),
      ],
    );
  }

  String _fxName(FxKind k) => switch (k) {
    FxKind.grade => 'Film Farben',
    FxKind.flash => 'Blitz',
    FxKind.anamorph => 'Anamorph',
    FxKind.halation => 'Halation',
    FxKind.mist => 'Black Mist',
    FxKind.grain => 'Körnung',
    FxKind.vignette => 'Vignette',
  };

  IconData _fxIcon(FxKind k) => switch (k) {
    FxKind.grade => Icons.palette_outlined,
    FxKind.flash => Icons.flash_on_outlined,
    FxKind.anamorph => Icons.flare,
    FxKind.halation => Icons.wb_sunny_outlined,
    FxKind.mist => Icons.blur_on,
    FxKind.grain => Icons.grain,
    FxKind.vignette => Icons.vignette_outlined,
  };

  (bool, double) _fxState(FxKind k) {
    final l = _shownLook;
    return switch (k) {
      FxKind.grade => (l.gradeOn, l.gradeAmount),
      FxKind.flash => (l.flashOn, l.flashAmount),
      FxKind.anamorph => (l.anaOn, l.anaAmount),
      FxKind.halation => (l.halOn, l.halAmount),
      FxKind.mist => (l.mistOn, l.mistAmount),
      FxKind.grain => (l.grainOn, l.grainAmount),
      FxKind.vignette => (l.vigOn, l.vigAmount),
    };
  }

  List<Widget> _fxList() {
    return [
      for (final k in FxKind.values)
        Builder(
          builder: (context) {
            final (on, amount) = _fxState(k);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => fx = k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _fxIcon(k),
                          size: 17,
                          color: on ? AppColors.accent : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Text(_fxName(k), style: const TextStyle(fontSize: 13)),
                        const Spacer(),
                        Text(
                          on ? '${(amount * 100).round()} %' : 'Aus',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _fxDetail(FxKind k) {
    final l = _shownLook;
    final (on, _) = _fxState(k);

    // Regler ändern schaltet den Effekt automatisch ein.
    Widget slider(
      String label,
      double value,
      void Function(FilmLook l, double v) set,
    ) {
      return RowSlider(
        label: label,
        value: value * 100,
        max: 100,
        display: '${(value * 100).round()}',
        onStart: store.checkpoint,
        onChanged: (v) => store.edit((d) {
          final look = _editLook(d);
          set(look, v / 100);
          switch (k) {
            case FxKind.grade:
              look.gradeOn = true;
            case FxKind.flash:
              look.flashOn = true;
            case FxKind.anamorph:
              look.anaOn = true;
            case FxKind.halation:
              look.halOn = true;
            case FxKind.mist:
              look.mistOn = true;
            case FxKind.grain:
              look.grainOn = true;
            case FxKind.vignette:
              look.vigOn = true;
          }
        }, record: false),
      );
    }

    void toggle(bool v) => store.edit((d) {
      final look = _editLook(d);
      switch (k) {
        case FxKind.grade:
          look.gradeOn = v;
        case FxKind.flash:
          look.flashOn = v;
        case FxKind.anamorph:
          look.anaOn = v;
        case FxKind.halation:
          look.halOn = v;
        case FxKind.mist:
          look.mistOn = v;
        case FxKind.grain:
          look.grainOn = v;
        case FxKind.vignette:
          look.vigOn = v;
      }
    });

    return [
      Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => fx = null),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(0, 6, 10, 6),
              child: Icon(Icons.chevron_left, size: 22),
            ),
          ),
          Text(_fxName(k), style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            on ? 'Aktiv' : 'Aus',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: on,
              onChanged: toggle,
              activeTrackColor: AppColors.accent,
              activeThumbColor: AppColors.text,
              inactiveTrackColor: AppColors.line,
              inactiveThumbColor: AppColors.muted,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ),
        ],
      ),
      ...switch (k) {
        FxKind.grade => [
          _gradeStyles(l),
          slider('Stärke', l.gradeAmount, (l, v) => l.gradeAmount = v),
        ],
        FxKind.flash => [
          slider('Stärke', l.flashAmount, (l, v) => l.flashAmount = v),
          slider('Abfall', l.flashFalloff, (l, v) => l.flashFalloff = v),
          slider('Höhe', l.flashHeight, (l, v) => l.flashHeight = v),
          slider('Kühle', l.flashCool, (l, v) => l.flashCool = v),
        ],
        FxKind.anamorph => [
          _anaColors(l),
          slider('Stärke', l.anaAmount, (l, v) => l.anaAmount = v),
          slider('Länge', l.anaLength, (l, v) => l.anaLength = v),
          slider('Schwelle', l.anaThreshold, (l, v) => l.anaThreshold = v),
          slider('Dicke', l.anaThickness, (l, v) => l.anaThickness = v),
        ],
        FxKind.halation => [
          slider('Stärke', l.halAmount, (l, v) => l.halAmount = v),
          slider('Radius', l.halRadius, (l, v) => l.halRadius = v),
          slider('Schwelle', l.halThreshold, (l, v) => l.halThreshold = v),
          slider('Wärme', l.halWarmth, (l, v) => l.halWarmth = v),
        ],
        FxKind.mist => [
          _mistPresets(l),
          slider('Stärke', l.mistAmount, (l, v) => l.mistAmount = v),
          slider('Weichheit', l.mistSoftness, (l, v) => l.mistSoftness = v),
          slider('Schatten', l.mistLift, (l, v) => l.mistLift = v),
        ],
        FxKind.grain => [
          slider('Menge', l.grainAmount, (l, v) => l.grainAmount = v),
          slider('Größe', l.grainSize, (l, v) => l.grainSize = v),
          slider('Farbanteil', l.grainColor, (l, v) => l.grainColor = v),
        ],
        FxKind.vignette => [
          slider('Stärke', l.vigAmount, (l, v) => l.vigAmount = v),
          slider('Weichheit', l.vigSoftness, (l, v) => l.vigSoftness = v),
        ],
      },
    ];
  }

  /// Farbe der Anamorph Streifen.
  Widget _anaColors(FilmLook l) {
    const swatch = [Color(0xFF4F9EFF), Color(0xFFFFB838)];
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          for (var i = 0; i < kAnaColorNames.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => store.edit((d) {
                  _editLook(d)
                    ..anaOn = true
                    ..anaColor = i;
                }),
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: l.anaColor == i ? AppColors.accent : AppColors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 18, height: 3, color: swatch[i]),
                      const SizedBox(width: 8),
                      Text(
                        kAnaColorNames[i],
                        style: TextStyle(fontSize: 12, color: l.anaColor == i ? AppColors.text : AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Auswahl der Film Farben als Knöpfe.
  Widget _gradeStyles(FilmLook l) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          for (var i = 0; i < kGradeNames.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => store.edit((d) {
                  _editLook(d)
                    ..gradeOn = true
                    ..gradeStyle = i;
                }),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: l.gradeOn && l.gradeStyle == i ? AppColors.accent : AppColors.line,
                    ),
                  ),
                  child: Text(
                    kGradeNames[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: l.gradeOn && l.gradeStyle == i ? AppColors.text : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Feste Stufen wie bei echten Black Mist Filtern (Stärke, Weichheit, Schatten).
  static const _mistSteps = [
    ('1/8', 0.20, 0.35, 0.15),
    ('1/4', 0.35, 0.45, 0.25),
    ('1/2', 0.55, 0.60, 0.40),
    ('1', 0.80, 0.75, 0.60),
  ];

  Widget _mistPresets(FilmLook l) {
    bool near(double a, double b) => (a - b).abs() < 0.005;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          for (final (name, amount, soft, lift) in _mistSteps) ...[
            if (name != '1/8') const SizedBox(width: 8),
            Expanded(
              child: Builder(builder: (context) {
                final on = l.mistOn && near(l.mistAmount, amount) && near(l.mistSoftness, soft) && near(l.mistLift, lift);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => store.edit((d) {
                    final look = _editLook(d);
                    look
                      ..mistOn = true
                      ..mistAmount = amount
                      ..mistSoftness = soft
                      ..mistLift = lift;
                  }),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: on ? AppColors.accent : AppColors.line),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(fontSize: 12, color: on ? AppColors.text : AppColors.muted),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _holdOriginal() {
    return GestureDetector(
      onTapDown: (_) => setState(() => original = true),
      onTapUp: (_) => setState(() => original = false),
      onTapCancel: () => setState(() => original = false),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: original ? AppColors.line : AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare, size: 16, color: AppColors.text),
            SizedBox(width: 8),
            Text('Halten: Original', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _photosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ActionRow(
          label: kIsWeb ? 'Fotos hinzufügen' : 'Fotos und Videos hinzufügen',
          icon: Icons.add,
          accent: true,
          onTap: store.loading ? null : () => store.pickPhotos(),
        ),
        ActionRow(
          label: 'Mischen',
          icon: Icons.shuffle,
          onTap: store.hasPhotos ? store.shuffle : null,
        ),
        ActionRow(
          label: 'Alle entfernen',
          icon: Icons.delete_outline,
          onTap: store.hasPhotos ? store.removeAll : null,
        ),
        const SizedBox(height: 4),
        const Text(
          'Fotos landen in freien Feldern, bei Bedarf kommen neue dazu (max. 20). '
          'Leeres Feld antippen: mehrere Fotos ab dort. Foto halten: tauschen. Foto antippen: zuschneiden (bei Videos auch der Startpunkt).',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Vier Ecken wie im Sucher einer Kamera.
class _Brackets extends CustomPainter {
  const _Brackets();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 12.0;
    final p = Paint()
      ..color = AppColors.muted
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * len)
          ..lineTo(x, y)
          ..lineTo(x + dx * len, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Brackets oldDelegate) => false;
}
