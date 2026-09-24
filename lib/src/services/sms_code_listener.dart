import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads a 4-digit code from the sign-up SMS with Android's SMS Retriever
/// (android/.../MainActivity.kt). Fully automatic, but only for an SMS that
/// ends with [appSignature]; the server appends it. Does nothing off Android.
///
/// Not yet tested with a real SMS: dev prints codes to the server console.
class SmsCodeListener {
  static const _channel = MethodChannel('food_ninja/sms');
  static final _code = RegExp(r'\b\d{4}\b');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Calls [onCode] once when a matching SMS arrives within 5 minutes.
  Future<void> start(ValueChanged<String> onCode) async {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onSms') return;
      final match = _code.firstMatch(call.arguments as String? ?? '');
      if (match != null) onCode(match.group(0)!);
    });
    try {
      await _channel.invokeMethod<bool>('start');
    } on Exception catch (e) {
      // PlatformException, or MissingPluginException when the Android side
      // is not built in (e.g. after a hot restart).
      debugPrint('[SmsCodeListener] start failed: $e');
    }
  }

  Future<void> stop() async {
    if (!_supported) return;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('stop');
    } on Exception catch (e) {
      // PlatformException, or MissingPluginException when the Android side
      // is not built in (e.g. after a hot restart).
      debugPrint('[SmsCodeListener] stop failed: $e');
    }
  }

  /// The 11-character hash the SMS must end with. Differs between debug and
  /// release signing, so the server takes it from its environment.
  Future<String?> appSignature() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<String>('appSignature');
    } on Exception catch (e) {
      // PlatformException, or MissingPluginException when the Android side
      // is not built in (e.g. after a hot restart).
      debugPrint('[SmsCodeListener] appSignature failed: $e');
      return null;
    }
  }
}
