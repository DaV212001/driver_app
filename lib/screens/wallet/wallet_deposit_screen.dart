import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/earnings_controller.dart';
import '../../core/theme/app_colors.dart';

class WalletDepositScreen extends StatefulWidget {
  const WalletDepositScreen({super.key});

  @override
  State<WalletDepositScreen> createState() => _WalletDepositScreenState();
}

class _WalletDepositScreenState extends State<WalletDepositScreen> {
  final EarningsController _earningsCtrl = Get.isRegistered<EarningsController>()
      ? Get.find<EarningsController>()
      : Get.put(EarningsController());

  final TextEditingController _amountCtrl = TextEditingController(text: '100');
  final List<double> _quickAmounts = const [100.0, 250.0, 500.0, 1000.0];
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDeposit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      if (!Get.testMode && Get.context != null) {
        Get.snackbar(
          'Invalid Amount',
          'Please enter a valid amount greater than 0',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final success = await _earningsCtrl.depositToWallet(amount: amount);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success && Navigator.canPop(context)) {
        Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        title: const Text(
          'Top-up Wallet',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.darkOutline : AppColors.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Top-up Wallet',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Choose an amount to add to your balance:',
                style: TextStyle(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amt) {
                  final isSelected = _amountCtrl.text == amt.toStringAsFixed(0);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _amountCtrl.text = amt.toStringAsFixed(0);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkSurfaceContainerLow
                                : AppColors.surfaceContainerLow),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '+${amt.toStringAsFixed(0)} Br',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Custom Amount',
                  suffixText: 'Br',
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkInputBg : AppColors.inputBg,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Secured with Chapa Payment Gateway',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleDeposit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Proceed to Pay',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
