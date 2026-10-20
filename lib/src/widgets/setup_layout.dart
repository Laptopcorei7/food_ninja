import 'package:flutter/material.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// The kit's form page (2-D Set Password): header title, a line of text,
/// the form, and the button at the bottom of the sheet. Used by the sign-up
/// setup steps and forgot password.
class SetupLayout extends StatelessWidget {
  const SetupLayout({
    required this.title,
    required this.children,
    this.intro,
    this.buttonLabel = 'Next',
    this.onButton,
    this.onBack,
    super.key,
  });

  final String title;
  final String? intro;
  final List<Widget> children;
  final String buttonLabel;

  /// Null hides the button (the screen has its own actions).
  final VoidCallback? onButton;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: title,
      onBack: onBack,
      // Scrolls only when the content does not fit (keyboard open);
      // otherwise the button stays at the bottom.
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (intro != null) ...[
                    Text(intro!, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                  ],
                  ...children,
                  if (onButton != null) ...[
                    const Spacer(),
                    const SizedBox(height: 24),
                    Center(
                      child: SizedBox(
                        width: 210,
                        child: MajorButton(
                          horizontal: 16,
                          vertical: 10,
                          textonButton: buttonLabel,
                          onPress: onButton,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label above any input, matching AuthTextField's.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
