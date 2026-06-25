import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/upload_photo_screen.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? _selected;

  final List<_PaymentOption> _options = const [
    _PaymentOption(id: 'paypal', label: 'PayPal', logoPath: 'assets/images/paypal.png'),
    _PaymentOption(id: 'visa', label: 'Visa', logoPath: 'assets/images/visa.png'),
    _PaymentOption(id: 'payoneer', label: 'Payoneer', logoPath: 'assets/images/payoneer.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 249, 253),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/pattern_2.png',
              fit: BoxFit.cover,
              height: 250,
              width: 200,
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 45,
                    height: 45,
                    child: CustomBackButton(
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontFamily: 'BentonSansBold',
                      fontSize: 25,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'This data will be displayed in your account\nprofile for security',
                    style: TextStyle(
                      fontFamily: 'BentonSansBook',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  ..._options.map(_buildOptionCard),

                  const Spacer(),

                  Center(
                    child: MajorButton(
                      horizontal: 75,
                      vertical: 23,
                      textonButton: 'Next',
                      onPress: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const UploadPhotoScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(_PaymentOption option) {
    final isSelected = _selected == option.id;

    return GestureDetector(
      onTap: () => setState(() => _selected = option.id),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF53E88B) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: _PaymentLogo(option: option),
        ),
      ),
    );
  }
}

class _PaymentOption {
  const _PaymentOption({
    required this.id,
    required this.label,
    required this.logoPath,
  });
  final String id;
  final String label;
  final String logoPath;
}

class _PaymentLogo extends StatelessWidget {
  const _PaymentLogo({required this.option});
  final _PaymentOption option;

  @override
  Widget build(BuildContext context) {
    return Text(
      option.label,
      style: const TextStyle(
        fontFamily: 'BentonSansBold',
        fontSize: 20,
        color: Colors.black87,
      ),
    );
  }
}
