import 'package:flutter/material.dart';

import '../Services/auth_router_service.dart';
import '../Services/user_auth_service.dart';

enum UserAuthMode { signIn, createAccount }

typedef UserAuthCallback = void Function(String? plan, String? currency);

class UserAuthDialog extends StatefulWidget {
  final String? preselectedPlan;
  final String? selectedCurrency;
  final UserAuthCallback? onAuthenticated;

  const UserAuthDialog({
    super.key,
    this.preselectedPlan,
    this.selectedCurrency,
    this.onAuthenticated,
  });

  @override
  State<UserAuthDialog> createState() => _UserAuthDialogState();
}

class _UserAuthDialogState extends State<UserAuthDialog> {
  UserAuthMode _mode = UserAuthMode.signIn;
  bool _isSubmitting = false;
  String? _errorText;
  String? _successText;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(
    text: 'India',
  );
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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

        final session = await UserAuthService.signUpWithEmailPassword(
          displayName: _nameController.text.trim(),
          email: email,
          password: password,
          country: _countryController.text.trim().isNotEmpty
              ? _countryController.text.trim()
              : 'India',
          countryCode: '+91',
          mobileNumber: _mobileController.text.trim(),
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

      final session = await UserAuthService.signInWithEmailPassword(
        email,
        password,
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

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
      _successText = null;
    });

    try {
      final session = await UserAuthService.signInWithGoogle(
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : 'google-user@getreadyjob.com',
        displayName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Google User',
        country: _countryController.text.trim().isNotEmpty
            ? _countryController.text.trim()
            : 'India',
        countryCode: '+91',
        mobileNumber: _mobileController.text.trim(),
        selectedPlan: widget.preselectedPlan,
      );

      if (session == null) {
        setState(() {
          _errorText = 'Google sign-in could not be completed.';
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
          _errorText = 'Google sign-in failed. Please try again.';
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
                const SizedBox(height: 16),
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
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (!isCreateAccount) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  Text(
                    _successText!,
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _continueWithGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      foregroundColor: const Color(0xFF1E3A8A),
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
