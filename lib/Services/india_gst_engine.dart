// India GST (Goods and Services Tax) engine.
//
// Provides GSTIN structural + check-digit validation (`IndiaGstEngine`) and
// CGST/SGST vs. IGST tax-breakdown calculation for domestic, SEZ, and
// export-of-services supplies (`GstCalculator`).

/// The seller's own GSTIN, or null while this business is not GST-registered.
///
/// Deliberately null (6 Oct 2026). Section 32(1) of the CGST Act says a person
/// who is not registered "shall not collect ... any amount by way of tax", and
/// a PAN is not a GSTIN - the GSTIN contains the PAN, but only exists after
/// registering on the GST portal. Until this holds a real 15-character GSTIN,
/// GstCalculator charges and displays no tax at all.
///
/// Setting this is the ONLY change needed to switch GST back on: the amount
/// charged never depends on it (see _chargeAmountForPlan in checkout_page.dart),
/// so turning it on reinterprets the same price as tax-inclusive rather than
/// raising it.
const String? sellerGstin = null;

/// The seller's own GST-registered home state. A domestic supply is taxed as
/// CGST+SGST (intra-state) when the customer's billing state matches this,
/// and as IGST (inter-state) otherwise. Only consulted once sellerGstin is set.
const String _sellerHomeState = 'Delhi';

/// Validates Indian GSTIN numbers: 15-character structure plus the official
/// mod-36 check-digit algorithm (not just a loose 15-char regex).
class IndiaGstEngine {
  IndiaGstEngine._();

  static const String _checksumAlphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  // 2-digit state code + 10-char PAN (5 letters, 4 digits, 1 letter) +
  // 1-char entity number + literal 'Z' + 1-char checksum.
  static final RegExp _gstinFormat = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

  /// Returns true only if [gstin] is 15 characters, matches the structural
  /// format, and its trailing checksum character matches the computed one.
  static bool isValidGstin(String gstin) {
    final value = gstin.trim().toUpperCase();
    if (value.length != 15 || !_gstinFormat.hasMatch(value)) {
      return false;
    }
    return _checkDigit(value.substring(0, 14)) == value[14];
  }

  static String _checkDigit(String first14Chars) {
    var sum = 0;
    for (var i = 0; i < first14Chars.length; i++) {
      final charValue = _checksumAlphabet.indexOf(first14Chars[i]);
      final factor = (i % 2 == 0) ? 1 : 2;
      final product = charValue * factor;
      sum += (product ~/ 36) + (product % 36);
    }
    final checksum = (36 - (sum % 36)) % 36;
    return _checksumAlphabet[checksum];
  }
}

/// How a supply is taxed under Indian GST.
///
/// [notRegistered] is not a GST treatment at all - it means the seller has no
/// GSTIN, so no tax is charged, no tax is shown and no tax invoice is issued.
enum GstTaxType { notRegistered, intraState, interState, export }

/// The computed tax breakdown of a GST-inclusive amount.
class GstBreakdown {
  const GstBreakdown({
    required this.taxType,
    required this.baseAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.totalTax,
    required this.totalAmount,
    required this.summaryLine,
    this.gstCharged = true,
  });

  final GstTaxType taxType;

  /// False when nothing in this breakdown is tax: either the seller is not
  /// registered, or the supply is a zero-rated export. UI that prints a
  /// "Base + GST = Total" split must check this first - printing that split
  /// when no tax exists tells a paying customer something untrue.
  final bool gstCharged;
  final double baseAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalTax;
  final double totalAmount;

  /// Human-readable line describing the tax treatment, ready to show in a
  /// billing summary.
  final String summaryLine;
}

/// Computes CGST/SGST/IGST breakdowns from a GST-inclusive amount.
class GstCalculator {
  GstCalculator._();

  static const double gstRate = 0.18;

  /// Whether this business may charge tax at all. Everything else in here is
  /// downstream of it - see the note on [sellerGstin].
  static bool get sellerIsRegistered => (sellerGstin ?? '').trim().isNotEmpty;

  /// [amountInclusive] is the final, tax-inclusive amount charged.
  /// [customerStateName] is the customer's billing state (used to decide
  /// intra-state vs. inter-state for domestic, non-SEZ supplies).
  static GstBreakdown compute({
    required double amountInclusive,
    String? customerStateName,
    required bool isExportSupply,
    required bool isSezUnit,
  }) {
    // Checked before everything else, including export. An unregistered seller
    // has no tax treatment to describe - not even a zero-rated one, because
    // "zero-rated export supply" is itself a statement made by a registered
    // person. The whole amount is simply the price.
    if (!sellerIsRegistered) {
      return GstBreakdown(
        taxType: GstTaxType.notRegistered,
        baseAmount: amountInclusive,
        cgst: 0,
        sgst: 0,
        igst: 0,
        totalTax: 0,
        totalAmount: amountInclusive,
        summaryLine: 'No GST is charged on this purchase - the seller is not GST-registered.',
        gstCharged: false,
      );
    }

    if (isExportSupply) {
      return GstBreakdown(
        taxType: GstTaxType.export,
        baseAmount: amountInclusive,
        cgst: 0,
        sgst: 0,
        igst: 0,
        totalTax: 0,
        totalAmount: amountInclusive,
        summaryLine: 'Tax: Export of Services (0% GST) - zero-rated supply, no GST charged.',
        gstCharged: false,
      );
    }

    final baseAmount = amountInclusive / (1 + gstRate);
    final totalTax = amountInclusive - baseAmount;

    if (isSezUnit) {
      return GstBreakdown(
        taxType: GstTaxType.interState,
        baseAmount: baseAmount,
        cgst: 0,
        sgst: 0,
        igst: totalTax,
        totalTax: totalTax,
        totalAmount: amountInclusive,
        summaryLine: 'Tax: 18% IGST (SEZ with Payment of IGST) - included in the amount above.',
      );
    }

    final normalizedCustomerState = customerStateName?.trim() ?? '';
    // Unknown customer state must NOT default to "same state as seller" -
    // that would wrongly charge CGST+SGST to an out-of-state customer.
    // Keep the safer flat-IGST treatment until the real state is known.
    final isKnownState = normalizedCustomerState.isNotEmpty;
    final isIntraState = isKnownState && normalizedCustomerState.toLowerCase() == _sellerHomeState.toLowerCase();

    if (isIntraState) {
      final half = totalTax / 2;
      return GstBreakdown(
        taxType: GstTaxType.intraState,
        baseAmount: baseAmount,
        cgst: half,
        sgst: half,
        igst: 0,
        totalTax: totalTax,
        totalAmount: amountInclusive,
        summaryLine: 'Tax: 18% GST (CGST 9% + SGST 9%) included in the amount above.',
      );
    }

    return GstBreakdown(
      taxType: GstTaxType.interState,
      baseAmount: baseAmount,
      cgst: 0,
      sgst: 0,
      igst: totalTax,
      totalTax: totalTax,
      totalAmount: amountInclusive,
      summaryLine: 'Tax: 18% IGST included in the amount above.',
    );
  }
}
