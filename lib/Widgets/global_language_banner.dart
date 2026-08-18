import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

enum _GreetingLocale { german, french, italian, spanish, global }

/// Lightweight, dependency-free "smart" multilingual greeting banner/badge.
///
/// Detects the visitor's browser language (primary signal) and, if that is
/// empty or unrecognized, falls back to the browser's IANA timezone
/// (secondary signal) to guess whether they are likely a German/French/
/// Italian/Spanish speaking visitor, then shows a short, friendly, localized
/// greeting pill. This is a pure client-side, synchronous best-effort guess
/// (never blocks rendering on a network call) - not a real i18n/locale
/// system, just a welcoming hint that voice/document tools work in their
/// language too.
class GlobalLanguageBanner extends StatelessWidget {
  const GlobalLanguageBanner({super.key});

  static const Map<_GreetingLocale, String> _messages = {
    _GreetingLocale.german:
        '🇩🇪 Willkommen! Sprechen oder laden Sie Dokumente auf Deutsch hoch – volle KI-Unterstützung.',
    _GreetingLocale.french:
        '🇫🇷 Bienvenue ! Parlez ou importez des documents en français – IA multilingue complète.',
    _GreetingLocale.italian:
        '🇮🇹 Benvenuto! Parla o carica documenti in italiano – supporto vocale e OCR integrato.',
    _GreetingLocale.spanish:
        '🇪🇸 ¡Bienvenido! Habla o sube documentos en español – soporte completo de IA multilingüe.',
    _GreetingLocale.global:
        '🌍 Global Ready: Speak or upload in German, French, Italian, Spanish, or English — 50+ languages natively supported.',
  };

  String _browserLanguage() {
    try {
      final primary = html.window.navigator.language.trim();
      if (primary.isNotEmpty) {
        return primary;
      }
    } catch (_) {
      // ignore - fall through to the languages list below.
    }
    try {
      final list = html.window.navigator.languages;
      if (list != null && list.isNotEmpty) {
        return list.first.trim();
      }
    } catch (_) {
      // ignore
    }
    return '';
  }

  /// Best-effort IANA timezone (e.g. "Europe/Berlin") via a tiny JS eval -
  /// no typed dart:js_interop binding exists/is needed for this one-shot
  /// synchronous read, mirroring this codebase's existing `js.context`
  /// usage (e.g. the PWA install-prompt check in home_page_v1_1.dart).
  String _browserTimeZone() {
    try {
      final result = js.context.callMethod('eval', [
        "(function(){try{return Intl.DateTimeFormat().resolvedOptions().timeZone || '';}catch(e){return '';}})()",
      ]);
      return (result ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  _GreetingLocale _localeFromLanguage(String rawLanguage) {
    final language = rawLanguage.trim().toLowerCase();
    if (language == 'de' || language.startsWith('de-')) return _GreetingLocale.german;
    if (language == 'fr' || language.startsWith('fr-')) return _GreetingLocale.french;
    if (language == 'it' || language.startsWith('it-')) return _GreetingLocale.italian;
    if (language == 'es' || language.startsWith('es-')) return _GreetingLocale.spanish;
    return _GreetingLocale.global;
  }

  _GreetingLocale _localeFromTimeZone(String rawTimeZone) {
    final timeZone = rawTimeZone.trim();
    if (timeZone.isEmpty) return _GreetingLocale.global;

    const germanZones = {'Europe/Berlin', 'Europe/Vienna', 'Europe/Zurich'};
    const frenchZones = {'Europe/Paris', 'Europe/Brussels'};
    const italianZones = {'Europe/Rome'};
    const spanishZones = {'Europe/Madrid'};
    // Broad Spanish-speaking Latin America coverage (per the "ES / LATAM" spec).
    const spanishLatamPrefixes = [
      'America/Mexico_City',
      'America/Bogota',
      'America/Argentina',
      'America/Lima',
      'America/Santiago',
      'America/Caracas',
      'America/Guatemala',
      'America/Havana',
      'America/Montevideo',
      'America/Asuncion',
      'America/La_Paz',
      'America/Managua',
      'America/Panama',
      'America/El_Salvador',
      'America/Tegucigalpa',
      'America/Costa_Rica',
      'America/Santo_Domingo',
    ];

    if (germanZones.contains(timeZone)) return _GreetingLocale.german;
    if (frenchZones.contains(timeZone)) return _GreetingLocale.french;
    if (italianZones.contains(timeZone)) return _GreetingLocale.italian;
    if (spanishZones.contains(timeZone)) return _GreetingLocale.spanish;
    for (final prefix in spanishLatamPrefixes) {
      if (timeZone.startsWith(prefix)) return _GreetingLocale.spanish;
    }
    return _GreetingLocale.global;
  }

  _GreetingLocale _resolveLocale() {
    final fromLanguage = _localeFromLanguage(_browserLanguage());
    if (fromLanguage != _GreetingLocale.global) {
      return fromLanguage;
    }
    return _localeFromTimeZone(_browserTimeZone());
  }

  @override
  Widget build(BuildContext context) {
    final locale = _resolveLocale();
    final message = _messages[locale] ?? _messages[_GreetingLocale.global]!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E3A5F),
          height: 1.4,
        ),
      ),
    );
  }
}
