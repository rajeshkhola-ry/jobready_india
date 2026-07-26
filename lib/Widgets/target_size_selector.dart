import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Services/compression_service.dart';

/// Target Size Selector for Compression
/// User specifies desired file size (e.g., 90MB, 500KB)
class TargetSizeSelector extends StatefulWidget {
  final Function(int, String) onTargetSet; // targetSize in bytes, unit (KB/MB)
  final ValueChanged<PdfCompressionMode>? onModeChanged;
  final int sourceBytes;
  final int? initialValue;
  final String? initialUnit;

  const TargetSizeSelector({
    super.key,
    required this.onTargetSet,
    this.onModeChanged,
    required this.sourceBytes,
    this.initialValue,
    this.initialUnit = 'MB',
  });

  @override
  State<TargetSizeSelector> createState() => _TargetSizeSelectorState();
}

class _TargetSizeSelectorState extends State<TargetSizeSelector> {
  late TextEditingController _sizeController;
  late String _selectedUnit;
  PdfCompressionMode _selectedMode = PdfCompressionMode.recommended;
  int? _lastAutoAppliedBytes;

  @override
  void initState() {
    super.initState();
    _sizeController = TextEditingController(
      text: widget.initialValue?.toString() ?? '',
    );
    _selectedUnit = widget.initialUnit ?? 'MB';
    _sizeController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sizeController.dispose();
    super.dispose();
  }

  int _calculateTargetBytes(double value, String unit) {
    if (unit == 'KB') {
      return (value * 1024).round(); // KB to bytes
    } else {
      return (value * 1024 * 1024).round(); // MB to bytes
    }
  }

  int _targetForProfile(PdfCompressionMode mode) {
    final source = widget.sourceBytes;
    final ratio = switch (mode) {
      PdfCompressionMode.smallSize => 0.35,
      PdfCompressionMode.recommended => 0.55,
      PdfCompressionMode.highQuality => 0.72,
      PdfCompressionMode.targetSize => 0.55,
    };

    if (source <= 100 * 1024) {
      return max(1, source - 1024);
    }

    final target = (source * ratio).round();
    final minTarget = 100 * 1024;
    final maxTarget = max(minTarget, source - 1024);
    return target.clamp(minTarget, maxTarget);
  }

  String _modeLabel(PdfCompressionMode mode) {
    return switch (mode) {
      PdfCompressionMode.smallSize => 'Small Size',
      PdfCompressionMode.recommended => 'Recommended',
      PdfCompressionMode.highQuality => 'High Quality',
      PdfCompressionMode.targetSize => 'Target Size',
    };
  }

  void _onModeSelected(PdfCompressionMode mode) {
    setState(() {
      _selectedMode = mode;
    });
    widget.onModeChanged?.call(mode);

    if (mode != PdfCompressionMode.targetSize) {
      final profileTarget = _targetForProfile(mode);
      _lastAutoAppliedBytes = profileTarget;
      widget.onTargetSet(profileTarget, profileTarget < 1024 * 1024 ? 'KB' : 'MB');
    } else {
      _autoApplyTargetIfValid();
    }
  }

  void _applyPresetKb(int kb) {
    setState(() {
      if (kb >= 1024) {
        _selectedUnit = 'MB';
        _sizeController.text = (kb / 1024).toStringAsFixed(kb % 1024 == 0 ? 0 : 2);
      } else {
        _selectedUnit = 'KB';
        _sizeController.text = kb.toString();
      }
    });
    _autoApplyTargetIfValid();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    }
  }

  void _autoApplyTargetIfValid() {
    final value = double.tryParse(_sizeController.text.trim());
    if (value == null || value <= 0) {
      return;
    }

    final targetBytes = _calculateTargetBytes(value, _selectedUnit);
    if (_lastAutoAppliedBytes == targetBytes) {
      return;
    }

    _lastAutoAppliedBytes = targetBytes;
    widget.onTargetSet(targetBytes, _selectedUnit);
  }

  void _onApply() {
    final value = double.tryParse(_sizeController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid size'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final targetBytes = _calculateTargetBytes(value, _selectedUnit);
    widget.onTargetSet(targetBytes, _selectedUnit);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ Target set to ${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} ${_selectedUnit} (${_formatBytes(targetBytes)})',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compression Mode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModeChip(PdfCompressionMode.smallSize),
              _buildModeChip(PdfCompressionMode.recommended),
              _buildModeChip(PdfCompressionMode.highQuality),
              _buildModeChip(PdfCompressionMode.targetSize),
            ],
          ),
          const SizedBox(height: 14),
          if (_selectedMode != PdfCompressionMode.targetSize)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '${_modeLabel(_selectedMode)} will auto-optimize around ${_formatBytes(_targetForProfile(_selectedMode))}.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E4E8C),
                ),
              ),
            ),
          if (_selectedMode != PdfCompressionMode.targetSize)
            const SizedBox(height: 16),

          const Text(
            'Target Compression Size',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use target mode for exact size presets or custom value',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedMode == PdfCompressionMode.targetSize)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kb in const [100, 200, 300, 400, 500, 800, 1024])
                  ActionChip(
                    label: Text(kb >= 1024 ? '1 MB' : '$kb KB'),
                    onPressed: () => _applyPresetKb(kb),
                  ),
              ],
            ),
          if (_selectedMode == PdfCompressionMode.targetSize)
            const SizedBox(height: 12),

          // Input Row
          Row(
            children: [
              // Size Input Field
              Expanded(
                child: TextField(
                  controller: _sizeController,
                  enabled: _selectedMode == PdfCompressionMode.targetSize,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;
                      if (text.isEmpty) {
                        return newValue;
                      }

                      final valid = RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text);
                      return valid ? newValue : oldValue;
                    }),
                  ],
                    onChanged: (_) => _selectedMode == PdfCompressionMode.targetSize
                      ? _autoApplyTargetIfValid()
                      : null,
                  decoration: InputDecoration(
                    hintText: 'Enter size',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF007AFF),
                        width: 2,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Unit Buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildUnitButton('KB'),
                    _buildUnitButton('MB'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preview
          if (_selectedMode == PdfCompressionMode.targetSize && _sizeController.text.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Target Size:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    _formatBytes(
                      _calculateTargetBytes(
                        double.tryParse(_sizeController.text) ?? 0,
                        _selectedUnit,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Apply Button
          if (_selectedMode == PdfCompressionMode.targetSize)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onApply,
                icon: const Icon(Icons.check_circle),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Apply Target Size',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeChip(PdfCompressionMode mode) {
    final selected = _selectedMode == mode;
    return ChoiceChip(
      label: Text(_modeLabel(mode)),
      selected: selected,
      onSelected: (_) => _onModeSelected(mode),
      selectedColor: const Color(0xFF0A4FA6).withOpacity(0.15),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? const Color(0xFF0A4FA6) : const Color(0xFF374151),
      ),
      side: BorderSide(color: selected ? const Color(0xFF0A4FA6) : Colors.grey.shade400),
    );
  }

  Widget _buildUnitButton(String unit) {
    final isSelected = _selectedUnit == unit;

    return InkWell(
      onTap: () {
        if (_selectedMode != PdfCompressionMode.targetSize) {
          return;
        }
        setState(() {
          _selectedUnit = unit;
        });
        _autoApplyTargetIfValid();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          unit,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// Compact Target Size Display
class CompactTargetSizeDisplay extends StatelessWidget {
  final int targetBytes;
  final String unit;

  const CompactTargetSizeDisplay({
    super.key,
    required this.targetBytes,
    required this.unit,
  });

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.compress,
            size: 16,
            color: Color(0xFF007AFF),
          ),
          const SizedBox(width: 6),
          Text(
            'Target: ${_formatBytes(targetBytes)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF007AFF),
            ),
          ),
        ],
      ),
    );
  }
}
