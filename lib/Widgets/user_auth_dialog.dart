import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/auth_router_service.dart';
import '../Services/shared_user_auth_service.dart';
import '../Services/user_auth_service.dart';

enum UserAuthMode { signIn, createAccount }

typedef UserAuthCallback = void Function(String? plan, String? currency);

class UserAuthDialog extends StatefulWidget {
  final String? preselectedPlan;
  final String? selectedCurrency;
  final UserAuthCallback? onAuthenticated;
  final bool stayOnHomeAfterAuth;

  const UserAuthDialog({
    super.key,
    this.preselectedPlan,
    this.selectedCurrency,
    this.onAuthenticated,
    this.stayOnHomeAfterAuth = false,
  });

  @override
  State<UserAuthDialog> createState() => _UserAuthDialogState();
}

class _UserAuthDialogState extends State<UserAuthDialog> {
  UserAuthMode _mode = UserAuthMode.signIn;
  bool _isSubmitting = false;
  bool _passwordVisible = false;
  String? _errorText;
  String? _successText;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(
    text: 'India',
  );
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isStrongPassword(String password) {
    if (password.length < 8) {
      return false;
    }
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    return hasUpper && hasLower && hasDigit;
  }

  bool _isValidMobile(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
      _successText = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorText = 'Please enter your email address and password.';
          _isSubmitting = false;
        });
        return;
      }

      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        setState(() {
          _errorText = 'Please enter a valid email address.';
          _isSubmitting = false;
        });
        return;
      }

      if (_mode == UserAuthMode.createAccount) {
        if (_nameController.text.trim().isEmpty) {
          setState(() {
            _errorText = 'Please enter your full name.';
            _isSubmitting = false;
          });
          return;
        }
        if (_mobileController.text.trim().isEmpty) {
          setState(() {
            _errorText = 'Please enter your mobile number.';
            _isSubmitting = false;
          });
          return;
        }
        if (!_isValidMobile(_mobileController.text.trim())) {
          setState(() {
            _errorText = 'Please enter a valid mobile number (minimum 10 digits).';
            _isSubmitting = false;
          });
          return;
        }
        if (!_isStrongPassword(password)) {
          setState(() {
            _errorText = 'Use a stronger password: minimum 8 characters with upper case, lower case, and a number.';
            _isSubmitting = false;
          });
          return;
        }

        final shared = await SharedUserAuthService.signup(
          fullName: _nameController.text.trim(),
          email: email,
          country: _countryController.text.trim().isNotEmpty
              ? _countryController.text.trim()
              : 'India',
          mobile: _mobileController.text.trim(),
          password: password,
        );
        if (!shared.success) {
          setState(() {
            _errorText = shared.error ?? 'Shared account creation failed.';
            _isSubmitting = false;
          });
          return;
        }
        final profile = shared.profile!;
        final session = await UserAuthService.signUpWithEmailPassword(
          displayName: profile.fullName,
          email: profile.email,
          password: password,
          country: profile.country,
          countryCode: profile.country.toLowerCase() == 'india' ? '+91' : '',
          mobileNumber: profile.mobile,
          selectedPlan: widget.preselectedPlan,
        );

        if (session == null) {
          setState(() {
            _errorText = 'Account creation failed. Please try again.';
            _isSubmitting = false;
          });
          return;
        }

        if (!mounted) {
          return;
        }
        await AuthRouterService.markUserAuthenticated(
          authToken: 'user-session',
        );
        Navigator.of(context).pop();
        if (widget.onAuthenticated != null) {
          widget.onAuthenticated!(
            widget.preselectedPlan,
            widget.selectedCurrency,
          );
          return;
        }
        if (widget.stayOnHomeAfterAuth) {
          return;
        }
        if (widget.preselectedPlan != null &&
            widget.preselectedPlan!.trim().isNotEmpty) {
          Navigator.of(context).pushNamed(
            '/dashboard',
            arguments: {'plan': widget.preselectedPlan},
          );
        } else {
          AuthRouterService.redirectAfterLogin(
            context,
            fallbackRoute: '/dashboard',
          );
        }
        return;
      }

      final shared = await SharedUserAuthService.login(email, password);
      if (!shared.success) {
        setState(() {
          _errorText = shared.error ?? 'Shared account sign-in failed.';
          _isSubmitting = false;
        });
        return;
      }
      final profile = shared.profile!;
      var session = await UserAuthService.signInWithEmailPassword(email, password, selectedPlan: widget.preselectedPlan);
      session ??= await UserAuthService.signUpWithEmailPassword(
        displayName: profile.fullName,
        email: profile.email,
        password: password,
        country: profile.country,
        countryCode: profile.country.toLowerCase() == 'india' ? '+91' : '',
        mobileNumber: profile.mobile,
        selectedPlan: widget.preselectedPlan,
      );
      if (session == null) {
        setState(() {
          _errorText =
              'We could not find that account. Try creating one first.';
          _isSubmitting = false;
        });
        return;
      }

      if (!mounted) {
        return;
      }
      await AuthRouterService.markUserAuthenticated(authToken: 'user-session');
      Navigator.of(context).pop();
      if (widget.onAuthenticated != null) {
        widget.onAuthenticated!(
          widget.preselectedPlan,
          widget.selectedCurrency,
        );
        return;
      }
      if (widget.stayOnHomeAfterAuth) {
        return;
      }
      if (widget.preselectedPlan != null &&
          widget.preselectedPlan!.trim().isNotEmpty) {
        Navigator.of(
          context,
        ).pushNamed('/dashboard', arguments: {'plan': widget.preselectedPlan});
      } else {
        AuthRouterService.redirectAfterLogin(
          context,
          fallbackRoute: '/dashboard',
        );
      }
    } on AuthRestrictionException catch (exception) {
      if (mounted) {
        setState(() {
          _errorText = exception.message;
          _isSubmitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = 'Something went wrong. Please try again.';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorText = 'Enter your email to request a reset.';
      });
      return;
    }

    final sent = await UserAuthService.requestPasswordReset(email);
    if (!mounted) {
      return;
    }
    setState(() {
      _successText = sent
          ? 'Password reset instructions are ready. Please check your inbox.'
          : 'We could not find a matching account yet.';
      _errorText = null;
    });
  }

  Future<void> _handleSocialAuth(String provider) async {
    final socialProvider = provider.trim().toLowerCase();
    final socialEmail = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : '${socialProvider}-${DateTime.now().millisecondsSinceEpoch}@getreadyjob.social';

    setState(() {
      _isSubmitting = true;
      _errorText = null;
      _successText = 'Opening ${socialProvider.toUpperCase()} sign-in...';
    });

    try {
      final authUrl = 'https://getreadyjob.com/api/auth/social?provider=$socialProvider&redirect=' +
          Uri.encodeComponent(html.window.location.href);
      final popup = html.window.open(authUrl, '_blank');
      if (popup == null) {
        throw Exception('Popup blocked');
      }

      final session = await UserAuthService.signInWithSocialProvider(
        provider: socialProvider,
        email: socialEmail,
        displayName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : socialEmail.split('@').first.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').trim(),
        country: _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : 'India',
        countryCode: _countryController.text.trim().toLowerCase() == 'india' ? '+91' : '',
        mobileNumber: _mobileController.text.trim(),
        selectedPlan: widget.preselectedPlan,
      );

      if (session == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = 'We could not continue with ${socialProvider.toUpperCase()} right now. Please try again.';
          _successText = null;
          _isSubmitting = false;
        });
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _successText = 'Signed in with ${socialProvider.toUpperCase()}.';
        _errorText = null;
        _isSubmitting = false;
      });
      await AuthRouterService.markUserAuthenticated(authToken: 'user-session');
      Navigator.of(context).pop();
      if (widget.onAuthenticated != null) {
        widget.onAuthenticated!(widget.preselectedPlan, widget.selectedCurrency);
        return;
      }
      if (widget.stayOnHomeAfterAuth) {
        return;
      }
      if (widget.preselectedPlan != null && widget.preselectedPlan!.trim().isNotEmpty) {
        Navigator.of(context).pushNamed('/dashboard', arguments: {'plan': widget.preselectedPlan});
      } else {
        AuthRouterService.redirectAfterLogin(context, fallbackRoute: '/dashboard');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = 'Something went wrong while continuing with ${provider.toUpperCase()}. Please try again.';
          _successText = null;
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _providerButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.25)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: color.withValues(alpha: 0.03),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreateAccount = _mode == UserAuthMode.createAccount;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isCreateAccount
                            ? 'Create your account'
                            : 'Welcome back',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _mode = isCreateAccount
                              ? UserAuthMode.signIn
                              : UserAuthMode.createAccount;
                          _emailController.clear();
                          _passwordController.clear();
                          _errorText = null;
                          _successText = null;
                        });
                      },
                      child: Text(
                        isCreateAccount ? 'Sign in instead' : 'Create account',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isCreateAccount
                      ? 'Create an account in a few steps and keep your conversions and plan access in sync.'
                      : 'Sign in quickly to view your dashboard, downloads, and plan access.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use your main GETREADYJOB account on getreadyjob.com to manage your plan and unlock the full job-ready tool suite.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _providerButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      color: const Color(0xFFEA4335),
                      onPressed: () => _handleSocialAuth('google'),
                    ),
                    const SizedBox(width: 8),
                    _providerButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple_rounded,
                      color: const Color(0xFF111827),
                      onPressed: () => _handleSocialAuth('apple'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _providerButton(
                      label: 'Continue with Microsoft',
                      icon: Icons.desktop_windows_rounded,
                      color: const Color(0xFF0078D4),
                      onPressed: () => _handleSocialAuth('microsoft'),
                    ),
                    const SizedBox(width: 8),
                    _providerButton(
                      label: 'Email / Password',
                      icon: Icons.mail_outline_rounded,
                      color: const Color(0xFF2563EB),
                      onPressed: () {
                        setState(() {
                          _mode = UserAuthMode.signIn;
                          _errorText = null;
                          _successText = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorText != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFB7185)),
                    ),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFBE123C),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (_successText != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Text(
                      _successText!,
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_errorText != null || _successText != null) const SizedBox(height: 12),
                if (isCreateAccount) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Email ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (isCreateAccount) ...[
                  TextField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      icon: Icon(_passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (isCreateAccount)
                  const Text(
                    'Password must be 8+ characters and include upper case, lower case, and a number.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                if (isCreateAccount) const SizedBox(height: 8),
                if (!isCreateAccount) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isCreateAccount
                                ? Icons.person_add_alt_1_rounded
                                : Icons.lock_open_rounded,
                          ),
                    label: Text(isCreateAccount ? 'Create account' : 'Sign in'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
