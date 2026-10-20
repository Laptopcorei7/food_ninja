import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/services/sms_code_listener.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/setup_layout.dart';

/// Sends a 4-digit code to [contact] and checks what the user types.
///
/// Without [resetMethod] it verifies the signed-in user's phone during
/// sign-up and continues to the payment method. With it ('sms' or 'email')
/// it checks a forgot-password code and continues to the new password screen.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    required this.contact,
    this.resetMethod,
    super.key,
  });

  final String contact;
  final String? resetMethod;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final _authService = AuthService();
  final _smsListener = SmsCodeListener();

  Timer? _timer;
  int _secondsLeft = 90;

  /// Wrong codes entered for the current code. The server refuses a code
  /// after 5, even the right one, so Resend is offered then.
  int _wrongTries = 0;

  /// Set after a 429; Resend stays hidden since the server would refuse it.
  bool _rateLimited = false;

  bool get _isReset => widget.resetMethod != null;
  bool get _bySms => widget.resetMethod != 'email';

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (_bySms) unawaited(_listenForSms());
    unawaited(_sendOtp()); // fire and forget on arrival
  }

  Future<void> _send() => _isReset
      ? _authService.requestPasswordReset(widget.resetMethod!, widget.contact)
      : _authService.sendOtp(widget.contact);

  /// Stops the countdown so Resend shows now.
  void _offerResend() {
    _timer?.cancel();
    setState(() => _secondsLeft = 0);
  }

  /// Fills and submits the code when the SMS arrives (see SmsCodeListener).
  Future<void> _listenForSms() async {
    if (kDebugMode) {
      debugPrint(
        '[Verification] SMS app hash: ${await _smsListener.appSignature()}',
      );
    }
    await _smsListener.start((code) {
      if (!mounted) return;
      for (var i = 0; i < 4; i++) {
        _controllers[i].text = code[i];
      }
      unawaited(_handleVerify());
    });
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
      await _send();
    } on Object catch (e) {
      debugPrint('[Verification] auto-send failed: $e');
      if (!mounted) return;
      // No code went out, so offer Resend now instead of after the countdown.
      _rateLimited = e is RateLimitException;
      _offerResend();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: "Couldn't Send Code",
          message: e.toString().replaceAll('Exception: ', ''),
          primaryLabel: 'OK',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    try {
      // The Retriever listens for 5 minutes; start a fresh listener.
      if (_bySms) unawaited(_listenForSms());
      await _send();
      if (!mounted) return;
      setState(() {
        _secondsLeft = 90;
        _wrongTries = 0;
        _timer?.cancel();
      });
      _startTimer();
    } on Object catch (e) {
      if (!mounted) return;
      if (e is RateLimitException) setState(() => _rateLimited = true);
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
          message: 'Please enter the 4-digit code we sent you.',
          primaryLabel: 'OK',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      // Replace, so back from the next screen can't return to a used code.
      if (_isReset) {
        final resetToken =
            await _authService.verifyResetCode(widget.contact, otp);
        if (!mounted) return;
        nav.pop(); // dismiss overlay
        await nav.pushReplacementNamed(
          AppRoutes.newPassword,
          arguments: resetToken,
        );
      } else {
        await _authService.verifyOtp(otp);
        if (!mounted) return;
        nav.pop(); // dismiss overlay
        await nav.pushReplacementNamed(AppRoutes.paymentMethod);
      }
    } on Object catch (e) {
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      var message = e.toString().replaceAll('Exception: ', '');
      if (e is RateLimitException) {
        setState(() => _rateLimited = true);
      } else if (message.toLowerCase().contains('expired')) {
        _offerResend();
      } else if (++_wrongTries >= 5) {
        _offerResend();
        message = 'Too many wrong tries for this code. '
            'Tap Resend Code to get a new one.';
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Verification Failed',
          message: message,
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
    unawaited(_smsListener.stop());
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
    final contact = widget.contact;
    final at = contact.indexOf('@');
    final maskedContact = at > 0
        ? '${contact[0]}****${contact.substring(at)}'
        : contact.length > 4
            ? '${contact.substring(0, contact.length - 4)}****'
            : contact;

    return SetupLayout(
      title: 'Enter Code',
      intro: 'We sent a 4-digit code to $maskedContact. '
          'It expires in $_formattedTime.',
      buttonLabel: 'Verify',
      onButton: _handleVerify,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _otpBox(i)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (_secondsLeft == 0 && !_rateLimited)
          Center(
            child: AuthLink(
              prefix: "Didn't get it?",
              label: 'Resend code',
              onTap: _resendOtp,
            ),
          ),
      ],
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      height: 64,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        decoration: const InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
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
