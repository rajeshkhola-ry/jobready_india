import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../Services/auth_router_service.dart';
import '../Services/owner_admin_access_service.dart';

class AdminTwoFactorPage extends StatefulWidget {
  const AdminTwoFactorPage({super.key});

  @override
  State<AdminTwoFactorPage> createState() => _AdminTwoFactorPageState();
}

class _AdminTwoFactorPageState extends State<AdminTwoFactorPage> {
  final TextEditingController _codeController = TextEditingController();
  late final bool _isSetupMode;
  late final TwoFactorSetupData _setupData;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _isSetupMode = !OwnerAdminAccessService.isTwoFactorConfigured;
    _setupData = OwnerAdminAccessService.initializeTwoFactorSetup();
    if (!OwnerAdminAccessService.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSetupMode) {
      await _handleSetup();
      return;
    }
    await _handleVerify();
  }

  Future<void> _handleSetup() async {
    final code = _codeController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorText = 'Enter a 6-digit authenticator code.';
      });
      return;
    }

    final ok = OwnerAdminAccessService.verifyTwoFactorCode(code);
    if (!ok) {
      setState(() {
        _errorText = 'Scan the QR code first, then enter the 6-digit code from your authenticator.';
      });
      return;
    }

    await AuthRouterService.markAdminAuthenticated(authToken: 'admin-session');

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('2FA Enabled'),
        content: Text(
          'Save this one-time recovery code in a safe place:\n\n${_setupData.recoveryCode}\n\n'
          'You can use it once if you cannot access your 2FA code.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/admin-dashboard', (route) => false);
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    final ok = OwnerAdminAccessService.verifyTwoFactorCode(code);

    if (!ok) {
      setState(() {
        _errorText = 'Invalid 2FA code or recovery code.';
      });
      return;
    }

    await AuthRouterService.markAdminAuthenticated(authToken: 'admin-session');

    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/admin-dashboard', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final setupUri = _setupData.otpauthUri;
    final recoveryCode = _setupData.recoveryCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Admin 2FA Verification'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSetupMode ? 'Set up two-factor security' : 'Verify with two-factor code',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isSetupMode
                        ? 'Scan the QR code in Google Authenticator or Microsoft Authenticator, then enter the 6-digit code it generates.'
                        : 'Enter your 6-digit 2FA code. You can also use your one-time recovery code.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if (_isSetupMode) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: setupUri,
                              size: 190,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Scan this QR code with your authenticator app.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'Manual setup key: ${_setupData.secret}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isSetupMode ? '2FA code from authenticator' : '2FA code or recovery code',
                      errorText: _errorText,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() {
                          _errorText = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(_isSetupMode ? 'Verify QR Setup and Continue' : 'Verify and Continue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF183A5B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (_isSetupMode) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Recovery code: $recoveryCode',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
