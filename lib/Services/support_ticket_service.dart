import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class SupportTicketEntry {
  final String ticketNumber;
  final String type;
  final String message;
  final String source;
  final String createdAtIso;

  const SupportTicketEntry({
    required this.ticketNumber,
    required this.type,
    required this.message,
    required this.source,
    required this.createdAtIso,
  });

  Map<String, dynamic> toMap() {
    return {
      'ticket_number': ticketNumber,
      'type': type,
      'message': message,
      'source': source,
      'created_at_iso': createdAtIso,
    };
  }

  factory SupportTicketEntry.fromMap(Map<String, dynamic> map) {
    return SupportTicketEntry(
      ticketNumber: map['ticket_number']?.toString() ?? '',
      type: map['type']?.toString() ?? 'Suggestion',
      message: map['message']?.toString() ?? '',
      source: map['source']?.toString() ?? 'unknown',
      createdAtIso: map['created_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

class SupportTicketService {
  static const String _ticketsStorageKey = 'jobready_support_tickets_v1';
  static const String _counterStorageKey = 'jobready_support_ticket_counter_v1';
  static const int _maxEntries = 200;
  static final Map<String, String> _memoryStore = <String, String>{};

  static String? _getStorage(String key) {
    if (!kIsWeb) {
      return _memoryStore[key];
    }

    try {
      return html.window.localStorage[key];
    } catch (_) {
      return _memoryStore[key];
    }
  }

  static void _setStorage(String key, String value) {
    _memoryStore[key] = value;
    if (!kIsWeb) {
      return;
    }

    try {
      html.window.localStorage[key] = value;
    } catch (_) {
      // Keep memory fallback.
    }
  }

  static List<SupportTicketEntry> getEntries() {
    final raw = _getStorage(_ticketsStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <SupportTicketEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <SupportTicketEntry>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => SupportTicketEntry.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const <SupportTicketEntry>[];
    }
  }

  static Future<SupportTicketEntry> createTicket({
    required String type,
    required String message,
    required String source,
  }) async {
    final now = DateTime.now().toLocal();
    final dayKey = _dayKey(now);
    final nextSequence = _nextSequence(dayKey);
    final ticket = SupportTicketEntry(
      ticketNumber: 'JR-$dayKey-${nextSequence.toString().padLeft(4, '0')}',
      type: type,
      message: message,
      source: source,
      createdAtIso: now.toIso8601String(),
    );

    final entries = getEntries().toList(growable: true);
    entries.insert(0, ticket);
    final trimmed = entries.take(_maxEntries).map((entry) => entry.toMap()).toList(growable: false);
    _setStorage(_ticketsStorageKey, jsonEncode(trimmed));

    return ticket;
  }

  static String _dayKey(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  static int _nextSequence(String dayKey) {
    final raw = _getStorage(_counterStorageKey);
    Map<String, dynamic> counters = <String, dynamic>{};

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          counters = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        counters = <String, dynamic>{};
      }
    }

    final current = int.tryParse(counters[dayKey]?.toString() ?? '0') ?? 0;
    final next = current + 1;
    counters[dayKey] = next;
    _setStorage(_counterStorageKey, jsonEncode(counters));
    return next;
  }
}
