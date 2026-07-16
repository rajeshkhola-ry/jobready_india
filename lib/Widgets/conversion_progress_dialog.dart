import 'package:flutter/material.dart';
import 'download_result_dialog.dart';

class ConversionProgressDialog extends StatefulWidget {
  final String outputFormat;

  const ConversionProgressDialog({
    super.key,
    required this.outputFormat,
  });

  @override
  State<ConversionProgressDialog> createState() =>
      _ConversionProgressDialogState();
}

class _ConversionProgressDialogState
    extends State<ConversionProgressDialog> {

  double progress = 0;
  String status = "Preparing document...";

  @override
  void initState() {
    super.initState();
    startConversion();
  }

  Future<void> startConversion() async {

    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      progress = 0.25;
      status = "Reading document...";
    });

    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      progress = 0.50;
      status = "Converting to ${widget.outputFormat}...";
    });

    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      progress = 0.80;
      status = "Finalizing...";
    });

    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      progress = 1.0;
      status = "Conversion Completed";
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),

      title: const Text(
        "Converting...",
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),

      content: SizedBox(
  width: 380,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [

      const Icon(
        Icons.description_outlined,
        color: Color(0xFF1F4E79),
        size: 60,
      ),

      const SizedBox(height: 15),

      const Text(
        "Converting Document",
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 8),

      Text(
        "Output : ${widget.outputFormat}",
        style: const TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),

      const SizedBox(height: 25),

      LinearProgressIndicator(
        value: progress,
        minHeight: 12,
        borderRadius: BorderRadius.circular(20),
      ),

      const SizedBox(height: 18),

      Text(
        "${(progress * 100).toInt()} %",
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F4E79),
        ),
      ),

      const SizedBox(height: 18),

      Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),

      const SizedBox(height: 25),

      const Divider(),

      const SizedBox(height: 10),

      Row(
        children: const [

          Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: 20,
          ),

          SizedBox(width: 8),

          Expanded(
            child: Text(
              "Please don't close JOBREADY while conversion is in progress.",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 10),
    ],
  ),
),
    );
  }
}