import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'bytes_store.dart';

BytesStore createStore() => _FileStore();

class _FileStore implements BytesStore {
  Directory? _dir;

  Future<File> _file(String key) async {
    _dir ??= await Directory(
      '${(await getApplicationDocumentsDirectory()).path}/collagen',
    ).create(recursive: true);
    return File('${_dir!.path}/${key.replaceAll('/', '__')}');
  }

  @override
  Future<void> put(String key, Uint8List bytes) async {
    final f = await _file(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<Uint8List?> get(String key) async {
    final f = await _file(key);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String key) async {
    final f = await _file(key);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<bool> has(String key) async => (await _file(key)).exists();
}
