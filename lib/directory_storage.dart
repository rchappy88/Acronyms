import 'directory_storage_io.dart'
    if (dart.library.html) 'directory_storage_web.dart' as storage;

Future<String?> readDirectory(String key) => storage.readDirectory(key);

Future<void> writeDirectory(String key, String value) => storage.writeDirectory(key, value);
