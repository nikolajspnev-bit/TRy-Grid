import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'painter.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showExportSheet(BuildContext context, CollageStore store) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) => ExportSheet(store: store),
  );
}

class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.store});
  final CollageStore store;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool uhd = true;
  bool busy = false;
  String? message;

  Size get size => widget.store.design.slideSize(uhd: uhd);
  int get count =>
      widget.store.design.carousel ? widget.store.design.slides : 1;

  String get fileName {
    final clean = widget.store.title
        .replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß _]'), '')
        .trim();
    return clean.isEmpty ? 'Collage' : clean;
  }

  Future<List<Uint8List>> _render() =>
      exportCollage(widget.store.design.clone(), uhd: uhd);

  Future<void> _run(Future<void> Function(List<Uint8List> files) action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action(await _render());
    } catch (e) {
      message = 'Hat nicht geklappt: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  String _name(int i) => count == 1
      ? fileName
      : '${fileName}_${(i + 1).toString().padLeft(2, '0')}';

  Future<void> _save(List<Uint8List> files) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw Exception(
        'Kein Zugriff auf Fotos. Bitte in den Einstellungen erlauben.',
      );
    }
    for (var i = 0; i < files.length; i++) {
      await Gal.putImageBytes(files[i], name: _name(i));
    }
    message = files.length == 1
        ? 'Gespeichert in Fotos.'
        : '${files.length} Bilder in Fotos gespeichert, in der richtigen Reihenfolge.';
  }

  Future<void> _share(List<Uint8List> files) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (var i = 0; i < files.length; i++)
            XFile.fromData(
              files[i],
              mimeType: 'image/png',
              name: '${_name(i)}.png',
            ),
        ],
        fileNameOverrides: [
          for (var i = 0; i < files.length; i++) '${_name(i)}.png',
        ],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.store.design;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Export',
                  style: TextStyle(color: AppColors.accent, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: AspectRatio(
                  aspectRatio: d.canvasRatio,
                  child: CustomPaint(painter: CollagePainter(d, mini: true)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Segmented(
              options: const ['1080p', '4K'],
              selected: uhd ? 1 : 0,
              onChanged: busy ? null : (i) => setState(() => uhd = i == 1),
            ),
            const SizedBox(height: 14),
            if (count > 1) InfoRow('Bilder', '$count Slides'),
            InfoRow(
              'Größe',
              '${size.width.round()} × ${size.height.round()} px',
            ),
            const InfoRow('Format', 'PNG'),
            const SizedBox(height: 18),
            if (!kIsWeb)
              ActionRow(
                label: 'In Fotos sichern',
                icon: Icons.download,
                accent: true,
                onTap: busy ? null : () => _run(_save),
              ),
            ActionRow(
              label: 'Teilen',
              icon: Icons.north_east,
              accent: kIsWeb,
              onTap: busy ? null : () => _run(_share),
            ),
            const SizedBox(height: 10),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}
