import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../Services/admin_auth_service.dart';

class TwoFactorSetupModal extends StatefulWidget {
  const TwoFactorSetupModal({
    super.key,
    required this.authService,
  });

  final AdminAuthService authService;

  @override
  State<TwoFactorSetupModal> createState() => _TwoFactorSetupModalState();
}

class _TwoFactorSetupModalState extends State<TwoFactorSetupModal> {
  final TextEditingController _otpController = TextEditingController();

  bool _loadingSecret = true;
  bool _verifying = false;
  bool _verified = false;
  String? _errorText;
  String _otpauthUri = '';
  String _secret = '';
  List<String> _recoveryCodes = <String>[];

  @override
  void initState() {
    super.initState();
    _loadSecret();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadSecret() async {
    setState(() {
      _loadingSecret = true;
      _errorText = null;
    });

    try {
      final payload = await widget.authService.generate2FASecret();
      if (!mounted) {
        return;
      }
      setState(() {
        _otpauthUri = payload['otpauthUri']?.toString() ?? '';
        _secret = payload['secret']?.toString() ?? '';
        _recoveryCodes = List<String>.from(payload['recoveryCodes'] as List<dynamic>? ?? <dynamic>[]);
        _loadingSecret = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _loadingSecret = false;
      });
    }
  }

  Future<void> _verifySetup() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorText = 'Enter the 6-digit code from Microsoft Authenticator.';
      });
      return;
    }

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      final ok = await widget.authService.verifyAndEnable2FA(code: code);
      if (!mounted) {
        return;
      }
      if (!ok) {
        setState(() {
          _errorText = 'Invalid code. Check the current 6-digit code and try again.';
          _verifying = false;
        });
        return;
      }
      setState(() {
        _verified = true;
        _verifying = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loadingSecret
              ? const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Up 2FA',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Scan this QR in Microsoft Authenticator, then enter the current 6-digit code.',
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      if (_otpauthUri.isNotEmpty)
                        Center(
                          child: QrImageView(
                            data: _otpauthUri,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 10),
                      SelectableText(
                        'Secret: $_secret',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Pinput(
                        controller: _otpController,
                        length: 6,
                        keyboardType: TextInputType.number,
                        onCompleted: (_) => _verifySetup(),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorText!,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _verifying || _verified ? null : _verifySetup,
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_verified ? 'Verified' : 'Verify & Enable 2FA'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Backup Recovery Codes (single-use)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SelectableText(
                          _recoveryCodes.join('\n'),
                          style: const TextStyle(
                            fontFamily: 'Courier New',
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Save these codes securely. Each code can be used once if your authenticator is unavailable.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _verified ? () => Navigator.of(context).pop(true) : null,
                            child: const Text('I Saved Backup Codes, Continue'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
