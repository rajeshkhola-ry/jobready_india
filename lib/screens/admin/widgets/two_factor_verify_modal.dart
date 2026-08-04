import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../../Services/admin_auth_service.dart';

class TwoFactorVerifyModal extends StatefulWidget {
  const TwoFactorVerifyModal({
    super.key,
    required this.authService,
    required this.adminUid,
  });

  final AdminAuthService authService;
  final String adminUid;

  @override
  State<TwoFactorVerifyModal> createState() => _TwoFactorVerifyModalState();
}

class _TwoFactorVerifyModalState extends State<TwoFactorVerifyModal> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _recoveryCodeController = TextEditingController();

  bool _verifying = false;
  bool _useRecoveryCode = false;
  String? _errorText;

  @override
  void dispose() {
    _otpController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otpCode = _otpController.text.trim();
    final recoveryCode = _recoveryCodeController.text.trim();

    if (!_useRecoveryCode && otpCode.length != 6) {
      setState(() {
        _errorText = 'Enter the 6-digit authenticator code.';
      });
      return;
    }
    if (_useRecoveryCode && recoveryCode.isEmpty) {
      setState(() {
        _errorText = 'Enter one backup recovery code.';
      });
      return;
    }

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      final result = await widget.authService.verifyAdmin2FACode(
        adminUid: widget.adminUid,
        otpCode: _useRecoveryCode ? '' : otpCode,
        recoveryCode: _useRecoveryCode ? recoveryCode : null,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        Navigator.of(context).pop(result);
        return;
      }

      setState(() {
        _errorText = 'Invalid code. Please try again.';
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
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2FA Verification',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your live Microsoft Authenticator code to continue.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.5),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _useRecoveryCode,
                title: const Text('Use backup recovery code'),
                onChanged: (value) {
                  setState(() {
                    _useRecoveryCode = value;
                    _errorText = null;
                  });
                },
              ),
              if (_useRecoveryCode)
                TextField(
                  controller: _recoveryCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Recovery Code',
                    hintText: 'XXXXX-XXXXX',
                  ),
                )
              else
                Pinput(
                  controller: _otpController,
                  length: 6,
                  keyboardType: TextInputType.number,
                  onCompleted: (_) => _verify(),
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
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify and Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
