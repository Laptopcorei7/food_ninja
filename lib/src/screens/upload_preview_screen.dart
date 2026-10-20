import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/services/user_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/setup_layout.dart';

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
    return SetupLayout(
      title: 'Profile Photo',
      intro: 'Happy with it? Tap the camera to pick another.',
      onButton: _handleNext,
      children: [_imagePreview()],
    );
  }

  /// The kit's profile photo (4.1.1-I): rounded square, orange camera badge.
  Widget _imagePreview() {
    final path = widget.imagePath;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 200,
              height: 200,
              color: context.colors.field,
              child: path == null
                  ? null
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      semanticLabel: 'Your new profile photo',
                    ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: -8,
            child: IconButton.filled(
              tooltip: 'Choose another photo',
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.uploadPhoto),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange,
                side: BorderSide(color: context.colors.background, width: 3),
              ),
              icon: const ImageIcon(
                AppIcons.camera,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
