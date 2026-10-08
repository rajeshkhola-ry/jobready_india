/// Shared source of truth for govt exam/portal photo & signature specs.
///
/// Used by both govt_verifier_page.dart (the resizer tool) and
/// doc_packager_page.dart (the bundle packager), so the two never drift
/// apart on the same board's numbers.
class GovtPhotoPreset {
  final String id;
  final String label;
  final int width;
  final int height;
  final int minKb;
  final int maxKb;
  final String notes;

  /// True for the one open-ended entry, where [width] and [height] are only
  /// starting values and the person types their own. Every other preset is a
  /// board's published specification and is not editable.
  final bool isCustom;

  const GovtPhotoPreset({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.minKb,
    required this.maxKb,
    required this.notes,
    this.isCustom = false,
  });
}

const List<GovtPhotoPreset> kGovtPhotoPresets = [
  GovtPhotoPreset(
    id: 'ssc_photo',
    label: 'SSC Photo',
    width: 200, height: 230,
    minKb: 20, maxKb: 50,
    notes: 'SSC CGL/CHSL/MTS: 3.5×4.5 cm, 20–50 KB, JPG/JPEG. White or light background. '
        'Note: SSC CGL/CHSL applications now require your photo to be captured LIVE via webcam or mobile camera during the application itself — a pre-existing photo can no longer be uploaded. Use this tool to prepare your Signature and other bundle documents.',
  ),
  GovtPhotoPreset(
    id: 'ssc_signature',
    label: 'SSC Signature',
    width: 140, height: 60,
    minKb: 10, maxKb: 20,
    notes: 'SSC CGL/CHSL/MTS: 3.5×1.5 cm, 10–20 KB, JPG/JPEG. Black ink on white background.',
  ),
  GovtPhotoPreset(
    id: 'upsc_photo',
    label: 'UPSC Photo',
    width: 350, height: 350,
    minKb: 20, maxKb: 240,
    notes: 'UPSC: square, 350×350 to 1000×1000 px, 20–240 KB, JPG, white background, full face visible.',
  ),
  GovtPhotoPreset(
    id: 'upsc_signature',
    label: 'UPSC Signature',
    width: 425, height: 425,
    minKb: 20, maxKb: 100,
    notes: 'UPSC: all three required handwritten signatures combined in ONE image, approx. 350–500 px, 20–100 KB, JPG.',
  ),
  GovtPhotoPreset(
    id: 'ibps_photo',
    label: 'IBPS / Bank Photo',
    width: 200, height: 230,
    minKb: 20, maxKb: 50,
    notes: 'IBPS PO/Clerk/SO: approx 200×230 px, 20–50 KB, JPG. Plain white background.',
  ),
  GovtPhotoPreset(
    id: 'ibps_signature',
    label: 'IBPS Signature',
    width: 140, height: 60,
    minKb: 10, maxKb: 20,
    notes: 'IBPS PO/Clerk/SO: approx 140×60 px, 10–20 KB, JPG. Blue/black ink on white.',
  ),
  GovtPhotoPreset(
    id: 'rrb_photo',
    label: 'RRB / Railway Photo',
    width: 320, height: 240,
    minKb: 50, maxKb: 100,
    notes: 'RRB NTPC/Group-D/ALP: 320×240 px, 50–100 KB, JPG. Light background.',
  ),
  GovtPhotoPreset(
    id: 'rrb_signature',
    label: 'RRB / Railway Signature',
    width: 140, height: 60,
    minKb: 30, maxKb: 49,
    notes: 'RRB NTPC/Group-D/ALP: 140×60 px, 30–49 KB, min 100 DPI, JPG.',
  ),
  GovtPhotoPreset(
    id: 'jee_photo',
    label: 'JEE / NEET Photo',
    width: 144, height: 192,
    minKb: 10, maxKb: 100,
    notes: 'JEE Main/NEET-UG: approx 3.5×4.5 cm, 10–100 KB, JPG. Plain white background.',
  ),
  GovtPhotoPreset(
    id: 'aadhaar_photo_update',
    label: 'Aadhaar Photo Update',
    width: 200, height: 200,
    minKb: 10, maxKb: 100,
    notes: 'UIDAI: square crop preferred, max 100 KB, JPG/JPEG. Face clearly visible.',
  ),

  // Open-ended entry, added 8 Oct 2026. Every preset above is a published
  // specification we can point at; this one carries no numbers of its own and
  // asks the person for theirs instead.
  //
  // It exists because the list above can only cover boards we are able to
  // verify. Pakistani portals (FPSC, PPSC, NTS, KPPSC, SPSC, PTS) are the
  // clearest case: their sites are not reachable from India, so their figures
  // cannot be checked today or kept right when they change. Printing a KB limit
  // we cannot verify would be worse than printing none — someone would trust
  // it, build their photo to it, and have the application rejected.
  //
  // Letting them enter what their own form says is the honest answer, and it
  // also covers every state board, university and employer form that will never
  // be worth a preset of its own.
  GovtPhotoPreset(
    id: 'custom',
    label: 'Other portal — enter your own size',
    width: 200, height: 230,
    minKb: 5, maxKb: 500,
    isCustom: true,
    notes: 'For any form not listed above — a government job in any country, a '
        'state or provincial board, a university, or an employer. Type the '
        'pixel size and KB limit your own form asks for and the tool will hit '
        'them. We only print figures for boards we can check ourselves, '
        'because a wrong number here is what gets an application rejected.',
  ),
];

/// Looks up a preset by its exact [id] (e.g. 'ssc_photo').
GovtPhotoPreset govtPhotoPresetById(String id) =>
    kGovtPhotoPresets.firstWhere((p) => p.id == id);
