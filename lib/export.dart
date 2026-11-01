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
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

  Size get size => widget.store.design.format.exportSize(uhd: uhd);

  String get fileName {
    final clean = widget.store.title
        .replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß _]'), '')
        .trim();
    return clean.isEmpty ? 'Collage' : clean;
  }

  Future<Uint8List> _render() =>
      exportCollage(widget.store.design.clone(), size);

  Future<void> _run(Future<void> Function(Uint8List bytes) action) async {
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

  Future<void> _save(Uint8List bytes) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      throw Exception(
        'Kein Zugriff auf Fotos. Bitte in den Einstellungen erlauben.',
      );
    }
    await Gal.putImageBytes(bytes, name: fileName);
    message = 'Gespeichert in Fotos.';
  }

  Future<void> _share(Uint8List bytes) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'image/png', name: '$fileName.png'),
        ],
        fileNameOverrides: ['$fileName.png'],
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
              child: SizedBox(
                height: 150,
                child: AspectRatio(
                  aspectRatio: d.format.ratio,
                  child: CustomPaint(painter: CollagePainter(d, dragFrom: -1)),
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
