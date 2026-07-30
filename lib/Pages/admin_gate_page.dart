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
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF183A5B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Owner Admin Access'),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F4EE), Color(0xFFF2F7FF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF8),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF183A5B).withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF183A5B), size: 24),
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
                        height: 1.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF183A5B), width: 1.4),
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
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF183A5B), width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _unlock,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Unlock Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF183A5B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
