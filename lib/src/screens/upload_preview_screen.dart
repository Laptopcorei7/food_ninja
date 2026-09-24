import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/setup_pattern.dart';

class UploadPreviewScreen extends StatefulWidget {
  const UploadPreviewScreen({super.key, this.imagePath});
  final String? imagePath;

  @override
  State<UploadPreviewScreen> createState() => _UploadPreviewState();
}

class _UploadPreviewState extends State<UploadPreviewScreen> {
  final _userService = UserService();

  Future<void> _handleNext() async {
    if (widget.imagePath == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'No Photo',
          message: 'Please select a photo before continuing.',
          primaryLabel: 'OK',
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    unawaited(showLoadingOverlay(context));
    final nav = Navigator.of(context);
    try {
      await _userService.uploadPhoto(widget.imagePath!);
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await nav.pushNamed(AppRoutes.setLocation);
    } on Object catch (e) {
      if (!mounted) return;
      nav.pop(); // dismiss overlay
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Upload Failed',
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
      body: Stack(
        children: [
          const SetupPattern(),
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
                        onTap: () => Navigator.maybePop(context),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Upload Your Photo\nProfile',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 25,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'This data will be displayed in your account\nprofile for security',
                      style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _imagePreview(),
                    const SizedBox(height: 150),
                    Center(
                      child: MajorButton(
                        horizontal: 60,
                        vertical: 20,
                        textonButton: 'Next',
                        onPress: _handleNext,
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

  Widget _imagePreview() {
    return Center(
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
              image: widget.imagePath != null
                  ? DecorationImage(
                      image: FileImage(File(widget.imagePath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, AppRoutes.uploadPhoto);
              },
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
