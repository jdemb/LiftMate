import 'dart:convert';

import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
  });

  static const defaultAssetPath = 'config/app_config.json';

  final String apiBaseUrl;

  static Future<AppConfig> load({
    AssetBundle? bundle,
    String assetPath = defaultAssetPath,
  }) async {
    const apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrlOverride.trim().isNotEmpty) {
      return AppConfig(apiBaseUrl: apiBaseUrlOverride.trim());
    }

    final assetBundle = bundle ?? rootBundle;
    final rawConfig = await assetBundle.loadString(assetPath);
    final decoded = jsonDecode(rawConfig);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('App config must be a JSON object.');
    }

    final apiBaseUrl = decoded['apiBaseUrl'];
    if (apiBaseUrl is! String || apiBaseUrl.trim().isEmpty) {
      throw const FormatException('App config requires apiBaseUrl.');
    }

    return AppConfig(apiBaseUrl: apiBaseUrl.trim());
  }
}
