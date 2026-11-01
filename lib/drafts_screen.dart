import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'drafts.dart';
import 'store.dart';
import 'theme.dart';

/// "Meine Collagen": alle gespeicherten Collagen, antippen zum Öffnen.
class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key, required this.store});
  final CollageStore store;

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<DraftInfo>? items;
  final thumbs = <String, Uint8List?>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.store.saveNow();
    final list = await Drafts.instance.list();
    for (final d in list) {
      thumbs[d.id] = await Drafts.instance.thumb(d.id);
    }
    if (mounted) setState(() => items = list);
  }

  String _date(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} · ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _delete(DraftInfo d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Löschen?', style: TextStyle(fontSize: 15)),
        content: Text('„${d.title}“ wird vom Gerät gelöscht.', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (widget.store.draftId == d.id) widget.store.forgetCurrent();
    await Drafts.instance.remove(d.id);
    setState(() {
      items = items!.where((e) => e.id != d.id).toList();
      thumbs.remove(d.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left, size: 24),
                  ),
                  const Text(
                    'MEINE COLLAGEN',
                    style: TextStyle(fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await widget.store.newCollage();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 15, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text('Neu', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list == null
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    )
                  : list.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Noch nichts gespeichert. Jede Collage mit Fotos wird automatisch hier abgelegt.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: list.length,
                          itemBuilder: (context, i) => _card(list[i]),
                        ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Wird nur auf diesem Gerät gespeichert.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(DraftInfo d) {
    final current = widget.store.draftId == d.id;
    final thumb = thumbs[d.id];
    return GestureDetector(
      onTap: () async {
        final ok = await widget.store.openDraft(d.id);
        if (!mounted) return;
        if (ok) {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konnte nicht geöffnet werden.')),
          );
        }
      },
      onLongPress: () => _delete(d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: current ? AppColors.accent : AppColors.line),
              ),
              padding: const EdgeInsets.all(8),
              child: thumb == null
                  ? const SizedBox()
                  : Image.memory(thumb, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    Text(_date(d.updated), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _delete(d),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 17, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
