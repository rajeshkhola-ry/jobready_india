import 'package:flutter/material.dart';
import 'conversion_progress_dialog.dart';

class ChooseOutputDialog extends StatefulWidget {
  const ChooseOutputDialog({super.key});

  @override
  State<ChooseOutputDialog> createState() => _ChooseOutputDialogState();
}

class _ChooseOutputDialogState extends State<ChooseOutputDialog> {
  String selectedFormat = "Word (.docx)";

  final List<String> formats = [
    "Word (.docx)",
    "JPG Images",
    "PNG Images",
    "Text (.txt)",
    "Compress PDF",
    "Compress Images",
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.transform, color: Color(0xFF234E7D)),
          SizedBox(width: 10),
          Text(
            "Choose Output Format",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: formats.map((format) {
            return RadioListTile<String>(
              value: format,
              groupValue: selectedFormat,
              activeColor: const Color(0xFF234E7D),
              title: Text(format),
              onChanged: (value) {
                setState(() {
                  selectedFormat = value!;
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF234E7D),
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(context, selectedFormat);

            await Future.delayed(
              const Duration(milliseconds: 200),
            );

            if (!mounted) return;

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => ConversionProgressDialog(
                outputFormat: selectedFormat,
              ),
            );
          },
          child: const Text("Continue"),
        ),
      ],
    );
  }
}