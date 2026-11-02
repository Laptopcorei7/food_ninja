import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/chat_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/open_link.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';
import 'package:food_ninja/src/widgets/tab_pills.dart';

/// Kit 9.5-A: the Help tab, leading to the support chat and the Help Center.
class HelpTab extends StatelessWidget {
  const HelpTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final divider = Divider(height: 1, color: colors.divider);
    void open(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    return SheetScaffold(
      title: 'Help',
      showBack: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          Text(
            'Something wrong with an order, a payment or your account? '
            'Chat with us, or find a quick answer in the Help Center.',
            style: TextStyle(fontSize: 16, color: colors.textBody),
          ),
          const SizedBox(height: 24),
          divider,
          _HelpRow(
            title: 'Help with an order',
            subtitle: 'Chat with support',
            onTap: () => open(const ChatScreen.support()),
          ),
          divider,
          _HelpRow(
            title: 'Help Center',
            subtitle: 'Questions and answers, contact details',
            onTap: () => open(const HelpCenterScreen()),
          ),
          divider,
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 16, color: colors.textBody),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}

/// Kit 9.5-C and 9.5-D: FAQs by category with a search, and the ways to
/// reach the team.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  static const categories = {
    'general': 'General',
    'account': 'Account',
    'services': 'Services',
  };

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  HelpInfo? _help;
  String? _error;
  String _view = 'faq';
  String _category = 'general';
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final help = await CatalogService().help();
      if (mounted) setState(() => _help = help);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Help] load failed: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final help = _help;
    return SheetScaffold(
      title: 'Help Center',
      subtitle: 'How can we help you?',
      child: help == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                TabPills(
                  tabs: const {'faq': 'FAQ', 'contact': 'Contact us'},
                  selected: _view,
                  onSelect: (v) => setState(() => _view = v),
                ),
                const SizedBox(height: 12),
                if (_view == 'faq')
                  ..._faqs(context, help.faqs)
                else
                  ..._contacts(context, help.contact),
              ],
            ),
    );
  }

  /// A search looks through every category; otherwise the chosen one.
  List<Widget> _faqs(BuildContext context, List<Faq> faqs) {
    final colors = context.colors;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final f in faqs)
        if (q.isEmpty
            ? f.category == _category
            : '${f.question} ${f.answer}'.toLowerCase().contains(q))
          f,
    ];
    return [
      TabPills(
        tabs: HelpCenterScreen.categories,
        selected: q.isEmpty ? _category : '',
        onSelect: (c) => setState(() => _category = c),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search',
            prefixIcon: const Icon(Icons.search_rounded),
            fillColor: colors.surface,
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No answers match. Try other words, or chat with support from '
            'the Help tab.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
        ),
      for (final f in shown) ...[
        Divider(height: 1, color: colors.divider),
        _Expandable(
          // A new search or category starts with every answer closed.
          key: ValueKey('${f.category}|${f.question}|$q'),
          title: f.question,
          children: [
            Text(
              f.answer,
              style: TextStyle(fontSize: 16, color: colors.textBody),
            ),
          ],
        ),
      ],
      if (shown.isNotEmpty) Divider(height: 1, color: colors.divider),
    ];
  }

  List<Widget> _contacts(BuildContext context, Map<String, String> c) {
    Widget link(String label, String? value, Uri? Function(String) uri) {
      if (value == null) return const SizedBox.shrink();
      final target = uri(value);
      return _LinkLine(
        label: label,
        value: value,
        onTap: target == null ? null : () => openLink(context, target),
      );
    }

    Uri? web(String v, String site) {
      if (v.startsWith('http')) return Uri.tryParse(v);
      final handle = v.replaceFirst('@', '');
      return Uri.tryParse(site.isEmpty ? 'https://$handle' : '$site$handle');
    }

    final rows = <(IconData, String, List<Widget>)>[
      if (c['phone'] != null || c['email'] != null)
        (
          Icons.headset_mic_outlined,
          'Customer service',
          [
            link('Call', c['phone'], (v) => Uri(scheme: 'tel', path: v)),
            link('Email', c['email'], (v) => Uri(scheme: 'mailto', path: v)),
          ],
        ),
      if (c['website'] case final v?)
        (Icons.language_rounded, 'Website', [link('Open', v, (v) => web(v, ''))]),
      if (c['whatsapp'] case final v?)
        (
          Icons.chat_outlined,
          'WhatsApp',
          [
            link(
              'Chat',
              v,
              (v) => v.startsWith('http')
                  ? Uri.tryParse(v)
                  : Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'\D'), '')}'),
            ),
          ],
        ),
      if (c['facebook'] case final v?)
        (
          Icons.facebook_outlined,
          'Facebook',
          [link('Open', v, (v) => web(v, 'https://facebook.com/'))],
        ),
      if (c['instagram'] case final v?)
        (
          Icons.camera_alt_outlined,
          'Instagram',
          [link('Open', v, (v) => web(v, 'https://instagram.com/'))],
        ),
    ];
    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Contact details are not available right now. Chat with '
            'support from the Help tab.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 16, color: context.colors.textSecondary),
          ),
        ),
      ];
    }
    return [
      for (final (icon, title, links) in rows)
        _Expandable(title: title, icon: icon, children: links),
    ];
  }
}

/// A kit row that opens to show more: orange title while closed, brown
/// once open.
class _Expandable extends StatelessWidget {
  const _Expandable({
    required this.title,
    required this.children,
    this.icon,
    super.key,
  });

  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: icon == null
          ? null
          : Icon(icon, size: 32, color: AppColors.orange),
      iconColor: AppColors.orange,
      collapsedIconColor: AppColors.orange,
      textColor: colors.textPrimary,
      collapsedTextColor: icon == null ? colors.accentText : colors.textPrimary,
      title: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      children: children,
    );
  }
}

/// "Call  +233 ..." under a contact row; tapping opens it.
class _LinkLine extends StatelessWidget {
  const _LinkLine({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: TextStyle(fontSize: 16, color: colors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, color: colors.accentText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
