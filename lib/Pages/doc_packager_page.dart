import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../Services/analytics_service.dart';
import '../Services/file_picker_service.dart';
import '../Services/govt_photo_presets.dart';
import '../Services/seo_helper.dart';
import '../Services/wasm_document_service.dart';
import '../Widgets/faq_accordion.dart';

// ── Board selector ───────────────────────────────────────────────────────────
// Photo/signature specs come from ../Services/govt_photo_presets.dart (the
// same source of truth govt_verifier_page.dart uses) so the two tools can't
// drift apart on the same board's numbers.

enum _Board { ssc, upsc, ibps, rrb }

extension on _Board {
  String get label => switch (this) {
        _Board.ssc => 'SSC',
        _Board.upsc => 'UPSC',
        _Board.ibps => 'IBPS',
        _Board.rrb => 'RRB',
      };

  String get presetPrefix => switch (this) {
        _Board.ssc => 'ssc',
        _Board.upsc => 'upsc',
        _Board.ibps => 'ibps',
        _Board.rrb => 'rrb',
      };
}

// ── Slot definitions ───────────────────────────────────────────────────────────

class _SlotDef {
  final String id;
  final String title;
  final String role;       // human label shown on card
  final String guidance;   // what to upload
  final IconData icon;
  final Color accent;
  final List<String> ext;
  final int? targetW;      // null = no resize
  final int? targetH;
  final int maxKb;
  final int minKb;
  final String archiveName;
  final bool required;

  const _SlotDef({
    required this.id, required this.title, required this.role,
    required this.guidance, required this.icon, required this.accent,
    required this.ext, this.targetW, this.targetH,
    required this.maxKb, required this.minKb,
    required this.archiveName, this.required = true,
  });
}

/// Builds the 4 slot definitions for [board]. Photo/signature dimensions and
/// KB limits come from govt_photo_presets.dart's shared preset table -
/// identity/document slots don't vary by board.
List<_SlotDef> _buildSlotDefs(_Board board) {
  final photoPreset = govtPhotoPresetById('${board.presetPrefix}_photo');
  final signaturePreset = govtPhotoPresetById('${board.presetPrefix}_signature');
  final isSsc = board == _Board.ssc;

  return [
    _SlotDef(
      id: 'photo', title: '01. Photo', role: 'Passport / ID Photo',
      guidance: isSsc
          ? '${board.label} now requires the photo to be captured LIVE via webcam/mobile camera during the application itself - a pre-existing photo can no longer be uploaded here. Skip this slot for SSC and pack Signature + Identity + Document instead.'
          : 'Coloured passport-size photo. ${photoPreset.notes}',
      icon: Icons.person_pin_rounded, accent: const Color(0xFF0F2D4A),
      ext: const ['jpg', 'jpeg', 'png', 'webp'],
      targetW: photoPreset.width, targetH: photoPreset.height,
      maxKb: photoPreset.maxKb, minKb: photoPreset.minKb,
      archiveName: '01_PHOTO.jpg', required: !isSsc,
    ),
    _SlotDef(
      id: 'signature', title: '02. Signature', role: board == _Board.upsc
          ? 'All 3 Required Signatures (combined)'
          : 'Scanned Signature',
      guidance: signaturePreset.notes,
      icon: Icons.draw_rounded, accent: const Color(0xFF065F46),
      ext: const ['jpg', 'jpeg', 'png', 'webp'],
      targetW: signaturePreset.width, targetH: signaturePreset.height,
      maxKb: signaturePreset.maxKb, minKb: signaturePreset.minKb,
      archiveName: '02_SIGNATURE.jpg', required: true,
    ),
    const _SlotDef(
      id: 'identity', title: '03. Identity Proof', role: 'Aadhaar / PAN / Passport',
      guidance: 'Front of your identity document. Ensure all text and numbers are clearly visible.',
      icon: Icons.credit_card_rounded, accent: Color(0xFF7C2D12),
      ext: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      targetW: null, targetH: null, maxKb: 200, minKb: 10,
      archiveName: '03_IDENTITY_PROOF', required: true,
    ),
    const _SlotDef(
      id: 'document', title: '04. Supporting Doc', role: 'Marksheet / Resume / Certificate',
      guidance: 'Latest marksheet, degree certificate, or tailored resume. PDF preferred.',
      icon: Icons.description_rounded, accent: Color(0xFF4338CA),
      ext: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      targetW: null, targetH: null, maxKb: 800, minKb: 10,
      archiveName: '04_DOCUMENT', required: false,
    ),
  ];
}

// ── Compute isolate for image processing ───────────────────────────────────────

class _ImgArgs {
  final Uint8List bytes;
  final int? targetW;
  final int? targetH;
  final int maxKb;
  const _ImgArgs({required this.bytes, this.targetW, this.targetH, required this.maxKb});
}

Uint8List _optimiseImage(_ImgArgs args) {
  final src = img.decodeImage(args.bytes);
  if (src == null) throw Exception('Cannot decode image.');

  // Resize if target dimensions given
  final sized = (args.targetW != null && args.targetH != null)
      ? img.copyResize(src,
            width: args.targetW!, height: args.targetH!,
            interpolation: img.Interpolation.cubic)
      : src;

  // Binary-search for highest quality within maxKb
  int lo = 15, hi = 90;
  Uint8List? best;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    final encoded = Uint8List.fromList(img.encodeJpg(sized, quality: mid));
    if (encoded.length <= args.maxKb * 1024) {
      best = encoded;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best ?? Uint8List.fromList(img.encodeJpg(sized, quality: 15));
}

// ── Slot state ─────────────────────────────────────────────────────────────────

enum _SlotStatus { empty, processing, ready, error }

class _SlotState {
  final PickedFileData? rawFile;
  final Uint8List? processedBytes;
  final _SlotStatus status;
  final String message;

  const _SlotState({
    this.rawFile,
    this.processedBytes,
    this.status = _SlotStatus.empty,
    this.message = '',
  });

  int get outputKb => ((processedBytes?.length ?? 0) / 1024).round();
  bool get isImage => rawFile != null &&
      !rawFile!.name.toLowerCase().endsWith('.pdf');
}

// ── Page ───────────────────────────────────────────────────────────────────────

class DocPackagerPage extends StatefulWidget {
  const DocPackagerPage({super.key});

  @override
  State<DocPackagerPage> createState() => _DocPackagerPageState();
}

class _DocPackagerPageState extends State<DocPackagerPage> {
  _Board _selectedBoard = _Board.ssc;
  List<_SlotDef> get _slotDefs => _buildSlotDefs(_selectedBoard);

  final List<_SlotState> _slots =
      List.generate(4, (_) => const _SlotState());

  bool _isPacking = false;
  String _status = 'Select your board, then upload documents into each slot. Files are optimised automatically.';

  void _onBoardChanged(_Board board) {
    if (board == _selectedBoard) return;
    setState(() {
      _selectedBoard = board;
      // Photo/signature were resized for the PREVIOUS board's dimensions -
      // clear them so a stale wrong-size file can't end up in the ZIP.
      _slots[0] = const _SlotState();
      _slots[1] = const _SlotState();
      _status = _buildOverallStatus();
    });
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackToolOpen('doc_packager');
    SeoHelper.apply(
      title: 'Job Application Document Bundle — One-Click ZIP Packager | GetReadyJob',
      description: 'Pick your board (SSC/UPSC/IBPS/RRB) and auto-bundle a correctly-sized photo, signature, identity proof, and marksheet into one ZIP. 100% local, no server.',
      path: '/doc-packager',
      keywords: 'job application document bundle ZIP, SSC document bundle, UPSC application photo signature, RRB railway document bundle, IBPS bank document bundle, job application packager India, one-click document ZIP',
    );
  }

  // ── File pick + auto-process ─────────────────────────────────────────────

  Future<void> _pickForSlot(int idx) async {
    final def = _slotDefs[idx];
    final picked = await FilePickerService.pickFileData(
      allowedExtensions: def.ext,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _slots[idx] = _SlotState(
        rawFile: picked,
        status: _SlotStatus.processing,
        message: 'Optimising…',
      );
      _status = 'Processing "${def.title}"…';
    });

    await _processSlot(idx, picked);
  }

  Future<void> _processSlot(int idx, PickedFileData picked) async {
    final def = _slotDefs[idx];
    final isPdf = picked.name.toLowerCase().endsWith('.pdf');

    try {
      Uint8List output;
      String msg;

      if (isPdf) {
        // PDFs: validate size only
        if (picked.bytes.length > def.maxKb * 1024) {
          setState(() {
            _slots[idx] = _SlotState(
              rawFile: picked,
              status: _SlotStatus.error,
              message: 'PDF is ${(picked.bytes.length / 1024).round()} KB — max ${def.maxKb} KB. '
                  'Compress externally or use a smaller PDF.',
            );
          });
          return;
        }
        output = picked.bytes;
        msg = 'PDF accepted — ${(output.length / 1024).round()} KB.';
      } else {
        // Images: resize + compress via isolate
        output = await compute(
          _optimiseImage,
          _ImgArgs(
            bytes: picked.bytes,
            targetW: def.targetW,
            targetH: def.targetH,
            maxKb: def.maxKb,
          ),
        );
        final kb = (output.length / 1024).round();
        final dim = (def.targetW != null) ? '${def.targetW}×${def.targetH}px  •  ' : '';
        msg = '${dim}${kb} KB  ✓';
      }

      if (!mounted) return;
      setState(() {
        _slots[idx] = _SlotState(
          rawFile: picked,
          processedBytes: output,
          status: _SlotStatus.ready,
          message: msg,
        );
        _status = _buildOverallStatus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slots[idx] = _SlotState(
          rawFile: picked,
          status: _SlotStatus.error,
          message: 'Failed: ${e.toString().split('\n').first}',
        );
      });
    }
  }

  // ── ZIP creation ─────────────────────────────────────────────────────────

  Future<void> _packAndDownload() async {
    setState(() { _isPacking = true; _status = 'Building ZIP bundle…'; });

    try {
      final archive = Archive();
      int fileCount = 0;

      for (int i = 0; i < _slotDefs.length; i++) {
        final def = _slotDefs[i];
        final state = _slots[i];
        if (state.processedBytes == null) continue;

        // Determine final archive filename (include original ext for PDFs)
        String archiveName = def.archiveName;
        final isPdf = state.rawFile!.name.toLowerCase().endsWith('.pdf');
        if (def.targetW == null) {
          // no resize slot — keep correct extension
          archiveName += isPdf ? '.pdf' : '.jpg';
        }

        final bytes = state.processedBytes!;
        archive.addFile(ArchiveFile(archiveName, bytes.length, bytes));
        fileCount++;
      }

      // README.txt
      final readme = _buildReadme(fileCount);
      final readmeBytes = utf8.encode(readme);
      archive.addFile(ArchiveFile(
        'APPLICATION_BUNDLE_README.txt', readmeBytes.length, readmeBytes));

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null || zipBytes.isEmpty) throw Exception('ZIP encoding failed.');

      final now = DateTime.now();
      final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      WasmDocumentService.triggerBrowserDownload(
        bytes: Uint8List.fromList(zipBytes),
        fileName: 'JobApplication_Bundle_GRJ_$ts.zip',
        mimeType: 'application/zip',
      );
      AnalyticsService.trackToolAction('doc_packager', 'zip_pack');

      if (mounted) {
        setState(() => _status =
            'Bundle downloaded — $fileCount file(s) + README in ZIP. ✓');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Pack failed: $e');
    } finally {
      if (mounted) setState(() => _isPacking = false);
    }
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  String _buildOverallStatus() {
    final ready = _slots.where((s) => s.status == _SlotStatus.ready).length;
    final processing = _slots.any((s) => s.status == _SlotStatus.processing);
    if (processing) return 'Optimising files…';
    if (ready == 0) return 'Upload documents into each slot.';
    final needMsg = _selectedBoard == _Board.ssc
        ? 'Upload at least the Signature to pack.'
        : 'Upload at least the Photo to pack.';
    return '$ready of ${_slotDefs.length} slot(s) ready. ${_canPack ? 'Tap "Pack & Download".' : needMsg}';
  }

  bool get _canPack =>
      _slots[0].status == _SlotStatus.ready || // photo ready
      _slots.any((s) => s.status == _SlotStatus.ready);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1F3D),
        foregroundColor: Colors.white,
        title: const Text('Job Application Bundle Packager'),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: (_canPack && !_isPacking) ? _packAndDownload : null,
              icon: _isPacking
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1F3D)))
                  : const Icon(Icons.download_for_offline_rounded, size: 16),
              label: Text(_isPacking ? 'Building…' : 'Pack & Download ZIP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCD34D),
                foregroundColor: const Color(0xFF0A1F3D),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F8FF), Color(0xFFE8F0FE)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero header
                  _heroCard(),
                  const SizedBox(height: 14),

                  // Board selector
                  _boardSelector(),
                  const SizedBox(height: 18),

                  // Slot grid
                  LayoutBuilder(builder: (ctx, bc) {
                    final twoCol = bc.maxWidth >= 660;
                    if (twoCol) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Column(children: [
                            _slotCard(0), const SizedBox(height: 12), _slotCard(2),
                          ])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(children: [
                            _slotCard(1), const SizedBox(height: 12), _slotCard(3),
                          ])),
                        ],
                      );
                    }
                    return Column(children: List.generate(
                        _slotDefs.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _slotCard(i),
                        )));
                  }),

                  const SizedBox(height: 16),

                  // Status row
                  _statusRow(_status),
                  const SizedBox(height: 12),

                  // Bottom pack button (also for narrow screens)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_canPack && !_isPacking) ? _packAndDownload : null,
                      icon: _isPacking
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.folder_zip_rounded),
                      label: Text(_isPacking
                          ? 'Building bundle…'
                          : 'Pack & Download Job Application Bundle (ZIP)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A1F3D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const FaqAccordion(
                    accentColor: Color(0xFF0A1F3D),
                    items: [
                      FaqItem(
                        question: 'What goes inside the job application ZIP bundle?',
                        answer: 'The bundle includes your auto-resized photo, signature, identity proof, and supporting document, named 01_PHOTO.jpg, 02_SIGNATURE.jpg, 03_IDENTITY_PROOF, and 04_DOCUMENT - ready to upload to any SSC/UPSC/IBPS portal.',
                      ),
                      FaqItem(
                        question: 'Are my documents uploaded to a server when packaging?',
                        answer: 'No. Every file is optimised and zipped entirely inside your browser. Nothing is transmitted to GetReadyJob servers or any third party.',
                      ),
                      FaqItem(
                        question: 'Is the Doc Packager tool free to use?',
                        answer: 'Yes, packaging and downloading your job application bundle is completely free, with no sign-up required.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _privacyFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Board selector ────────────────────────────────────────────────────────

  Widget _boardSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exam Board',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A1F3D))),
          const SizedBox(height: 4),
          const Text(
            'Photo & signature dimensions and KB limits are set automatically for the board you pick.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _Board.values.map((board) {
              final active = board == _selectedBoard;
              return ChoiceChip(
                label: Text(board.label),
                selected: active,
                onSelected: (_) => _onBoardChanged(board),
                selectedColor: const Color(0xFF0A1F3D),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : const Color(0xFF0A1F3D),
                ),
                backgroundColor: const Color(0xFFF0F5FC),
                side: BorderSide(color: active ? const Color(0xFF0A1F3D) : const Color(0xFFD8E5F5)),
              );
            }).toList(),
          ),
          if (_selectedBoard == _Board.ssc) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_rounded, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "SSC CGL/CHSL now requires the photo to be captured LIVE during the application itself — it can't be pre-uploaded. Use this tool for your Signature, Identity Proof, and Supporting Document instead.",
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1F3D),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCD34D).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.folder_zip_rounded, color: Color(0xFFFCD34D), size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zero-Server Job Application Packager',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              SizedBox(height: 4),
              Text(
                'Upload your Photo, Signature, Identity Proof, and Supporting Document. '
                'Each file is auto-optimised to portal-compliant dimensions and KB limits locally. '
                'Download everything as a single, clean ZIP bundle — zero server, zero upload.',
                style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD), height: 1.5),
              ),
              SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _HeroBadge('🔒 100% Local'),
                _HeroBadge('⚡ Instant Optimise'),
                _HeroBadge('📦 Structured ZIP'),
                _HeroBadge('✅ SSC / UPSC / IBPS / RRB'),
              ]),
            ],
          )),
        ]),
      );

  // ── Slot card ─────────────────────────────────────────────────────────────

  Widget _slotCard(int idx) {
    final def = _slotDefs[idx];
    final state = _slots[idx];
    final accent = def.accent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE7F4)),
        boxShadow: const [BoxShadow(color: Color(0x0A0A1F3D), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.20))),
            ),
            child: Row(children: [
              Icon(def.icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent)),
                  Text(def.role, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              )),
              _specBadge(def),
            ]),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Guidance text
                Text(def.guidance,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.5)),
                const SizedBox(height: 10),

                // File zone
                _fileZone(idx, def, state),

                const SizedBox(height: 10),

                // Upload button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: state.status == _SlotStatus.processing ? null : () => _pickForSlot(idx),
                    icon: Icon(state.rawFile == null ? Icons.upload_rounded : Icons.refresh_rounded, size: 15),
                    label: Text(
                      state.rawFile == null ? 'Upload ${def.role}' : 'Replace File',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.50)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specBadge(_SlotDef def) {
    final dimText = def.targetW != null ? '${def.targetW}×${def.targetH}px  •  ' : '';
    final kbText = '${def.minKb}–${def.maxKb} KB';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: def.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (def.targetW != null)
            Text('${def.targetW}×${def.targetH}px',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: def.accent)),
          Text(kbText,
              style: TextStyle(fontSize: 10, color: def.accent.withValues(alpha: 0.80))),
          Text(def.required ? 'Required' : 'Optional',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: def.required ? const Color(0xFF991B1B) : const Color(0xFF3B82F6))),
        ],
      ),
    );
  }

  Widget _fileZone(int idx, _SlotDef def, _SlotState state) {
    switch (state.status) {
      case _SlotStatus.empty:
        return _emptyZone(def);
      case _SlotStatus.processing:
        return _processingZone();
      case _SlotStatus.ready:
        return _readyZone(state, def);
      case _SlotStatus.error:
        return _errorZone(state.message);
    }
  }

  Widget _emptyZone(_SlotDef def) => Container(
        height: 72,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFB8D0ED), style: BorderStyle.solid),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_upload_rounded, size: 22, color: def.accent.withValues(alpha: 0.40)),
          const SizedBox(height: 4),
          Text('Accepted: ${def.ext.map((e) => e.toUpperCase()).join(' / ')}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
      );

  Widget _processingZone() => Container(
        height: 72,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7DD3FC)),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0EA5E9))),
          SizedBox(height: 6),
          Text('Optimising…', style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _readyZone(_SlotState state, _SlotDef def) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.rawFile!.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF14532D)),
                overflow: TextOverflow.ellipsis),
            Text(state.message,
                style: const TextStyle(fontSize: 11, color: Color(0xFF166534))),
          ])),
        ]),
      );

  Widget _errorZone(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDA4AF)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFBE123C), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9F1239)))),
        ]),
      );

  // ── Status & footer ───────────────────────────────────────────────────────

  Widget _statusRow(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8D0ED)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF475569)),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4))),
        ]),
      );

  Widget _privacyFooter() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF64748B)),
          SizedBox(width: 8),
          Expanded(child: Text(
            '🔒 Privacy guarantee: All documents are processed entirely in your browser. '
            'No file, byte, or metadata is ever sent to any server. '
            'The ZIP is created locally and downloaded directly to your device.',
            style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.5),
          )),
        ]),
      );

  // ── README content ────────────────────────────────────────────────────────

  String _buildReadme(int fileCount) {
    final now = DateTime.now();
    final ts = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}  '
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    final photo = _slotDefs[0];
    final signature = _slotDefs[1];
    final board = _selectedBoard.label;
    final isSsc = _selectedBoard == _Board.ssc;
    final photoLine = isSsc
        ? 'Passport/ID photo — NOT included: $board requires a LIVE-captured photo during the application itself, it cannot be pre-uploaded.'
        : 'Passport/ID photo (${photo.targetW}×${photo.targetH}px, ${photo.minKb}–${photo.maxKb} KB)';
    return '''
==========================================================
  JOB APPLICATION BUNDLE — GETREADYJOB.COM
  Board: $board
  Packed: $ts
  Files in this bundle: $fileCount
==========================================================

CONTENTS:
  01_PHOTO.jpg            — $photoLine
  02_SIGNATURE.jpg        — Scanned signature (${signature.targetW}×${signature.targetH}px, ${signature.minKb}–${signature.maxKb} KB)
  03_IDENTITY_PROOF.*     — Identity document (Aadhaar / PAN / Passport)
  04_DOCUMENT.*           — Marksheet / Resume / Certificate

HOW TO USE:
  • Attach individual files as required by the $board portal / HR form.
  • Image files are optimised specifically for $board's published spec.
  • PDF files are included as-is.

PORTAL COMPLIANCE ($board):
  Photo     : ${photo.targetW}×${photo.targetH}px, JPG, ${photo.minKb}–${photo.maxKb} KB${isSsc ? ' — live capture required, see note above' : ''}
  Signature : ${signature.targetW}×${signature.targetH}px, JPG, ${signature.minKb}–${signature.maxKb} KB
  Identity  : JPG/PDF, clearly legible, ≤200 KB
  Document  : JPG/PDF, ≤800 KB

PRIVACY NOTE:
  This bundle was assembled entirely in your browser using
  GetReadyJob.com — no files were uploaded to any server.
  All processing was performed locally on your device.

----------------------------------------------------------
  getreadyjob.com  |  support@drutasystem.com
==========================================================
''';
  }
}

// ── Small badge widget (stateless) ────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final String label;
  const _HeroBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFCD34D).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.40)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFCD34D))),
      );
}
