import 'dart:convert';

import 'package:universal_html/html.dart' as html;

import 'api_config.dart';

/// Calls the real, Claude-powered backend endpoint (/api/ai-resume-assist)
/// added to lib/compression_server.js (the live Node.js backend).
///
/// IMPORTANT: this only ever gets called for users already confirmed to be
/// on a paid plan (PlanCatalogConfig.isPaidPlan) - the caller in
/// ai_resume_builder_page.dart checks that BEFORE calling this service,
/// exactly like every other premium-feature gate in this app
/// (see Widgets/quota_gate.dart). Free-tier users never trigger a real,
/// billable AI call. The server independently re-verifies the paid plan
/// server-side using the email passed here - the client-side check above
/// is a UX gate, not the security boundary.
class RealAiAssistService {
  RealAiAssistService._();

  static Future<String> request(String action, Map<String, dynamic> data, String email) async {
    final url = '${ApiConfig.baseUrl}/api/ai-resume-assist';
    html.HttpRequest response;
    try {
      response = await html.HttpRequest.request(
        url,
        method: 'POST',
        sendData: jsonEncode({'action': action, 'data': data, 'email': email}),
        requestHeaders: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
    } catch (_) {
      throw Exception('Could not reach the AI service. Please check your connection and try again.');
    }

    final raw = response.responseText ?? '{}';
    Map<String, dynamic> mapped;
    try {
      final decoded = jsonDecode(raw);
      mapped = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      throw Exception('The AI service returned an unexpected response. Please try again.');
    }

    if (mapped['success'] != true) {
      throw Exception(mapped['error']?.toString() ?? 'The AI service could not process this request.');
    }
    final text = mapped['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw Exception('The AI service returned an empty response. Please try again.');
    }
    return text;
  }
}
