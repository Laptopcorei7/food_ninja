import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/auth_layout.dart';
import 'package:food_ninja/src/widgets/custom_checkboxes.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

bool _same(DeliveryAddress a, DeliveryAddress? b) =>
    b != null && a.address == b.address && a.lat == b.lat && a.lng == b.lng;

String _message(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Where to deliver (kit 4.1.1-J): the phone's current position, the saved
/// addresses and the sign-up address. Tapping one returns it.
class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({this.selected, super.key});

  final DeliveryAddress? selected;

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final _catalog = CatalogService();
  final _location = LocationService();
  StreamSubscription<DeliveryAddress>? _gps;

  DeliveryAddress? _here;
  bool _locating = true;
  List<DeliveryAddress>? _saved;
  DeliveryAddress? _signUp;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gps = _location.currentAddress().listen(
          (found) => setState(() => _here = found),
          onError: (Object e) => debugPrint('[DeliveryAddress] GPS: $e'),
          onDone: () {
            if (mounted) setState(() => _locating = false);
          },
        );
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_gps?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    // The sign-up address is a spare; failing to get it hides only its row.
    final signUp = _location.signUpAddress().then<DeliveryAddress?>(
      (a) => a,
      onError: (Object e) {
        debugPrint('[DeliveryAddress] sign-up address: $e');
        return null;
      },
    );
    try {
      final saved = await _catalog.addresses();
      final spare = await signUp;
      if (mounted) {
        setState(() {
          _saved = saved;
          _signUp = spare;
        });
      }
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[DeliveryAddress] load failed: $e');
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _add() async {
    final nav = Navigator.of(context);
    final added = await nav.push(
      MaterialPageRoute<DeliveryAddress>(
        builder: (_) => AddAddressScreen(here: _here),
      ),
    );
    if (added != null && mounted) nav.pop(added);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final saved = _saved;
    final signUp = _signUp;
    final here = _here;
    final showSignUp = signUp != null &&
        !(saved ?? const []).any((a) => a.address == signUp.address);
    return SheetScaffold(
      title: 'Delivery address',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          ChoiceRow(
            leading: ImageIcon(
              AppIcons.location,
              size: 30,
              color: colors.accentText,
            ),
            title: 'Current location',
            subtitle: here?.address ??
                (_locating
                    ? 'Finding your location…'
                    : 'Location is off or not allowed'),
            selected: here != null && _same(here, widget.selected),
            onTap: () {
              if (here != null) Navigator.of(context).pop(here);
            },
          ),
          Divider(color: colors.divider),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          else if (saved == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
            )
          else ...[
            for (final address in saved) ...[
              ChoiceRow(
                leading: ImageIcon(
                  AppIcons.home,
                  size: 30,
                  color: colors.accentText,
                ),
                title: address.label ?? 'Saved address',
                subtitle: address.address,
                selected: _same(address, widget.selected),
                onTap: () => Navigator.of(context).pop(address),
              ),
              Divider(color: colors.divider),
            ],
            if (showSignUp) ...[
              ChoiceRow(
                leading: ImageIcon(
                  AppIcons.home,
                  size: 30,
                  color: colors.accentText,
                ),
                title: 'Address from sign-up',
                subtitle: signUp.address,
                selected: _same(signUp, widget.selected),
                onTap: () => Navigator.of(context).pop(signUp),
              ),
              Divider(color: colors.divider),
            ],
          ],
          const SizedBox(height: 32),
          Center(
            child: MajorButton(
              horizontal: 32,
              vertical: 10,
              tone: ButtonTone.soft,
              textonButton: 'Add new address',
              onPress: _add,
            ),
          ),
        ],
      ),
    );
  }
}

/// Saves a named address (kit 4.1.1-K). The street can come from GPS or be
/// typed; a typed one is placed on the map so riders can find it.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({this.here, super.key});

  /// The phone's current address, if found, for "Use my current location".
  final DeliveryAddress? here;

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _label = TextEditingController();
  final _address = TextEditingController();
  final _catalog = CatalogService();
  final _location = LocationService();

  /// Where the GPS put the address now in the field, until it is edited.
  DeliveryAddress? _fromGps;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    super.dispose();
  }

  void _useGps(DeliveryAddress found) {
    _address.text = found.address;
    setState(() {
      _fromGps = found;
      _error = null;
    });
  }

  Future<void> _locate() async {
    if (widget.here case final here?) return _useGps(here);
    setState(() => _locating = true);
    try {
      // The last known address first, then a fresh fix, unless the user
      // has started editing the first.
      var found = false;
      await for (final address in _location.currentAddress()) {
        if (!mounted) return;
        if (found && _address.text != _fromGps?.address) break;
        found = true;
        _useGps(address);
      }
      if (!found && mounted) {
        setState(() => _error = "Couldn't find your location. Type it.");
      }
    } on Exception catch (e) {
      debugPrint('[AddAddress] locate failed: $e');
      if (mounted) setState(() => _error = "Couldn't find your location.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final text = _address.text.trim();
    if (label.isEmpty || text.isEmpty) {
      setState(() => _error = 'Give the address a name and a street.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      final gps = _fromGps;
      final placed = gps != null && gps.address == text
          ? gps
          : await _location.locate(text);
      if (placed == null) {
        throw Exception(
          "We couldn't find that address on the map. Add the area and city.",
        );
      }
      final saved = await _catalog.addAddress(
        label,
        DeliveryAddress(address: text, lat: placed.lat, lng: placed.lng),
      );
      if (mounted) nav.pop(saved);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[AddAddress] save failed: $e');
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SheetScaffold(
      title: 'Add new address',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          const Center(
            child: ImageIcon(
              AppIcons.location,
              size: 72,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _label,
            label: 'Name',
            hint: "Home, Work, Mum's house",
            textCapitalization: TextCapitalization.sentences,
          ),
          AuthTextField(
            controller: _address,
            label: 'Address',
            hint: 'Street, area, city',
            autofillHints: const [AutofillHints.fullStreetAddress],
            textInputAction: TextInputAction.done,
          ),
          if (_error case final error?) ...[
            Text(
              error,
              style: TextStyle(color: colors.accentText, fontSize: 15),
            ),
            const SizedBox(height: 12),
          ],
          Center(
            child: TextButton.icon(
              onPressed: _locating ? null : _locate,
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orange,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Use my current location'),
              style: TextButton.styleFrom(
                foregroundColor: colors.accentText,
                backgroundColor: colors.soft,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: MajorButton(
              horizontal: 48,
              vertical: 12,
              textonButton: _saving ? 'Saving…' : 'Save address',
              onPress: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
