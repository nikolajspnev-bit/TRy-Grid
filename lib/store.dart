import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';

/// Hält die Collage und den Verlauf für Rückgängig / Wiederholen.
class CollageStore extends ChangeNotifier {
  Design design = Design();
  String title = 'Neue Collage';
  bool loading = false;

  final List<Design> _undo = [];
  final List<Design> _redo = [];

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
  void addPhotos(List<Photo> photos) {
    if (photos.isEmpty) return;
    edit((d) {
      final used = d.slots.take(d.frames).where((s) => s != null).length;
      final needed = used + photos.length;
      if (needed > d.frames) d.frames = math.min(kMaxSlots, needed);
      final queue = List<Photo>.of(photos);
      for (var i = 0; i < d.visibleCount && queue.isNotEmpty; i++) {
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
  Future<void> pickPhotos({int? intoSlot}) async {
    final picker = ImagePicker();
    final List<XFile> files;
    // imageQuality sorgt dafür, dass HEIC Bilder als JPEG ankommen.
    if (intoSlot != null) {
      final f = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      files = f == null ? [] : [f];
    } else {
      files = await picker.pickMultiImage(imageQuality: 95, limit: kMaxSlots);
    }
    if (files.isEmpty) return;

    loading = true;
    notifyListeners();
    final photos = <Photo>[];
    for (final f in files) {
      final p = await loadPhoto(await f.readAsBytes());
      if (p != null) photos.add(p);
    }
    loading = false;
    if (intoSlot != null && photos.isNotEmpty) {
      setPhoto(intoSlot, photos.first);
    } else {
      addPhotos(photos);
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
