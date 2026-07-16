import 'api_config.dart';

class IntegrationAuth {
  final String type;
  final Map<String, dynamic> raw;

  const IntegrationAuth({
    required this.type,
    required this.raw,
  });

  factory IntegrationAuth.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    return IntegrationAuth(
      type: source['type']?.toString().toLowerCase() ?? 'none',
      raw: Map<String, dynamic>.from(source),
    );
  }

  String get displayLabel {
    switch (type) {
      case 'api_key':
        return 'API KEY';
      case 'bearer':
        return 'BEARER';
      case 'oauth2':
        return 'OAUTH2';
      default:
        return 'NONE';
    }
  }
}

class IntegrationAction {
  final String id;
  final String path;
  final String method;
  final String description;

  const IntegrationAction({
    required this.id,
    required this.path,
    required this.method,
    required this.description,
  });

  factory IntegrationAction.fromMap(Map<String, dynamic> map) {
    return IntegrationAction(
      id: map['id']?.toString() ?? 'unknown_action',
      path: map['path']?.toString() ?? '/',
      method: map['method']?.toString().toUpperCase() ?? 'GET',
      description: map['description']?.toString() ?? '',
    );
  }
}

class IntegrationApp {
  final String id;
  final String name;
  final bool enabled;
  final String baseUrl;
  final String authType;
  final IntegrationAuth auth;
  final List<IntegrationAction> actions;

  const IntegrationApp({
    required this.id,
    required this.name,
    required this.enabled,
    required this.baseUrl,
    required this.authType,
    required this.auth,
    required this.actions,
  });

  factory IntegrationApp.fromMap(Map<String, dynamic> map) {
    final actionsRaw = map['actions'];
    final actionsList = actionsRaw is List ? actionsRaw : const [];

    return IntegrationApp(
      id: map['id']?.toString() ?? 'unknown_app',
      name: map['name']?.toString() ?? 'Unknown App',
      enabled: map['enabled'] == true,
      baseUrl: map['base_url']?.toString() ?? '',
      authType: map['auth_type']?.toString() ?? 'none',
      auth: IntegrationAuth.fromMap(
        map['auth'] is Map ? Map<String, dynamic>.from(map['auth']) : null,
      ),
      actions: actionsList
          .whereType<Map>()
          .map((item) => IntegrationAction.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class IntegrationHubService {
  static Future<List<IntegrationApp>> getEnabledApps() async {
    final manifest = await ApiService.getIntegrationManifest();
    final appsRaw = manifest['apps'];
    final appsList = appsRaw is List ? appsRaw : const [];

    return appsList
        .whereType<Map>()
        .map((item) => IntegrationApp.fromMap(Map<String, dynamic>.from(item)))
        .where((app) => app.enabled)
        .toList();
  }

  static Future<Map<String, dynamic>> runAction({
    required IntegrationApp app,
    required IntegrationAction action,
    Map<String, dynamic>? payload,
  }) async {
    return ApiService.executeIntegrationAction(
      appId: app.id,
      actionId: action.id,
      payload: payload ?? <String, dynamic>{},
      authConfig: app.auth.raw,
    );
  }
}
