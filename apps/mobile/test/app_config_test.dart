import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/app_config.dart';

void main() {
  test('loads API base URL from config asset', () async {
    final config = await AppConfig.load(
      bundle: _StringAssetBundle({
        'config/app_config.json': '{"apiBaseUrl":"https://api.example.test"}',
      }),
    );

    expect(config.apiBaseUrl, 'https://api.example.test');
  });

  test('trims API base URL from config asset', () async {
    final config = await AppConfig.load(
      bundle: _StringAssetBundle({
        'config/app_config.json': '{"apiBaseUrl":" https://api.example.test/ "}',
      }),
    );

    expect(config.apiBaseUrl, 'https://api.example.test/');
  });

  test('rejects config without API base URL', () async {
    expect(
      AppConfig.load(
        bundle: _StringAssetBundle({
          'config/app_config.json': '{}',
        }),
      ),
      throwsFormatException,
    );
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Asset not found: $key');
    }

    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}
