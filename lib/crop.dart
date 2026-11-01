import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';
import 'video/video_native.dart';

enum CropAction { save, replace, remove }

class CropResult {
  CropResult(
    this.action, {
    this.zoom = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.videoStartMs = 0,
    this.startFrame,
  });
  final CropAction action;
  final double zoom;
  final double offsetX;
  final double offsetY;
  final int videoStartMs;
  final ui.Image? startFrame;
}

/// Bild im Feld zoomen und verschieben.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.slot, required this.cellAspect});
  final Slot slot;

  /// Breite geteilt durch Höhe des Feldes.
  final double cellAspect;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  static const maxZoom = 5.0;
  late double zoom = widget.slot.zoom;
  late double ox = widget.slot.offsetX;
  late double oy = widget.slot.offsetY;

  double _startZoom = 1;

  // Video: Startpunkt (wird beim Loslassen des Reglers geladen).
  late double startMs = widget.slot.videoStartMs.toDouble();
  bool loadingFrame = false;

  Future<void> _loadStart() async {
    final v = widget.slot.photo.video;
    if (v == null) return;
    setState(() => loadingFrame = true);
    try {
      final img = await VideoNative.frameAt(v.path, startMs.round());
      widget.slot
        ..startFrame = img
        ..videoStartMs = startMs.round();
    } catch (_) {}
    if (mounted) setState(() => loadingFrame = false);
  }

  String _time(double ms) {
    final s = (ms / 1000).floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
  Rect _cell = Rect.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Abbrechen',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        leadingWidth: 110,
        title: Text(widget.slot.photo.video != null ? 'Video' : 'Zuschneiden'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              CropResult(
                CropAction.save,
                zoom: zoom,
                offsetX: ox,
                offsetY: oy,
                videoStartMs: widget.slot.videoStartMs,
                startFrame: widget.slot.startFrame,
              ),
            ),
            child: const Text(
              'Fertig',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  const margin = 32.0;
                  var w = c.maxWidth - margin * 2;
                  var h = w / widget.cellAspect;
                  if (h > c.maxHeight - margin * 2) {
                    h = c.maxHeight - margin * 2;
                    w = h * widget.cellAspect;
                  }
                  _cell = Rect.fromCenter(
                    center: Offset(c.maxWidth / 2, c.maxHeight / 2),
                    width: w,
                    height: h,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) => _startZoom = zoom,
                    onScaleUpdate: _onScale,
                    child: CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _CropPainter(widget.slot, _cell, zoom, ox, oy, widget.slot.shown),
                    ),
                  );
                },
              ),
            ),
            if (widget.slot.photo.video != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const SizedBox(width: 44, child: Text('Start', style: TextStyle(fontSize: 12))),
                    Expanded(
                      child: Slider(
                        value: startMs.clamp(0, _maxStart),
                        min: 0,
                        max: _maxStart,
                        onChanged: (v) => setState(() => startMs = v),
                        onChangeEnd: (_) => _loadStart(),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: loadingFrame
                          ? const Center(
                              child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
                              ),
                            )
                          : Text(
                              _time(startMs),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: AppColors.accent),
                            ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.zoom_out, color: AppColors.muted),
                  Expanded(
                    child: Slider(
                      value: zoom,
                      min: 1,
                      max: maxZoom,
                      onChanged: (v) => setState(() => zoom = v),
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: AppColors.muted),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _action(
                    Icons.restart_alt,
                    'Zurücksetzen',
                    () => setState(() {
                      zoom = 1;
                      ox = 0;
                      oy = 0;
                    }),
                  ),
                  _action(
                    Icons.swap_horiz,
                    'Ersetzen',
                    () =>
                        Navigator.pop(context, CropResult(CropAction.replace)),
                  ),
                  _action(
                    Icons.delete_outline,
                    'Entfernen',
                    () => Navigator.pop(context, CropResult(CropAction.remove)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _maxStart {
    final d = widget.slot.photo.video?.durationMs ?? 0;
    return (d - 500).clamp(1, 1 << 30).toDouble();
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.text),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _onScale(ScaleUpdateDetails e) {
    setState(() {
      if (e.pointerCount > 1) {
        zoom = (_startZoom * e.scale).clamp(1.0, maxZoom);
      }
      // Verschieben: Fingerbewegung in Pixeln in den Bereich -1 bis 1 umrechnen.
      final p = widget.slot.photo;
      final r = imageRect(p.width, p.height, _cell, zoom, ox, oy);
      final overX = r.width - _cell.width;
      final overY = r.height - _cell.height;
      if (overX > 0.5) {
        ox = (ox + 2 * e.focalPointDelta.dx / overX).clamp(-1.0, 1.0);
      }
      if (overY > 0.5) {
        oy = (oy + 2 * e.focalPointDelta.dy / overY).clamp(-1.0, 1.0);
      }
    });
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.slot, this.cell, this.zoom, this.ox, this.oy, this.img);
  final Slot slot;
  final ui.Image img;
  final Rect cell;
  final double zoom, ox, oy;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = imageRect(
      slot.photo.width,
      slot.photo.height,
      cell,
      zoom,
      ox,
      oy,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );

    // Überstand abgedunkelt zeigen, damit man sieht, was abgeschnitten wird.
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()..color = const Color(0x4DFFFFFF),
    );
    canvas.save();
    canvas.clipRect(cell);
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // Rahmen und Drittel Hilfslinien.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = cell.left + cell.width * i / 3;
      final y = cell.top + cell.height * i / 3;
      canvas.drawLine(Offset(x, cell.top), Offset(x, cell.bottom), line);
      canvas.drawLine(Offset(cell.left, y), Offset(cell.right, y), line);
    }
    canvas.drawRect(
      cell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.zoom != zoom || old.ox != ox || old.oy != oy || old.cell != cell || old.img != img;
}
