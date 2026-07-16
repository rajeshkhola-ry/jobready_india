import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Target Size Selector for Compression
/// User specifies desired file size (e.g., 90MB, 500KB)
class TargetSizeSelector extends StatefulWidget {
  final Function(int, String) onTargetSet; // targetSize in bytes, unit (KB/MB)
  final int? initialValue;
  final String? initialUnit;

  const TargetSizeSelector({
    super.key,
    required this.onTargetSet,
    this.initialValue,
    this.initialUnit = 'MB',
  });

  @override
  State<TargetSizeSelector> createState() => _TargetSizeSelectorState();
}

class _TargetSizeSelectorState extends State<TargetSizeSelector> {
  late TextEditingController _sizeController;
  late String _selectedUnit;
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
            'Target Compression Size',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter desired file size and select unit',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          // Input Row
          Row(
            children: [
              // Size Input Field
              Expanded(
                child: TextField(
                  controller: _sizeController,
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
                  onChanged: (_) => _autoApplyTargetIfValid(),
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
          if (_sizeController.text.isNotEmpty)
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

  Widget _buildUnitButton(String unit) {
    final isSelected = _selectedUnit == unit;

    return InkWell(
      onTap: () {
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
