import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../controllers/driver_auth_controller.dart';
import '../../core/theme/app_colors.dart';

class DriverOtpScreen extends StatefulWidget {
  const DriverOtpScreen({super.key});

  @override
  State<DriverOtpScreen> createState() => _DriverOtpScreenState();
}

class _DriverOtpScreenState extends State<DriverOtpScreen> {
  final _otpController = TextEditingController();
  late final int userId;
  late final String phone;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    userId = args['userId'] is int
        ? args['userId']
        : int.tryParse(args['userId']?.toString() ?? '1') ?? 1;
    phone = args['phone']?.toString() ?? '';
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final authCtrl = Get.find<DriverAuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone'),
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
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sms_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AutoSizeText(
                    'Enter Verification Code',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    minFontSize: 16,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AutoSizeText(
                    'We sent a 4-digit SMS verification code to\n$phone',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    minFontSize: 11,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // OTP Input Field
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 14,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Verify Button
                  Obx(() {
                    final loading = authCtrl.isLoading.value;
                    return ElevatedButton(
                      onPressed: loading
                          ? null
                          : () {
                              final otp = _otpController.text.trim();
                              if (otp.length < 4) {
                                Get.snackbar(
                                  'Incomplete Code',
                                  'Please enter the full 4-digit code',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                return;
                              }
                              authCtrl.verifyOtpAndComplete(
                                userId: userId,
                                otp: otp,
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
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify & Proceed',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Resend Code
                  TextButton.icon(
                    onPressed: () => authCtrl.resendOtp(phone: phone),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Resend Code'),
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
