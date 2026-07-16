import 'api_config.dart';
import 'public_brand_config.dart';

class OtpActionResult {
  final bool success;
  final String message;
  final String? otpReference;

  const OtpActionResult({
    required this.success,
    required this.message,
    this.otpReference,
  });
}

class OtpService {
  const OtpService();

  bool get isOtpEnabled => ApiConfig.featureFlags['email_otp_enabled'] == true;

  Future<OtpActionResult> requestOtpForSupportEmail({
    String purpose = 'support_login',
  }) {
    return requestOtp(email: PublicBrandConfig.supportEmail, purpose: purpose);
  }

  Future<OtpActionResult> requestOtp({
    required String email,
    String purpose = 'login',
  }) async {
    if (!_isValidEmail(email)) {
      return const OtpActionResult(
        success: false,
        message: 'Please enter a valid email address.',
      );
    }

    final response = await ApiService.requestEmailOtp(
      email: email,
      purpose: purpose,
    );

    return OtpActionResult(
      success: response['status'] == 'success',
      message: response['message']?.toString() ?? 'OTP request response received.',
      otpReference: response['otp_reference']?.toString(),
    );
  }

  Future<OtpActionResult> verifyOtp({
    required String email,
    required String otpCode,
    String? otpReference,
  }) async {
    if (!_isValidEmail(email)) {
      return const OtpActionResult(
        success: false,
        message: 'Please enter a valid email address.',
      );
    }

    final response = await ApiService.verifyEmailOtp(
      email: email,
      otpCode: otpCode,
      otpReference: otpReference,
    );

    return OtpActionResult(
      success: response['verified'] == true,
      message: response['message']?.toString() ?? 'OTP verification response received.',
      otpReference: otpReference,
    );
  }

  Future<OtpActionResult> resendOtp({
    required String email,
    String? otpReference,
  }) async {
    if (!_isValidEmail(email)) {
      return const OtpActionResult(
        success: false,
        message: 'Please enter a valid email address.',
      );
    }

    final response = await ApiService.resendEmailOtp(
      email: email,
      otpReference: otpReference,
    );

    return OtpActionResult(
      success: response['status'] == 'success',
      message: response['message']?.toString() ?? 'OTP resend response received.',
      otpReference: response['otp_reference']?.toString(),
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }
}
