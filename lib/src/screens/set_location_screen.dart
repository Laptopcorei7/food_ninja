import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/sign_up_screen.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class SetLocationScreen extends StatefulWidget {
  const SetLocationScreen({super.key});

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final TextEditingController _locationController = TextEditingController();
  final _userService = UserService();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    final address = _locationController.text.trim();

    if (address.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Enter Location',
          message: 'Please enter your delivery address to continue.',
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      // lat/lng default to 0.0 — maps integration will update these later
      await _userService.updateLocation(address, 0, 0);
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await nav.push<void>(
        MaterialPageRoute<void>(builder: (_) => const SignupSuccessScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Error',
          message: e.toString().replaceAll('Exception: ', ''),
          primaryLabel: 'Try Again',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

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
                    'Set Your Location',
                    style: TextStyle(
                      fontFamily: 'BentonSansBold',
                      fontSize: 25,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'This data will be used for your delivery address',
                    style: TextStyle(
                      fontFamily: 'BentonSansBook',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF53E88B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF53E88B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            style: const TextStyle(
                              fontFamily: 'BentonSansRegular',
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Your Location',
                              hintStyle: TextStyle(
                                fontFamily: 'BentonSansRegular',
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Center(
                    child: MajorButton(
                      horizontal: 75,
                      vertical: 23,
                      textonButton: 'Next',
                      onPress: _handleNext,
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
}
