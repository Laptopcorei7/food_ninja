import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// 'visa' or 'mastercard' from the first digits of a card number, else null.
String? cardBrand(String number) {
  final d = _digits(number);
  if (d.startsWith('4')) return 'visa';
  if (RegExp('^5[1-5]').hasMatch(d)) return 'mastercard';
  // Mastercard's 2-series: 2221 to 2720.
  if (d.length >= 4) {
    final first4 = int.parse(d.substring(0, 4));
    if (first4 >= 2221 && first4 <= 2720) return 'mastercard';
  }
  return null;
}

/// The Luhn check every card number passes; it catches most typos.
bool cardNumberValid(String number) {
  final d = _digits(number);
  if (d.length < 13 || d.length > 19) return false;
  var sum = 0;
  for (var i = 0; i < d.length; i++) {
    var n = int.parse(d[d.length - 1 - i]);
    if (i.isOdd) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return sum % 10 == 0;
}

/// True for "MM/YY" in this month or later.
bool expiryValid(String expiry, {DateTime? now}) {
  final match = RegExp(r'^(\d\d)/(\d\d)$').firstMatch(expiry);
  if (match == null) return false;
  final month = int.parse(match[1]!);
  final year = 2000 + int.parse(match[2]!);
  if (month < 1 || month > 12) return false;
  final today = now ?? DateTime.now();
  return DateTime(year, month + 1).isAfter(DateTime(today.year, today.month));
}

/// The Ghana network a mobile number belongs to, from its prefix, or null.
String? momoNetwork(String phone) {
  final local = _localPhone(phone);
  if (local.length < 3) return null;
  return switch (local.substring(0, 3)) {
    '024' || '025' || '053' || '054' || '055' || '059' => 'mtn',
    '020' || '050' => 'telecel',
    '026' || '027' || '056' || '057' => 'airteltigo',
    _ => null,
  };
}

/// "+233 24 123 4567" -> "0241234567".
String _localPhone(String phone) {
  final d = _digits(phone);
  return d.startsWith('233') ? '0${d.substring(3)}' : d;
}

/// Digits in groups of four: "4242 4242 4242 4242".
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = _digits(newValue.text);
    final digits = d.length > 19 ? d.substring(0, 19) : d;
    final text = [
      for (var i = 0; i < digits.length; i += 4)
        digits.substring(i, i + 4 > digits.length ? digits.length : i + 4),
    ].join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// "MMYY" typed as "MM/YY".
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = _digits(newValue.text);
    final digits = d.length > 4 ? d.substring(0, 4) : d;
    final text = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _message(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Adds a card (kit 4.1.1-M). The brand shows as the number is typed. Only
/// the brand and last 4 digits are saved; the full number and the CVV will
/// go to the payment provider when real payments arrive.
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({this.existingId, super.key});

  /// A card chosen at sign-up without its number: it gets the digits
  /// instead of a new card being added.
  final String? existingId;

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _catalog = CatalogService();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The preview card follows the fields.
    for (final c in [_name, _number, _expiry]) {
      c.addListener(_redraw);
    }
  }

  void _redraw() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _expiry.dispose();
    super.dispose();
  }

  String? _problem() {
    if (_name.text.trim().isEmpty) return 'Enter the name on the card.';
    final brand = cardBrand(_number.text);
    if (_digits(_number.text).length >= 4 && brand == null) {
      return 'We take Visa and Mastercard.';
    }
    if (!cardNumberValid(_number.text) || brand == null) {
      return 'Check the card number.';
    }
    if (!expiryValid(_expiry.text)) {
      return 'Enter the expiry date as MM/YY. The card must not have expired.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    setState(() => _error = problem);
    if (problem != null) return;
    final digits = _digits(_number.text);
    final brand = cardBrand(digits);
    final last4 = digits.substring(digits.length - 4);
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final saved = switch (widget.existingId) {
        final id? =>
          await _catalog.updatePaymentMethod(id, brand: brand, last4: last4),
        null => await _catalog.addPaymentMethod(
            'card',
            brand: brand,
            last4: last4,
          ),
      };
      if (mounted) nav.pop(saved);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[AddCard] save failed: $e');
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SheetScaffold(
      title: 'Add card',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          _CardPreview(
            number: _number.text,
            name: _name.text.trim(),
            expiry: _expiry.text,
            brand: cardBrand(_number.text),
          ),
          const SizedBox(height: 28),
          AuthTextField(
            controller: _name,
            label: 'Name on card',
            hint: 'Ama Mensah',
            autofillHints: const [AutofillHints.creditCardName],
            textCapitalization: TextCapitalization.words,
          ),
          AuthTextField(
            controller: _number,
            label: 'Card number',
            hint: '0000 0000 0000 0000',
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.creditCardNumber],
            inputFormatters: [_CardNumberFormatter()],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 160,
              child: AuthTextField(
                controller: _expiry,
                label: 'Expiry date',
                hint: 'MM/YY',
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.creditCardExpirationDate],
                textInputAction: TextInputAction.done,
                inputFormatters: [_ExpiryFormatter()],
              ),
            ),
          ),
          Text(
            'We keep only the brand and last 4 digits.',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: colors.accentText, fontSize: 15),
            ),
          ],
          const SizedBox(height: 28),
          Center(
            child: MajorButton(
              horizontal: 48,
              vertical: 12,
              textonButton: _saving ? 'Saving…' : 'Save card',
              onPress: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// The kit's card picture: yellow with an orange and a cream corner. Its
/// colours are fixed, like a real card, in both themes.
class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.number,
    required this.name,
    required this.expiry,
    required this.brand,
  });

  final String number;
  final String name;
  final String expiry;
  final String? brand;

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.brown;
    final logo = switch (brand) {
      'visa' => 'assets/images/visa.png',
      'mastercard' => 'assets/images/mastercard.png',
      _ => null,
    };
    TextStyle small(FontWeight w) =>
        TextStyle(fontSize: 13, fontWeight: w, color: ink);
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CustomPaint(
            painter: _CornersPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: SizedBox(
                      height: 44,
                      width: 44,
                      child:
                          logo == null ? null : Image.asset(logo, color: ink),
                    ),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      number.isEmpty ? '0000 0000 0000 0000' : number,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Card holder', style: small(FontWeight.w400)),
                            Text(
                              name.isEmpty ? 'Your name' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: small(FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expires', style: small(FontWeight.w400)),
                          Text(
                            expiry.isEmpty ? 'MM/YY' : expiry,
                            style: small(FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
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

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = AppColors.yellow)
      ..drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.58, 0)
          ..lineTo(0, h * 0.5)
          ..close(),
        Paint()..color = AppColors.orange,
      )
      ..drawPath(
        Path()
          ..moveTo(w * 0.63, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h * 0.38)
          ..close(),
        Paint()..color = AppColors.cream,
      );
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => false;
}

/// Adds a mobile money wallet: the number picks the network, which the
/// user can change (numbers can move between networks).
class AddMomoScreen extends StatefulWidget {
  const AddMomoScreen({this.existingId, super.key});

  final String? existingId;

  @override
  State<AddMomoScreen> createState() => _AddMomoScreenState();
}

class _AddMomoScreenState extends State<AddMomoScreen> {
  final _phone = TextEditingController();
  final _catalog = CatalogService();
  String? _network;

  /// True once the user taps a network; the number stops choosing it.
  bool _picked = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _onPhone(String text) {
    if (_picked) return;
    setState(() => _network = momoNetwork(text));
  }

  Future<void> _save() async {
    final local = _localPhone(_phone.text);
    final network = _network;
    final problem = !RegExp(r'^0\d{9}$').hasMatch(local)
        ? 'Enter your 10-digit mobile number.'
        : network == null
            ? 'Choose your network.'
            : null;
    setState(() => _error = problem);
    if (problem != null) return;
    final last4 = local.substring(local.length - 4);
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final saved = switch (widget.existingId) {
        final id? => await _catalog.updatePaymentMethod(
            id,
            network: network,
            last4: last4,
          ),
        null => await _catalog.addPaymentMethod(
            'momo',
            network: network,
            last4: last4,
          ),
      };
      if (mounted) nav.pop(saved);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[AddMomo] save failed: $e');
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SheetScaffold(
      title: 'Add mobile money',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          AuthTextField(
            controller: _phone,
            label: 'Mobile number',
            hint: '024 123 4567',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
            onChanged: _onPhone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d +]')),
            ],
          ),
          Semantics(
            header: true,
            child: Text(
              'Network',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          for (final MapEntry(key: id, value: name)
              in PaymentMethod.networks.entries) ...[
            ChoiceRow(
              leading: Icon(
                Icons.phone_android_rounded,
                size: 28,
                color: colors.accentText,
              ),
              title: name,
              selected: _network == id,
              onTap: () => setState(() {
                _network = id;
                _picked = true;
              }),
            ),
            Divider(color: colors.divider),
          ],
          const SizedBox(height: 8),
          Text(
            'We keep only the network and last 4 digits.',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: colors.accentText, fontSize: 15),
            ),
          ],
          const SizedBox(height: 28),
          Center(
            child: MajorButton(
              horizontal: 48,
              vertical: 12,
              textonButton: _saving ? 'Saving…' : 'Save',
              onPress: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
