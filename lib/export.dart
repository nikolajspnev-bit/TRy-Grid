import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'painter.dart';
import 'video/video_export.dart';
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
  bool overview = false;
  bool busy = false;

  /// Video Export (nur in der App, wenn Videos in der Collage sind).
  late bool asVideo = canVideo;
  late double seconds = _defaultSeconds();
  double progress = 0;

  bool get hasVideo => widget.store.design.hasVideo;
  bool get canVideo => hasVideo && !kIsWeb && !widget.store.design.carousel;
  double get maxSeconds =>
      longestClipSeconds(widget.store.design).clamp(1, 60).toDouble();
  double _defaultSeconds() =>
      hasVideo ? maxSeconds.clamp(1, 15).roundToDouble() : 5;

  Future<String> _renderVideo() async {
    final dir = await getTemporaryDirectory();
    final out =
        '${dir.path}/${fileName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    return exportVideoCollage(
      widget.store.design.clone(),
      seconds: seconds,
      outPath: out,
      onProgress: (p) {
        if (mounted) setState(() => progress = p);
      },
    );
  }

  Future<void> _runVideo(bool share) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      busy = true;
      progress = 0;
      message = null;
    });
    try {
      final path = await _renderVideo();
      if (share) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: 'video/mp4', name: '$fileName.mp4')],
            sharePositionOrigin: origin,
          ),
        );
      } else {
        if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
          throw Exception(
            'Kein Zugriff auf Fotos. Bitte in den Einstellungen erlauben.',
          );
        }
        await Gal.putVideo(path);
        message = 'Video in Fotos gespeichert.';
      }
    } catch (e) {
      message = 'Hat nicht geklappt: $e';
    }
    if (mounted) setState(() => busy = false);
  }

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

  Future<List<Uint8List>> _render() => exportCollage(
    widget.store.design.clone(),
    uhd: uhd,
    overview: overview && count > 1,
  );

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
      : i >= count
      ? '${fileName}_Gesamt'
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
            if (canVideo) ...[
              Segmented(
                options: const ['Video MP4', 'Bild PNG'],
                selected: asVideo ? 0 : 1,
                onChanged: busy
                    ? null
                    : (i) => setState(() => asVideo = i == 0),
              ),
              const SizedBox(height: 10),
            ],
            if (hasVideo && !canVideo)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  kIsWeb
                      ? 'Video Export geht nur in der App. Hier wird das erste Bild gespeichert.'
                      : 'Video im Karussell kommt später. Hier wird das Startbild gespeichert.',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            if (asVideo && canVideo)
              ..._videoOptions()
            else
              ..._imageOptions(d),
            const SizedBox(height: 10),
            if (busy)
              Center(
                child: asVideo && canVideo
                    ? Text(
                        'Video wird erstellt: ${(progress * 100).round()} %',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                      )
                    : const SizedBox(
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

  List<Widget> _videoOptions() => [
    RowSlider(
      label: 'Länge',
      value: seconds.clamp(1, maxSeconds),
      min: 1,
      max: maxSeconds < 1.5 ? 1.5 : maxSeconds,
      display: '${seconds.round()} s',
      onChanged: busy
          ? null
          : (v) => setState(
              () => seconds = v.roundToDouble().clamp(1, maxSeconds),
            ),
    ),
    const InfoRow('Größe', '1080p, 30 Bilder/s'),
    const InfoRow('Ton', 'ohne'),
    const SizedBox(height: 14),
    ActionRow(
      label: 'In Fotos sichern',
      icon: Icons.download,
      accent: true,
      onTap: busy ? null : () => _runVideo(false),
    ),
    ActionRow(
      label: 'Teilen',
      icon: Icons.north_east,
      onTap: busy ? null : () => _runVideo(true),
    ),
  ];

  List<Widget> _imageOptions(Object d) => [
    Segmented(
      options: const ['1080p', '4K'],
      selected: uhd ? 1 : 0,
      onChanged: busy ? null : (i) => setState(() => uhd = i == 1),
    ),
    const SizedBox(height: 14),
    if (count > 1) InfoRow('Bilder', '$count Slides'),
    if (count > 1)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            const Text(
              'Gesamtbild dazu',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const Spacer(),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: overview,
                onChanged: busy ? null : (v) => setState(() => overview = v),
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
      ),
    InfoRow('Größe', '${size.width.round()} × ${size.height.round()} px'),
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
  ];
}
