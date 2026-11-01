import 'dart:typed_data';

import 'bytes_store_io.dart' if (dart.library.js_interop) 'bytes_store_web.dart' as impl;

/// Einfacher Speicher für Dateien (Schlüssel → Bytes).
/// In der App: Ordner im App Speicher. Im Browser: IndexedDB.
abstract class BytesStore {
  Future<void> put(String key, Uint8List bytes);
  Future<Uint8List?> get(String key);
  Future<void> delete(String key);
  Future<bool> has(String key);

  static BytesStore? _instance;
  static BytesStore get instance => _instance ??= impl.createStore();
}
