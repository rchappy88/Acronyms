import 'package:shared_preferences/shared_preferences.dart';

Future<String?> readDirectory(String key) async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getString(key);
}

Future<void> writeDirectory(String key, String value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(key, value);
}
