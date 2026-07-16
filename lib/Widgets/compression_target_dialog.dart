import 'package:flutter/material.dart';

class CompressionTargetDialog extends StatefulWidget {
  final String fileName;
  final int fileSizeBytes;

  const CompressionTargetDialog({
    super.key,
    required this.fileName,
    required this.fileSizeBytes,
  });

  @override
  State<CompressionTargetDialog> createState() => _CompressionTargetDialogState();
}

class _CompressionTargetDialogState extends State<CompressionTargetDialog> {
  String selectedUnit = 'KB';
  final TextEditingController _targetController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizeDisplay = widget.fileSizeBytes < 1024
        ? '${widget.fileSizeBytes} B'
        : widget.fileSizeBytes < 1024 * 1024
            ? '${(widget.fileSizeBytes / 1024).toStringAsFixed(1)} KB'
            : '${(widget.fileSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Compress File',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File: ${widget.fileName}'),
          const SizedBox(height: 6),
          Text('Current size: $sizeDisplay'),
          const SizedBox(height: 18),
          const Text('Target size'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter a value',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: selectedUnit,
                items: const [
                  DropdownMenuItem(value: 'KB', child: Text('KB')),
                  DropdownMenuItem(value: 'MB', child: Text('MB')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedUnit = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'The app will attempt to reduce the file size while keeping quality as good as possible.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(_targetController.text.trim());
            if (value == null || value <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid target size.'),
                ),
              );
              return;
            }

            final targetBytes = selectedUnit == 'MB'
                ? (value * 1024 * 1024).toInt()
                : (value * 1024).toInt();

            if (targetBytes >= widget.fileSizeBytes) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Target size must be smaller than the current file size.'),
                ),
              );
              return;
            }

            Navigator.pop(context, targetBytes);
          },
          child: const Text('Compress'),
        ),
      ],
    );
  }
}
