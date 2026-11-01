import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'crop.dart';
import 'export.dart';
import 'models.dart';
import 'painter.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

enum PanelTab { design, fx, photos }

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

  // "Halten für Original"
  bool original = false;

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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Halten zum Tauschen · Tippen zum Zuschneiden',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
      child: Row(
        children: [
          PopupMenuButton<AspectFormat>(
            tooltip: 'Format',
            color: AppColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            offset: const Offset(0, 44),
            onSelected: (f) => store.edit((d) => d.format = f),
            itemBuilder: (_) => [
              for (final f in AspectFormat.values)
                PopupMenuItem(
                  value: f,
                  child: Row(
                    children: [
                      Icon(
                        f == d.format
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 16,
                        color: f == d.format
                            ? AppColors.accent
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${f.description} ${f.label}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${f.exportSize(uhd: true).width.round()} × ${f.exportSize(uhd: true).height.round()}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.format.label, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 2),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _rename,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      store.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 13, color: AppColors.muted),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Exportieren',
            onPressed: store.hasPhotos
                ? () => showExportSheet(context, store)
                : null,
            icon: const Icon(Icons.north_east, size: 26),
            color: AppColors.accent,
            disabledColor: AppColors.line,
          ),
        ],
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
        var w = c.maxWidth - pad * 2;
        var h = w / d.format.ratio;
        if (h > c.maxHeight - pad) {
          h = c.maxHeight - pad;
          w = h * d.format.ratio;
        }
        final size = Size(w, h);
        final unit = w / 400;
        final border = d.border * unit;
        final frames = cellFrames(
          d.normalizedRects,
          size,
          border,
          d.spacing * unit,
        );
        final innerW = w - 2 * border, innerH = h - 2 * border;

        int? hit(Offset p) {
          for (var i = 0; i < frames.length; i++) {
            if (frames[i].contains(p)) return i;
          }
          return null;
        }

        // Nächste Trennlinie unter dem Finger (max. 22 px entfernt).
        Seam? seamAt(Offset p) {
          Seam? best;
          var bestDist = 22.0;
          for (final s in findSeams(d.normalizedRects)) {
            final cs = seamOnCanvas(s, size, border);
            final along = s.vertical ? p.dy : p.dx;
            final lo = s.vertical ? cs.a.dy : cs.a.dx;
            final hi = s.vertical ? cs.b.dy : cs.b.dx;
            if (along < lo || along > hi) continue;
            final dist = s.vertical
                ? (p.dx - cs.a.dx).abs()
                : (p.dy - cs.a.dy).abs();
            if (dist < bestDist) {
              bestDist = dist;
              best = s;
            }
          }
          return best;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onPanStart: (e) {
                final s = seamAt(e.localPosition);
                if (s == null) return;
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
                if (s == null || innerW <= 0 || innerH <= 0) return;
                seamDelta += s.vertical
                    ? e.delta.dx / innerW
                    : e.delta.dy / innerH;
                store.edit(
                  (d) => d.customRects = moveSeam(seamBase, s, seamDelta),
                  record: false,
                );
              },
              onPanEnd: (_) => setState(() => seam = null),
              onPanCancel: () => setState(() => seam = null),
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
                size: size,
                painter: CollagePainter(
                  d,
                  dragFrom: dragFrom,
                  dragTarget: dragTarget,
                  original: original,
                  activeSeam: seam == null
                      ? null
                      : Seam(
                          vertical: seam!.vertical,
                          pos: seam!.pos + seamDelta,
                          start: seam!.start,
                          end: seam!.end,
                        ),
                ),
              ),
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

  Future<void> _openSlot(int i) async {
    final slot = store.design.slots[i];
    if (slot == null) {
      await store.pickPhotos(intoSlot: i);
      return;
    }
    final d = store.design;
    // Seitenverhältnis des Feldes auf einer Referenzleinwand berechnen.
    final ref = Size(1000, 1000 / d.format.ratio);
    final unit = ref.width / 400;
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
    const titles = {
      PanelTab.design: 'Design',
      PanelTab.fx: 'FX',
      PanelTab.photos: 'Fotos',
    };
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(18, 6, 14, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(titles[tab]!, style: const TextStyle(fontSize: 14)),
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
          SizedBox(
            height: 232,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 4),
              child: switch (tab) {
                PanelTab.design => _designTab(),
                PanelTab.fx => _fxTab(),
                PanelTab.photos => _photosTab(),
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _tabButton(PanelTab.design, Icons.grid_view),
              _tabButton(PanelTab.fx, Icons.auto_awesome_outlined),
              _tabButton(PanelTab.photos, Icons.photo_library_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: AppColors.text,
      disabledColor: AppColors.line,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _tabButton(PanelTab t, IconData icon) {
    final active = tab == t;
    return IconButton(
      onPressed: () => setState(() => tab = t),
      icon: Icon(icon, size: 24),
      color: active ? AppColors.text : AppColors.muted,
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
      Color(0xFF6B4F3A),
    ];
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
                  GestureDetector(
                    onTap: () => store.edit((d) => d.background = c),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: d.background == c
                              ? AppColors.accent
                              : AppColors.line,
                          width: d.background == c ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fxTab() {
    final look = store.design.look;
    String pct(double v) => '${(v * 100).round()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        RowSlider(
          label: 'Halation',
          value: look.halation * 100,
          max: 100,
          display: pct(look.halation),
          onStart: store.checkpoint,
          onChanged: (v) =>
              store.edit((d) => d.look.halation = v / 100, record: false),
        ),
        RowSlider(
          label: 'Black Mist',
          value: look.mist * 100,
          max: 100,
          display: pct(look.mist),
          onStart: store.checkpoint,
          onChanged: (v) =>
              store.edit((d) => d.look.mist = v / 100, record: false),
        ),
        RowSlider(
          label: 'Körnung',
          value: look.grain * 100,
          max: 100,
          display: pct(look.grain),
          onStart: store.checkpoint,
          onChanged: (v) =>
              store.edit((d) => d.look.grain = v / 100, record: false),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => setState(() => original = true),
                onTapUp: (_) => setState(() => original = false),
                onTapCancel: () => setState(() => original = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
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
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: look.active
                    ? () => store.edit((d) => d.look = FilmLook())
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restart_alt,
                        size: 16,
                        color: look.active ? AppColors.text : AppColors.line,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zurücksetzen',
                        style: TextStyle(
                          fontSize: 13,
                          color: look.active ? AppColors.text : AppColors.line,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Wirkt auf alle Fotos.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _photosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ActionRow(
          label: 'Fotos hinzufügen',
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
          'Fotos landen in freien Feldern. Bei Bedarf kommen neue Felder dazu (max. 12).',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
