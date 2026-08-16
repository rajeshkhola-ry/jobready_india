import 'dart:convert';

import '../Utils/web_safe_browser.dart';

class VoiceTopupPack {
  final String id;
  final String name;
  final int credits;
  final double priceInr;
  final double priceUsd;
  final bool isPopular;

  const VoiceTopupPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceInr,
    required this.priceUsd,
    this.isPopular = false,
  });

  VoiceTopupPack copyWith({
    String? name,
    int? credits,
    double? priceInr,
    double? priceUsd,
    bool? isPopular,
  }) {
    return VoiceTopupPack(
      id: id,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      priceInr: priceInr ?? this.priceInr,
      priceUsd: priceUsd ?? this.priceUsd,
      isPopular: isPopular ?? this.isPopular,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'credits': credits,
      'price_inr': priceInr,
      'price_usd': priceUsd,
      'is_popular': isPopular,
    };
  }

  factory VoiceTopupPack.fromMap(Map<String, dynamic> map, VoiceTopupPack fallback) {
    return VoiceTopupPack(
      id: map['id']?.toString() ?? fallback.id,
      name: map['name']?.toString() ?? fallback.name,
      credits: int.tryParse(map['credits']?.toString() ?? '') ?? fallback.credits,
      priceInr: double.tryParse(map['price_inr']?.toString() ?? '') ?? fallback.priceInr,
      priceUsd: double.tryParse(map['price_usd']?.toString() ?? '') ?? fallback.priceUsd,
      isPopular: map['is_popular'] == true || fallback.isPopular,
    );
  }
}

/// Admin-configurable Razorpay voice-command top-up packs. Persisted in
/// localStorage (mirrors PlanCatalogService's pattern) so admin edits publish
/// immediately to the pricing page grid.
class VoiceTopupService {
  static const String _storageKey = 'jobready_voice_topup_packs_v1';

  static List<VoiceTopupPack> defaults() {
    return const [
      VoiceTopupPack(id: 'starter', name: 'Starter', credits: 100, priceInr: 29, priceUsd: 0.99),
      VoiceTopupPack(id: 'popular', name: 'Popular', credits: 250, priceInr: 59, priceUsd: 1.99, isPopular: true),
      VoiceTopupPack(id: 'pro', name: 'Pro', credits: 600, priceInr: 119, priceUsd: 3.99),
    ];
  }

  static List<VoiceTopupPack> load() {
    final raw = WebSafeBrowser.readLocalStorage(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return defaults();
      }
      final fallbacks = defaults();
      final packs = <VoiceTopupPack>[];
      for (var i = 0; i < decoded.length && i < fallbacks.length; i++) {
        packs.add(VoiceTopupPack.fromMap(Map<String, dynamic>.from(decoded[i] as Map), fallbacks[i]));
      }
      return packs.isEmpty ? defaults() : packs;
    } catch (_) {
      return defaults();
    }
  }

  static Future<void> save(List<VoiceTopupPack> packs) async {
    WebSafeBrowser.writeLocalStorage(
      _storageKey,
      jsonEncode(packs.map((pack) => pack.toMap()).toList()),
    );
  }
}
