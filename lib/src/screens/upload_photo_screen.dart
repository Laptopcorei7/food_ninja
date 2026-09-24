import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/setup_pattern.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class UploadPhotoScreen extends StatefulWidget {
  const UploadPhotoScreen({super.key, this.recoveredImagePath});

  /// A photo taken before Android closed the app during the camera step
  /// (see app.dart); the preview opens straight away.
  final String? recoveredImagePath;

  @override
  State<UploadPhotoScreen> createState() => _UploadPhotoState();
}

class _UploadPhotoState extends State<UploadPhotoScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final recovered = widget.recoveredImagePath;
    if (recovered != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.uploadPreview,
          arguments: recovered,
        );
      });
    }
  }

  Future<void> _pick(ImageSource source) async {
    // The gallery opens Android's photo picker, which needs no permission.
    // The camera does, because the manifest declares CAMERA.
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AppDialog(
            title: 'Camera Access Needed',
            message:
                'Allow camera access in Settings to take a photo, or choose one from your gallery.',
            primaryLabel: 'Open Settings',
            onPrimary: () {
              Navigator.of(ctx).pop();
              unawaited(openAppSettings());
            },
            secondaryLabel: 'Not Now',
            onSecondary: () => Navigator.of(ctx).pop(),
          ),
        );
        return;
      }
    }

    final XFile? image;
    try {
      // A resized JPEG stays well under the server's 5 MB limit.
      image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      debugPrint('[UploadPhoto] pickImage failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open that. Please try again.")),
      );
      return;
    }
    if (image == null || !mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.uploadPreview,
      arguments: image.path,
    );
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
                        // maybePop: after a recovered restart there is no
                        // earlier screen to return to.
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
                    _fromGallery(context),
                    const SizedBox(height: 30),
                    _fromCamera(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fromGallery(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _pick(ImageSource.gallery),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/gallery.png',
            height: 50,
            width: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          const Text(
            'From Gallery',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _fromCamera(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _pick(ImageSource.camera),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/camera.png',
            height: 50,
            width: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          const Text(
            'Take Photo',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
