import 'dart:io';
import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/upload_photo_screen.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';
import 'package:food_ninja/src/widgets/major_button.dart';

class UploadPreviewScreen extends StatefulWidget {
  const UploadPreviewScreen({super.key, this.imagePath});
  final String? imagePath;

  @override
  State<UploadPreviewScreen> createState() => _UploadPreviewState();
}

class _UploadPreviewState extends State<UploadPreviewScreen> {
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
                    imagePreview(),
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

  Widget imagePreview() {
    return Center(
      child: Stack(
        alignment: Alignment.topRight, // Align X button to the top right
        children: [
          // Image preview box
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              image: DecorationImage(
                image: FileImage(File(widget.imagePath!)),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // X button positioned at the top right of the container
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const UploadPhotoScreen(),
                  ),
                );
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
