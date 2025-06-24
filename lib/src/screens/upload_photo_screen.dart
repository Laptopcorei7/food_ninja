import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/upload_preview_screen.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class UploadPhotoScreen extends StatefulWidget {
  const UploadPhotoScreen({super.key});

  @override
  State<UploadPhotoScreen> createState() => _UploadPhotoState();
}

class _UploadPhotoState extends State<UploadPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
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
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Upload Your Photo\nProfile',
                      style: TextStyle(
                        fontFamily: 'BentonSansBold',
                        fontSize: 25,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'This data will be displayed in your account\nprofile for security',
                      style: TextStyle(
                        fontFamily: 'BentonSansBook',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 30),

                    fromGallery(context),
                    const SizedBox(height: 30),
                    fromPhoto(context),
                    const SizedBox(height: 150),
                    const Center(
                      child: MajorButton(
                        horizontal: 60,
                        vertical: 20,
                        textonButton: 'Next',
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

  Widget fromGallery(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final status = await Permission.storage.request();

        if (status.isGranted) {
          final image = await _picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            if (!context.mounted) return; // Add this line
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => UploadPreviewScreen(imagePath: image.path),
              ),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
            style: TextStyle(
              fontFamily: 'BentonSansBold',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget fromPhoto(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final status = await Permission.camera.request();

        if (status.isGranted) {
          final image = await _picker.pickImage(source: ImageSource.camera);
          if (image != null) {
            if (!context.mounted) return; // Add this line
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => UploadPreviewScreen(imagePath: image.path),
              ),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
            style: TextStyle(
              fontFamily: 'BentonSansBold',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
