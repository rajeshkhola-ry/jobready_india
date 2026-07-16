import 'package:flutter/material.dart';

import '../Services/owner_admin_access_service.dart';

class AdminGatePage extends StatefulWidget {
  final String targetRoute;

  const AdminGatePage({
    super.key,
    required this.targetRoute,
  });

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tryAutoOpen();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _tryAutoOpen() {
    if (!OwnerAdminAccessService.isUnlocked) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(widget.targetRoute);
    });
  }

  void _unlock() {
    final ok = OwnerAdminAccessService.unlockWithCode(_codeController.text);
    if (ok) {
      Navigator.of(context).pushReplacementNamed(widget.targetRoute);
      return;
    }

    setState(() {
      _errorText = 'Invalid owner code';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Admin Access'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin area is protected',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter owner code to continue.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _codeController,
                        obscureText: true,
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() {
                              _errorText = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Owner code',
                          errorText: _errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _unlock,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Unlock Admin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F4E79),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
