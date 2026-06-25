import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/payment_method_screen.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({required this.phoneNumber, super.key});
  final String phoneNumber;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _timer;
  int _secondsLeft = 90; // 1 minute 30 seconds

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _formattedTime {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = widget.phoneNumber.length > 4
        ? '${widget.phoneNumber.substring(0, widget.phoneNumber.length - 4)}****'
        : widget.phoneNumber;

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
            child: SingleChildScrollView(
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
                      'Enter 4-digit\nVerification code',
                      style: TextStyle(
                        fontFamily: 'BentonSansBold',
                        fontSize: 25,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Code send to $maskedPhone . This code will expired in $_formattedTime',
                      style: const TextStyle(
                        fontFamily: 'BentonSansBook',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, _otpBox),
                    ),
                    const SizedBox(height: 200),

                    Center(
                      child: MajorButton(
                        horizontal: 75,
                        vertical: 23,
                        textonButton: 'Next',
                        onPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const PaymentMethodScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 70,
      height: 70,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 28,
          fontFamily: 'BentonSansBold',
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF53E88B),
              width: 2,
            ),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            // Move to next box automatically
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            // Move back on delete
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
