import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../controllers/driver_auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../models/country_code.dart';
import '../../services/driver_auth_service.dart';
import '../../widgets/common/country_code_dropdown.dart';

class DriverForgotPasswordScreen extends StatefulWidget {
  const DriverForgotPasswordScreen({super.key});

  @override
  State<DriverForgotPasswordScreen> createState() =>
      _DriverForgotPasswordScreenState();
}

class _DriverForgotPasswordScreenState
    extends State<DriverForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1: Enter phone, 2: Enter OTP, 3: Reset password
  bool _obscurePassword = true;
  CountryCode _selectedCountry = CountryCode.defaultCountry;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    if (args['phone'] != null) {
      _phoneController.text = args['phone'].toString();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final authCtrl = Get.find<DriverAuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Indicator
                  Row(
                    children: [
                      _buildStepCircle(1, 'Phone'),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _step >= 2
                              ? AppColors.primary
                              : AppColors.outlineVariant,
                        ),
                      ),
                      _buildStepCircle(2, 'OTP'),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _step >= 3
                              ? AppColors.primary
                              : AppColors.outlineVariant,
                        ),
                      ),
                      _buildStepCircle(3, 'Password'),
                    ],
                  ),

                  const SizedBox(height: 32),

                  if (_step == 1) ...[
                    // STEP 1: Phone
                    AutoSizeText(
                      'Forgot Driver Password?',
                      maxLines: 1,
                      minFontSize: 16,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AutoSizeText(
                      'Enter your registered driver phone number and we will send you a verification code.',
                      maxLines: 2,
                      minFontSize: 11,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: _selectedCountry.dialCode == '+251'
                            ? '911234567 or 0911234567'
                            : 'Enter phone number',
                        prefixIcon: CountryCodeDropdown(
                          selectedCountry: _selectedCountry,
                          onChanged: (country) {
                            setState(() {
                              _selectedCountry = country;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Obx(() {
                      final loading = authCtrl.isSendingOtp.value;
                      return ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                                final rawPhone = _phoneController.text.trim();
                                final cleanPhone = DriverAuthService.sanitizePhone(
                                  rawPhone,
                                  _selectedCountry.dialCode,
                                );
                                final ok = await authCtrl.sendPasswordResetOtp(
                                  cleanPhone,
                                );
                                if (ok) {
                                  setState(() => _step = 2);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send Verification Code'),
                      );
                    }),
                  ] else if (_step == 2) ...[
                    // STEP 2: OTP
                    AutoSizeText(
                      'Verify Code',
                      maxLines: 1,
                      minFontSize: 16,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AutoSizeText(
                      'Enter the 4-digit code sent to ${_phoneController.text.trim()}',
                      maxLines: 2,
                      minFontSize: 11,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        letterSpacing: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final otp = _otpController.text.trim();
                        if (authCtrl.verifyPasswordResetOtp(otp)) {
                          setState(() => _step = 3);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Verify Code'),
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      final cooldown = authCtrl.resendCooldown.value;
                      return TextButton(
                        onPressed: cooldown > 0
                            ? null
                            : () => authCtrl.sendPasswordResetOtp(
                                  _phoneController.text.trim(),
                                ),
                        child: Text(
                          cooldown > 0
                              ? 'Resend Code in ${cooldown}s'
                              : 'Resend Code',
                        ),
                      );
                    }),
                  ] else ...[
                    // STEP 3: New Password
                    AutoSizeText(
                      'Set New Password',
                      maxLines: 1,
                      minFontSize: 16,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AutoSizeText(
                      'Create a secure password for your driver account.',
                      maxLines: 2,
                      minFontSize: 11,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: 'New Password (4-digit PIN)',
                        hintText: '4-digit PIN',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Confirm Password (4-digit PIN)',
                        hintText: '4-digit PIN',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Obx(() {
                      final loading = authCtrl.isResettingPassword.value;
                      return ElevatedButton(
                        onPressed: loading
                            ? null
                            : () {
                                authCtrl.resetPasswordWithOtp(
                                  newPassword: _passwordController.text,
                                  confirmPassword:
                                      _confirmPasswordController.text,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save New Password'),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCircle(int stepNum, String label) {
    final isActive = _step >= stepNum;
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor:
              isActive ? AppColors.primary : AppColors.outlineVariant,
          child: Text(
            '$stepNum',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
