import 'package:flutter/material.dart';

/// Shows a full-screen semi-transparent overlay with a centred green spinner.
/// The caller dismisses it with Navigator.of(context).pop() when ready.
Future<void> showLoadingOverlay(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => const Center(
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF53E88B)),
      ),
    ),
  );
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.imagePath,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryIsDestructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? imagePath;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryIsDestructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null) ...[
              Image.asset(imagePath!, height: 90),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'BentonSansBold',
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'BentonSansBook',
                fontSize: 13,
                color: Color(0xFF9D9D9D),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: primaryLabel,
              onTap: onPrimary,
              isDestructive: primaryIsDestructive,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontFamily: 'BentonSansMedium',
                    fontSize: 13,
                    color: Color(0xFF9D9D9D),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.isDestructive,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isDestructive
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF53E88B), Color(0xFF15BE77)],
                ),
          color: isDestructive ? const Color(0xFFE53935) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'BentonSansBold',
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
