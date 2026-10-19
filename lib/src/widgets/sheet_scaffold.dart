import 'package:flutter/material.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/custom_back_button.dart';

/// The kit's page shape: a yellow header with a back arrow and a centred
/// title, and a rounded sheet below it holding [child].
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    required this.child,
    this.title,
    this.subtitle,
    this.header,
    this.showBack = true,
    this.onBack,
    this.actions = const [],
    this.headerHeight = 96,
    this.bottomNavigationBar,
    super.key,
  });

  /// The sheet's content. It fills the sheet; scroll inside it if needed.
  final Widget child;
  final String? title;

  /// Orange line under the title ("How Can We Help You?").
  final String? subtitle;

  /// Replaces the title row, e.g. Home's search bar and greeting.
  final Widget? header;
  final bool showBack;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  /// Small buttons at the right of the title row.
  final List<Widget> actions;

  /// Height of the yellow band under the status bar.
  final double headerHeight;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: colors.header,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: headerHeight,
              child: header ??
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Room on both sides so the title stays centred.
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: actions.length > 1 ? 92 : 56,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: colors.onHeader,
                                ),
                              ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.accentText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (showBack && (onBack != null || canPop))
                        Positioned(
                          left: 8,
                          child: CustomBackButton(
                            onTap: onBack ??
                                () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      Positioned(
                        right: 16,
                        child: Row(children: actions),
                      ),
                    ],
                  ),
            ),
          ),
          Expanded(
            child: Material(
              color: colors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
