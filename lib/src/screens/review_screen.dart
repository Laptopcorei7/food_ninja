import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/theme/app_icons.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:food_ninja/src/utils/session.dart';
import 'package:food_ninja/src/widgets/food_photo.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

/// Kit 4.1.1-G: one page per dish (stars and a comment, or Skip), then one
/// for the restaurant, sent together. Pops true once sent.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({required this.order, this.restaurantRating, super.key});

  final PlacedOrder order;

  /// Stars already tapped on Order Delivered.
  final int? restaurantRating;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  /// One page per dish; the same dish in two portions is rated once.
  late final List<CartLine> _dishes = [
    for (final line in widget.order.lines)
      if (line.menuItemId != null) line,
  ].fold(<String, CartLine>{}, (byId, line) {
    byId.putIfAbsent(line.menuItemId!, () => line);
    return byId;
  }).values.toList();

  late final Map<String, TextEditingController> _comments = {
    for (final dish in _dishes) dish.menuItemId!: TextEditingController(),
  };
  final _restaurantComment = TextEditingController();
  final _stars = <String, int>{};
  late int? _restaurantStars = widget.restaurantRating;
  int _step = 0;
  bool _sending = false;

  bool get _onRestaurant => _step == _dishes.length;

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    _restaurantComment.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop(false);
    } else {
      setState(() => _step--);
    }
  }

  void _skip() {
    setState(() {
      _stars.remove(_dishes[_step].menuItemId);
      _step++;
    });
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await CatalogService().reviewOrder(
        widget.order.id,
        dishes: {
          for (final MapEntry(key: id, value: stars) in _stars.entries)
            id: (stars, _comments[id]!.text),
        },
        restaurantRating: _restaurantStars!,
        restaurantComment: _restaurantComment.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Thank you for your review!')),
        );
      Navigator.of(context).pop(true);
    } on SessionExpiredException {
      if (mounted) await signOutExpired(context);
    } on Exception catch (e) {
      debugPrint('[Review] failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: SheetScaffold(
        title: 'Leave a Review',
        onBack: _back,
        child: _onRestaurant ? _restaurantPage() : _dishPage(_dishes[_step]),
      ),
    );
  }

  Widget _dishPage(CartLine dish) {
    final id = dish.menuItemId!;
    final stars = _stars[id];
    return _Page(
      key: ValueKey(id),
      counter: 'Dish ${_step + 1} of ${_dishes.length}',
      image: FoodPhoto(url: dish.photoUrl),
      title: dish.name,
      question: 'We would love to know what you think of this dish.',
      stars: stars,
      onStars: (s) => setState(() => _stars[id] = s),
      comment: _comments[id]!,
      left: MajorButton(
        horizontal: 20,
        vertical: 10,
        tone: ButtonTone.soft,
        textonButton: 'Skip',
        onPress: _skip,
      ),
      right: MajorButton(
        horizontal: 20,
        vertical: 10,
        textonButton: 'Next',
        onPress: stars == null ? null : () => setState(() => _step++),
      ),
    );
  }

  Widget _restaurantPage() {
    return _Page(
      key: const ValueKey('restaurant'),
      counter: _dishes.isEmpty ? null : 'Last step',
      image: ColoredBox(
        color: context.colors.field,
        child: const Center(
          child: ImageIcon(AppIcons.utensils, size: 64, color: AppColors.orange),
        ),
      ),
      title: widget.order.restaurantName ?? 'The restaurant',
      question: 'How were the restaurant and the delivery?',
      stars: _restaurantStars,
      onStars: (s) => setState(() => _restaurantStars = s),
      comment: _restaurantComment,
      left: MajorButton(
        horizontal: 20,
        vertical: 10,
        tone: ButtonTone.soft,
        textonButton: 'Cancel',
        onPress: () => Navigator.of(context).pop(false),
      ),
      right: _sending
          ? const Center(child: CircularProgressIndicator())
          : MajorButton(
              horizontal: 20,
              vertical: 10,
              textonButton: 'Submit',
              onPress: _restaurantStars == null ? null : _submit,
            ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.counter,
    required this.image,
    required this.title,
    required this.question,
    required this.stars,
    required this.onStars,
    required this.comment,
    required this.left,
    required this.right,
    super.key,
  });

  final String? counter;
  final Widget image;
  final String title;
  final String question;
  final int? stars;
  final ValueChanged<int> onStars;
  final TextEditingController comment;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        if (counter case final c?)
          Text(
            c,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
        const SizedBox(height: 8),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox.square(dimension: 150, child: image),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          question,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, color: colors.textBody),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var s = 1; s <= 5; s++)
              IconButton(
                tooltip: '$s star${s == 1 ? '' : 's'}',
                isSelected: stars != null && s <= stars!,
                onPressed: () => onStars(s),
                icon: const Icon(Icons.star_outline_rounded),
                selectedIcon: const Icon(Icons.star_rounded),
                color: AppColors.orange,
                iconSize: 40,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Leave us a comment (optional)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, color: colors.textBody),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: comment,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Write your review...'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        ),
      ],
    );
  }
}
