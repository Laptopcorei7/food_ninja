import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ninja/app/routes.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/widgets/app_dialog.dart';
import 'package:food_ninja/src/widgets/setup_layout.dart';
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
    return SetupLayout(
      title: 'Profile Photo',
      intro: 'Add a photo so riders know who to hand your order to.',
      children: [
        _SourceCard(
          icon: AppIcons.image,
          label: 'Choose from gallery',
          onTap: () => _pick(ImageSource.gallery),
        ),
        const SizedBox(height: 16),
        _SourceCard(
          icon: AppIcons.camera,
          label: 'Take a photo',
          onTap: () => _pick(ImageSource.camera),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AssetImage icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.soft,
                child: ImageIcon(icon, size: 28, color: AppColors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
