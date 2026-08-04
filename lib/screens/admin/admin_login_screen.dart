import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../Services/auth_router_service.dart';
import '../../Services/admin_auth_service.dart';
import '../../Widgets/brand_logo_button.dart';
import '../../models/admin_user_model.dart';
import 'widgets/two_factor_setup_modal.dart';
import 'widgets/two_factor_verify_modal.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, this.targetRoute = '/admin-dashboard'});

  final String targetRoute;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AdminAuthService();

  bool _busy = false;
  bool _passwordVisible = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Enter admin email and password.';
      });
      return;
    }

    if (Firebase.apps.isEmpty) {
      setState(() {
        _errorText = 'Firebase is not initialized. Configure Firebase before using admin 2FA login.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      final admin = await _authService.signInAdmin(email: email, password: password);
      if (!mounted) {
        return;
      }

      final verificationResult = await _run2FAFlow(admin);
      if (!mounted || verificationResult == null || verificationResult['success'] != true) {
        setState(() {
          _busy = false;
        });
        return;
      }

      final authToken = (verificationResult['customToken']?.toString().trim().isNotEmpty ?? false)
          ? verificationResult['customToken'].toString().trim()
          : 'admin-2fa-session';
      await AuthRouterService.markAdminAuthenticated(authToken: authToken);
      if (!mounted) {
        return;
      }
      final route = widget.targetRoute.trim().isEmpty ? '/admin-dashboard' : widget.targetRoute;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString().replaceFirst('AdminAuthException: ', '');
        _busy = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _run2FAFlow(AdminUserModel admin) async {
    if (!admin.is2FAEnabled) {
      final setupDone = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TwoFactorSetupModal(authService: _authService),
      );
      if (setupDone == true) {
        return <String, dynamic>{'success': true};
      }
      return null;
    }

    final verifyResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TwoFactorVerifyModal(
        authService: _authService,
        adminUid: admin.uid,
      ),
    );

    return verifyResult;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0F172A),
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogoButton(
              size: 30,
              padding: const EdgeInsets.all(2),
              tooltip: 'Go to home',
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Admin Login',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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
                  const Text(
                    'Secure Admin Access',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign in with Firebase Auth email/password. You will complete Microsoft Authenticator verification before dashboard access.',
                    style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                        icon: Icon(
                          _passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _login,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: const Text('Continue to 2FA'),
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
