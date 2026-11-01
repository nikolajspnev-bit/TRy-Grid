import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';
import 'painter.dart';
import 'storage/bytes_store.dart';
import 'store.dart';
import 'video/video_native.dart';

/// Eintrag in "Meine Collagen".
class DraftInfo {
  DraftInfo({required this.id, required this.title, required this.updated});
  final String id;
  final String title;
  final DateTime updated;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updated': updated.millisecondsSinceEpoch,
  };

  static DraftInfo fromJson(Map<String, dynamic> j) => DraftInfo(
    id: j['id'] as String,
    title: (j['title'] as String?) ?? 'Collage',
    updated: DateTime.fromMillisecondsSinceEpoch((j['updated'] as num).toInt()),
  );
}

/// Speichert Collagen dauerhaft auf dem Gerät (Fotos nur einmal).
class Drafts {
  Drafts._();
  static final instance = Drafts._();

  BytesStore get _s => BytesStore.instance;
  static const _index = 'index.json';

  Future<List<DraftInfo>> list() async {
    final raw = await _s.get(_index);
    if (raw == null) return [];
    try {
      final list = jsonDecode(utf8.decode(raw)) as List;
      final out = [for (final e in list) DraftInfo.fromJson((e as Map).cast<String, dynamic>())];
      out.sort((a, b) => b.updated.compareTo(a.updated));
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeIndex(List<DraftInfo> list) =>
      _s.put(_index, Uint8List.fromList(utf8.encode(jsonEncode([for (final d in list) d.toJson()]))));

  Future<Uint8List?> thumb(String id) => _s.get('t_$id');

  /// Speichert die Collage unter [id] (neu, falls null). Gibt die id zurück.
  Future<String> save(Design design, String title, String? id) async {
    final newId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    for (final slot in design.slots) {
      if (slot == null) continue;
      // Videos liegen schon als Datei im App Speicher.
      if (slot.photo.video != null) continue;
      final key = 'p_${slot.photo.key}';
      if (!await _s.has(key)) await _s.put(key, slot.photo.bytes);
    }
    final json = {'title': title, 'design': design.toJson()};
    await _s.put('d_$newId', Uint8List.fromList(utf8.encode(jsonEncode(json))));
    await _s.put('t_$newId', await renderThumb(design));
    final list = (await this.list()).where((d) => d.id != newId).toList()
      ..add(DraftInfo(id: newId, title: title, updated: DateTime.now()));
    await _writeIndex(list);
    return newId;
  }

  /// Lädt eine Collage. null, wenn sie fehlt.
  Future<(Design, String)?> open(String id) async {
    final raw = await _s.get('d_$id');
    if (raw == null) return null;
    final j = (jsonDecode(utf8.decode(raw)) as Map).cast<String, dynamic>();
    final dj = (j['design'] as Map).cast<String, dynamic>();
    final photos = <String, Photo>{};
    for (final key in Design.photoKeysIn(dj)) {
      if (key.startsWith('v-')) {
        final p = await openVideo(key.substring(2));
        if (p != null) photos[key] = p;
        continue;
      }
      final bytes = await _s.get('p_$key');
      if (bytes == null) continue;
      final p = await loadPhoto(bytes);
      if (p != null) photos[key] = p;
    }
    final design = Design.fromJson(dj, photos);
    // Videos mit späterem Start: passendes Vorschaubild holen.
    for (final slot in design.slots) {
      final v = slot?.photo.video;
      if (slot == null || v == null || slot.videoStartMs <= 0) continue;
      try {
        slot.startFrame = await VideoNative.frameAt(v.path, slot.videoStartMs);
      } catch (_) {}
    }
    return (design, (j['title'] as String?) ?? 'Collage');
  }

  /// Löscht eine Collage und Fotos, die keine andere Collage mehr braucht.
  Future<void> remove(String id) async {
    final raw = await _s.get('d_$id');
    final rest = (await list()).where((d) => d.id != id).toList();
    await _writeIndex(rest);
    await _s.delete('d_$id');
    await _s.delete('t_$id');
    if (raw == null) return;
    final mine = Design.photoKeysIn(
      ((jsonDecode(utf8.decode(raw)) as Map)['design'] as Map).cast<String, dynamic>(),
    );
    final used = <String>{};
    for (final d in rest) {
      final r = await _s.get('d_${d.id}');
      if (r == null) continue;
      used.addAll(Design.photoKeysIn(
        ((jsonDecode(utf8.decode(r)) as Map)['design'] as Map).cast<String, dynamic>(),
      ));
    }
    for (final k in mine.difference(used)) {
      if (k.startsWith('v-')) {
        await _s.deleteVideo(k.substring(2));
      } else {
        await _s.delete('p_$k');
      }
    }
  }
}
