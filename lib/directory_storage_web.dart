import 'package:web/web.dart' as web;

Future<String?> readDirectory(String key) async => web.window.localStorage.getItem(key);

Future<void> writeDirectory(String key, String value) async {
  web.window.localStorage.setItem(key, value);
}
