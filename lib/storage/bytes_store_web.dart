import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'bytes_store.dart';

BytesStore createStore() => _IdbStore();

class _IdbStore implements BytesStore {
  static const _store = 'files';
  Database? _db;

  Future<Database> _open() async => _db ??= await idbFactoryBrowser.open(
    'try_grid',
    version: 1,
    onUpgradeNeeded: (e) => e.database.createObjectStore(_store),
  );

  @override
  Future<void> put(String key, Uint8List bytes) async {
    final tx = (await _open()).transaction(_store, idbModeReadWrite);
    await tx.objectStore(_store).put(bytes, key);
    await tx.completed;
  }

  @override
  Future<Uint8List?> get(String key) async {
    final tx = (await _open()).transaction(_store, idbModeReadOnly);
    final v = await tx.objectStore(_store).getObject(key);
    await tx.completed;
    if (v == null) return null;
    if (v is Uint8List) return v;
    if (v is ByteBuffer) return v.asUint8List();
    if (v is List) return Uint8List.fromList(v.cast<int>());
    return null;
  }

  @override
  Future<void> delete(String key) async {
    final tx = (await _open()).transaction(_store, idbModeReadWrite);
    await tx.objectStore(_store).delete(key);
    await tx.completed;
  }

  @override
  Future<bool> has(String key) async => (await get(key)) != null;
}
