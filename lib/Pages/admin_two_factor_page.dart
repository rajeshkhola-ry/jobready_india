import 'package:flutter/material.dart';

import '../Services/auth_router_service.dart';
import '../Services/admin_remote_auth_service.dart';
import '../Services/owner_admin_access_service.dart';

class AdminTwoFactorPage extends StatefulWidget {
  const AdminTwoFactorPage({super.key});

  @override
  State<AdminTwoFactorPage> createState() => _AdminTwoFactorPageState();
}

class _AdminTwoFactorPageState extends State<AdminTwoFactorPage> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    if (!OwnerAdminAccessService.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
      });
      return;
    }
    if (!AdminRemoteAuthService.hasPendingChallenge) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        OwnerAdminAccessService.lock();
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
    if (_isSubmitting) {
      return;
    }
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorText = 'Enter the 6-digit OTP sent to your email.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final token = await AdminRemoteAuthService.verify(code);
    if (token == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorText = 'Invalid or expired OTP. Please try again or resend OTP.';
      });
      return;
    }

    OwnerAdminAccessService.markTwoFactorVerifiedForSession();
    await AuthRouterService.markAdminAuthenticated(authToken: token);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/admin-dashboard', (route) => false);
  }

  Future<void> _resendOtp() async {
    if (_isResending) {
      return;
    }
    setState(() {
      _isResending = true;
      _errorText = null;
    });
    final sent = await AdminRemoteAuthService.resendOtp();
    if (!mounted) {
      return;
    }
    setState(() {
      _isResending = false;
      if (!sent) {
        _errorText = 'Unable to resend OTP. Please sign in again.';
      }
    });
    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A fresh OTP has been sent. It is valid for 5 minutes.')),
      );
    } else {
      OwnerAdminAccessService.lock();
      AdminRemoteAuthService.clearPendingChallenge();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedDeliveryEmail = AdminRemoteAuthService.deliveryEmail.isNotEmpty
        ? AdminRemoteAuthService.deliveryEmail
        : 'RAJESH.KHOLA@GMAIL.COM';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Admin Email OTP Verification'),
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
                  const Text(
                    'Enter the 6-digit OTP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A fresh 6-digit OTP was sent to $maskedDeliveryEmail. OTP validity: 5 minutes.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '6-digit email OTP',
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
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(_isSubmitting ? 'Verifying...' : 'Verify OTP and Continue'),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isResending ? null : _resendOtp,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_isResending ? 'Resending OTP...' : 'Resend OTP'),
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
