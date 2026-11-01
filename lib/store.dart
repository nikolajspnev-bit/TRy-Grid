import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'drafts.dart';
import 'storage/bytes_store.dart';
import 'video/video_native.dart';
import 'models.dart';

/// Hält die Collage und den Verlauf für Rückgängig / Wiederholen.
class CollageStore extends ChangeNotifier {
  Design design = Design();
  String title = 'Neue Collage';
  bool loading = false;

  final List<Design> _undo = [];
  final List<Design> _redo = [];

  /// Kennung in "Meine Collagen" (null = noch nie gespeichert).
  String? draftId;
  Timer? _saveTimer;
  Future<void>? _saving;
  bool _dirty = false;

  /// Jede Änderung wird nach kurzer Pause automatisch gespeichert.
  @override
  void notifyListeners() {
    super.notifyListeners();
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), saveNow);
  }

  /// Sofort speichern (z. B. bevor "Meine Collagen" geöffnet wird).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    while (_saving != null) {
      await _saving;
    }
    if (!_dirty || !hasPhotos) return;
    _dirty = false;
    final snapshot = design.clone();
    final f = Drafts.instance.save(snapshot, title, draftId).then((id) => draftId = id);
    _saving = f;
    try {
      await f;
    } catch (e) {
      debugPrint('Speichern fehlgeschlagen: $e');
    } finally {
      _saving = null;
    }
  }

  void _reset(Design d, String t, String? id) {
    _saveTimer?.cancel();
    design = d;
    title = t;
    draftId = id;
    _undo.clear();
    _redo.clear();
    super.notifyListeners();
    _dirty = false;
  }

  /// Neue, leere Collage (die alte ist dann schon gespeichert).
  Future<void> newCollage() async {
    await saveNow();
    _reset(Design(), 'Neue Collage', null);
  }

  /// Die gerade offene Collage wurde gelöscht: leer neu anfangen, ohne zu speichern.
  void forgetCurrent() => _reset(Design(), 'Neue Collage', null);

  /// Gespeicherte Collage öffnen.
  Future<bool> openDraft(String id) async {
    await saveNow();
    loading = true;
    super.notifyListeners();
    final r = await Drafts.instance.open(id);
    loading = false;
    if (r == null) {
      super.notifyListeners();
      return false;
    }
    _reset(r.$1, r.$2, id);
    return true;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get hasPhotos => design.slots.any((s) => s != null);

  /// Aktuellen Stand merken, bevor sich etwas ändert.
  void checkpoint() {
    _undo.add(design.clone());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  /// Ändert die Collage. Mit [record] = false ohne neuen Verlaufsschritt
  /// (z. B. während ein Regler gezogen wird).
  void edit(void Function(Design d) change, {bool record = true}) {
    if (record) checkpoint();
    change(design);
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(design);
    design = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(design);
    design = _redo.removeLast();
    notifyListeners();
  }

  void setTitle(String value) {
    title = value;
    notifyListeners();
  }

  void swap(int a, int b) {
    if (a == b) return;
    edit((d) {
      final tmp = d.slots[a];
      d.slots[a] = d.slots[b];
      d.slots[b] = tmp;
    });
  }

  void shuffle() {
    edit((d) {
      final n = d.visibleCount;
      final part = d.slots.sublist(0, n)..shuffle(math.Random());
      for (var i = 0; i < n; i++) {
        d.slots[i] = part[i];
      }
    });
  }

  void removeAll() {
    edit((d) => d.slots = List<Slot?>.filled(kMaxSlots, null));
  }

  /// Verteilt neue Fotos auf freie Felder. Im Raster werden bei Bedarf
  /// automatisch mehr Felder angelegt.
  /// Fügt Fotos in freie Felder ein. Mit [startAt] beginnt es bei diesem
  /// Feld und läuft dann der Reihe nach weiter (danach wieder von vorne).
  void addPhotos(List<Photo> photos, {int startAt = 0}) {
    if (photos.isEmpty) return;
    edit((d) {
      final used = d.slots.take(d.frames).where((s) => s != null).length;
      final needed = used + photos.length;
      if (needed > d.frames) d.frames = math.min(kMaxSlots, needed);
      final queue = List<Photo>.of(photos);
      final n = d.visibleCount;
      for (var k = 0; k < n && queue.isNotEmpty; k++) {
        final i = (startAt + k) % n;
        if (d.slots[i] == null) d.slots[i] = Slot(queue.removeAt(0));
      }
    });
  }

  void setPhoto(int index, Photo photo) {
    edit((d) => d.slots[index] = Slot(photo));
  }

  void removePhoto(int index) {
    edit((d) => d.slots[index] = null);
  }

  /// Fotos aus der Galerie wählen und laden.
  /// [intoSlot]: genau ein Foto für dieses Feld (Ersetzen).
  /// [startAt]: leeres Feld angetippt, mehrere Fotos ab diesem Feld.
  Future<void> pickPhotos({int? intoSlot, int startAt = 0}) async {
    final picker = ImagePicker();
    final List<XFile> files;
    // imageQuality sorgt dafür, dass HEIC Bilder als JPEG ankommen.
    // In der App gehen auch Videos, im Browser nur Fotos.
    if (intoSlot != null) {
      final f = kIsWeb
          ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 95)
          : await picker.pickMedia(imageQuality: 95);
      files = f == null ? [] : [f];
    } else {
      files = kIsWeb
          ? await picker.pickMultiImage(imageQuality: 95, limit: kMaxSlots)
          : await picker.pickMultipleMedia(imageQuality: 95, limit: kMaxSlots);
    }
    if (files.isEmpty) return;

    loading = true;
    notifyListeners();
    final photos = <Photo>[];
    for (final f in files) {
      final p = !kIsWeb && isVideoFile(f) ? await loadVideo(f.path) : await loadPhoto(await f.readAsBytes());
      if (p != null) photos.add(p);
    }
    loading = false;
    if (intoSlot != null && photos.isNotEmpty) {
      setPhoto(intoSlot, photos.first);
    } else {
      addPhotos(photos, startAt: startAt);
    }
    notifyListeners();
  }
}

/// Dekodiert ein Foto und erzeugt eine kleine Vorschau (max. 1600 px).
Future<Photo?> loadPhoto(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (w, h) {
        const maxSide = 1600;
        if (math.max(w, h) <= maxSide) {
          return ui.TargetImageSize(width: w, height: h);
        }
        return w >= h
            ? const ui.TargetImageSize(width: maxSide)
            : const ui.TargetImageSize(height: maxSide);
      },
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    return Photo(bytes: bytes, preview: frame.image);
  } catch (e) {
    debugPrint('Foto konnte nicht geladen werden: $e');
    return null;
  }
}

bool isVideoFile(XFile f) {
  final mime = f.mimeType ?? '';
  if (mime.startsWith('video/')) return true;
  final n = f.path.toLowerCase();
  return ['.mp4', '.mov', '.m4v', '.3gp', '.webm', '.mkv'].any(n.endsWith);
}

/// Video in den App Speicher übernehmen und das erste Bild als Vorschau holen.
Future<Photo?> loadVideo(String sourcePath) async {
  try {
    final name = await BytesStore.instance.importVideo(sourcePath);
    if (name == null) return null;
    return await openVideo(name);
  } catch (e) {
    debugPrint('Video konnte nicht geladen werden: $e');
    return null;
  }
}

/// Gespeichertes Video öffnen (Vorschaubild und Länge).
Future<Photo?> openVideo(String name) async {
  try {
    final path = await BytesStore.instance.videoPath(name);
    if (path == null) return null;
    final info = await VideoNative.probe(path);
    final poster = await VideoNative.frameAt(path, 0);
    final png = await poster.toByteData(format: ui.ImageByteFormat.png);
    return Photo(
      bytes: png!.buffer.asUint8List(),
      preview: poster,
      video: VideoSource(name: name, path: path, durationMs: info.durationMs),
    );
  } catch (e) {
    debugPrint('Video konnte nicht geöffnet werden: $e');
    return null;
  }
}
