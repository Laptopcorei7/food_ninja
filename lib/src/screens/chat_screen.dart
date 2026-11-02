import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/screens/orders_screen.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/utils/api_url.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';
import 'package:image_picker/image_picker.dart';

/// Kit 9.5-B: the support chat with the bot (and later staff), or the chat
/// with one order's rider. New messages are fetched every [every].
class ChatScreen extends StatefulWidget {
  const ChatScreen.support({super.key})
      : orderId = null,
        riderName = null;

  const ChatScreen.rider({
    required String this.orderId,
    this.riderName,
    super.key,
  });

  /// Set for a rider chat.
  final String? orderId;
  final String? riderName;

  static const every = Duration(seconds: 3);

  /// Picks a photo from the gallery, which needs no permission (unlike the
  /// camera, whose app Android may kill this one behind). Tests swap it.
  @visibleForTesting
  static Future<String?> Function() pickPhoto = () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return file?.path;
  };

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _catalog = CatalogService();
  final _text = TextEditingController();
  Chat? _chat;
  final _messages = <ChatMessage>[];
  String? _error;
  bool _sending = false;
  bool _polling = false;
  Timer? _timer;

  bool get _rider => widget.orderId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final chat = await (_rider
          ? _catalog.riderChat(widget.orderId!)
          : _catalog.supportChat());
      if (!mounted) return;
      setState(() {
        _chat = chat;
        _messages
          ..clear()
          ..addAll(chat.messages);
      });
      _timer?.cancel();
      _timer = Timer.periodic(ChatScreen.every, (_) => _poll());
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Chat] load failed: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _poll() async {
    final chat = _chat;
    if (chat == null || _polling) return;
    _polling = true;
    try {
      final after = _messages.lastOrNull?.at ?? DateTime(2000);
      _add(await _catalog.newMessages(chat.id, after));
    } on SessionExpiredException {
      _timer?.cancel();
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      // The next poll may work; what is on screen stays.
      debugPrint('[Chat] poll failed: $e');
    } finally {
      _polling = false;
    }
  }

  /// Adds messages not on screen yet: a poll can return one a send
  /// already added.
  void _add(List<ChatMessage> messages) {
    if (!mounted) return;
    final have = {for (final m in _messages) m.id};
    final fresh = messages.where((m) => have.add(m.id)).toList();
    if (fresh.isNotEmpty) setState(() => _messages.addAll(fresh));
  }

  Future<bool> _send({String? text, String? option}) =>
      _run(() => _catalog.sendMessage(_chat!.id, text: text, option: option));

  Future<void> _sendText() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    if (await _send(text: text)) _text.clear();
  }

  Future<void> _sendPhoto() async {
    final String? path;
    try {
      path = await ChatScreen.pickPhoto();
    } on Exception catch (e) {
      debugPrint('[Chat] photo pick failed: $e');
      _say("Couldn't open your photos.");
      return;
    }
    if (path == null) return;
    await _run(() => _catalog.sendPhoto(_chat!.id, path!));
  }

  /// Sends one message; true when it went through.
  Future<bool> _run(Future<List<ChatMessage>> Function() send) async {
    if (_sending || _chat == null) return false;
    setState(() => _sending = true);
    try {
      _add(await send());
      return true;
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Chat] send failed: $e');
      _say(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    return false;
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(persist: false, content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _rider ? (widget.riderName ?? 'Your rider') : 'Support',
      child: _chat == null ? _status(context) : _thread(context),
    );
  }

  Widget _status(BuildContext context) {
    if (_error == null) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
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
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _thread(BuildContext context) {
    final colors = context.colors;
    // Only the newest bot message's buttons are live; older ones answered
    // a question that has moved on.
    final lastOptions = _messages.lastWhereOrNull((m) => m.options.isNotEmpty);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Send ${widget.riderName ?? 'your rider'} a message '
                      'about this order.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, color: colors.textSecondary),
                    ),
                  ),
                )
              // Reversed so the newest message sits at the bottom and new
              // ones appear without scrolling.
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[_messages.length - 1 - i];
                    return _Bubble(
                      message: m,
                      onOption: identical(m, lastOptions) && !_sending
                          ? (o) => _send(option: o.value)
                          : null,
                    );
                  },
                ),
        ),
        _Composer(
          controller: _text,
          sending: _sending,
          onSend: _sendText,
          onPhoto: _sendPhoto,
        ),
      ],
    );
  }
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}

/// One message: the user's on the right in cream, the others on the left
/// outlined in orange, each with its time below.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onOption});

  final ChatMessage message;

  /// Null when the buttons are spent.
  final ValueChanged<ChatOption>? onOption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = message;
    final text = TextStyle(fontSize: 17, height: 1.25, color: colors.textBody);
    final bold = text.copyWith(fontWeight: FontWeight.w600);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(m.at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    const r = Radius.circular(20);
    final image = mediaUrl(m.imageUrl);
    final width = MediaQuery.sizeOf(context).width * 0.72;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (m.from == 'staff')
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'YumQuick team',
                style: TextStyle(fontSize: 14, color: colors.accentText),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: m.mine ? colors.field : colors.background,
                border: m.mine
                    ? null
                    : Border.all(color: AppColors.orange, width: 1.5),
                borderRadius: m.mine
                    ? const BorderRadius.only(
                        topLeft: r,
                        topRight: r,
                        bottomLeft: r,
                      )
                    : const BorderRadius.only(
                        topLeft: r,
                        topRight: r,
                        bottomRight: r,
                      ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (image != null)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: m.text == null ? 0 : 8,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            image,
                            width: width - 36,
                            fit: BoxFit.cover,
                            // Decode at the shown size, not the photo's.
                            cacheWidth: ((width - 36) *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                            semanticLabel: 'Photo',
                            errorBuilder: (_, __, ___) => Text(
                              'Photo unavailable',
                              style: text.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (m.text case final t?) Text(t, style: text),
                    if (m.order case final o?) ...[
                      const SizedBox(height: 4),
                      Text(o.items, style: text),
                      Text('Order No. ${o.number}', style: bold),
                      if (o.at case final at?)
                        Text(formatOrderTime(context, at), style: bold),
                    ],
                    if (m.options.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in m.options)
                            _OptionPill(
                              label: o.label,
                              onTap: onOption == null
                                  ? null
                                  : () => onOption!(o),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              time,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.soft,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: onTap == null ? colors.textSecondary : colors.accentText,
            ),
          ),
        ),
      ),
    );
  }
}

/// The kit's peach bar: photo, text field, send.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPhoto,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget round(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          onPressed: sending ? null : onTap,
          style: IconButton.styleFrom(backgroundColor: colors.surface),
          icon: Icon(icon, color: AppColors.orange),
        );
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return ColoredBox(
      color: colors.soft,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              round(Icons.attach_file_rounded, 'Send a photo', onPhoto),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Write here…',
                    counterText: '',
                    fillColor: colors.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: shape,
                    enabledBorder: shape,
                    focusedBorder: shape,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              round(Icons.send_rounded, 'Send', onSend),
            ],
          ),
        ),
      ),
    );
  }
}
