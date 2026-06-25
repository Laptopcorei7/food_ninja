import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/payment_method_screen.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
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
  final _authService = AuthService();

  Timer? _timer;
  int _secondsLeft = 90;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _sendOtp(); // fire and forget on arrival
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

  Future<void> _sendOtp() async {
    try {
      await _authService.sendOtp(widget.phoneNumber);
    } catch (_) {
      // Silently ignore on auto-send; user can tap Resend if needed.
    }
  }

  Future<void> _resendOtp() async {
    try {
      await _authService.sendOtp(widget.phoneNumber);
      if (!mounted) return;
      setState(() {
        _secondsLeft = 90;
        _timer?.cancel();
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Failed to Send',
          message: e.toString().replaceAll('Exception: ', ''),
          primaryLabel: 'OK',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  Future<void> _handleVerify() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 4) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Enter Code',
          message: 'Please enter the 4-digit code sent to your phone.',
          primaryLabel: 'OK',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      await _authService.verifyOtp(otp);
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await nav.push<void>(
        MaterialPageRoute<void>(builder: (_) => const PaymentMethodScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Verification Failed',
          message: e.toString().replaceAll('Exception: ', ''),
          primaryLabel: 'Try Again',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  String get _formattedTime {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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
                      'Code sent to $maskedPhone. This code will expire in $_formattedTime',
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
                    const SizedBox(height: 24),

                    Center(
                      child: _secondsLeft == 0
                          ? TextButton(
                              onPressed: _resendOtp,
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF53E88B),
                                    Color(0xFF15BE77),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(
                                  Rect.fromLTWH(
                                    0,
                                    0,
                                    bounds.width,
                                    bounds.height,
                                  ),
                                ),
                                blendMode: BlendMode.srcIn,
                                child: const Text(
                                  'Resend Code',
                                  style: TextStyle(
                                    fontFamily: 'BentonSansMedium',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 176),

                    Center(
                      child: MajorButton(
                        horizontal: 75,
                        vertical: 23,
                        textonButton: 'Next',
                        onPress: _handleVerify,
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
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
