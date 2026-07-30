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
  final TextEditingController _adminIdController = TextEditingController(
    text: OwnerAdminAccessService.adminId,
  );
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tryAutoOpen();
  }

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
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
    final ok = OwnerAdminAccessService.unlockWithCredentials(
      _adminIdController.text,
      _passwordController.text,
    );
    if (ok) {
      Navigator.of(context).pushReplacementNamed(widget.targetRoute);
      return;
    }

    setState(() {
      _errorText = 'Invalid admin login credentials';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3A66),
        foregroundColor: Colors.white,
        title: const Text('Owner Admin Access'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD8E5F5)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0E3A66).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0E3A66), size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Protected Admin Area',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter your admin credentials to continue into the system check and release tools.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _adminIdController,
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() {
                          _errorText = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Admin ID',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() {
                          _errorText = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: _errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('Unlock Admin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E3A66),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
