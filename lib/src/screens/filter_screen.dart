import 'dart:async';

import 'package:flutter/material.dart';
import 'package:food_ninja/src/services/catalog_service.dart';
import 'package:food_ninja/src/services/location_service.dart';
import 'package:food_ninja/src/theme/app_colors.dart';
import 'package:food_ninja/src/widgets/category_strip.dart';
import 'package:food_ninja/src/widgets/major_button.dart';
import 'package:food_ninja/src/widgets/sheet_scaffold.dart';

class FilterArgs {
  const FilterArgs({required this.filter, required this.here});

  final MenuFilter filter;
  final Here here;
}

/// Distance choices; null is the whole delivery range.
const _distances = <double?>[2, 5, 10, null];

/// 4.4: category, minimum rating, distance and price. Pops the new
/// [MenuFilter] on Apply.
class FilterScreen extends StatefulWidget {
  const FilterScreen({required this.args, super.key});

  final FilterArgs args;

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late MenuFilter _f = widget.args.filter;

  /// The slider's ends, from the server, for the current choices.
  (double, double)? _range;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRange());
  }

  Future<void> _loadRange() async {
    final here = widget.args.here;
    try {
      final range = await CatalogService()
          .priceRange(lat: here.lat, lng: here.lng, filter: _f);
      if (mounted) setState(() => _range = range);
    } on Exception catch (e) {
      // The slider just stays hidden; the other filters still work.
      debugPrint('[Filter] price range failed: $e');
    }
  }

  void _set(MenuFilter f, {bool rangeChanges = false}) {
    setState(() => _f = f);
    if (rangeChanges) unawaited(_loadRange());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final heading = textTheme.titleLarge?.copyWith(color: colors.textPrimary);
    return SheetScaffold(
      title: 'Filter',
      actions: [
        TextButton(
          onPressed: () => _set(
            MenuFilter(sort: _f.sort),
            rangeChanges: true,
          ),
          style: TextButton.styleFrom(foregroundColor: colors.onHeader),
          child: const Text(
            'Reset',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.only(top: 24, bottom: 32),
        children: [
          _pad(Text('Categories', style: heading)),
          const SizedBox(height: 12),
          CategoryStrip(
            selected: _f.category,
            onSelected: (c) =>
                _set(_f.copyWith(category: () => c), rangeChanges: true),
          ),
          _divider(),
          _pad(
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top rated',
                    style: heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _f.minRating == null
                      ? 'Any rating'
                      : '${_f.minRating} and up',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _stars(),
          ),
          _divider(),
          _pad(Text('Distance', style: heading)),
          const SizedBox(height: 12),
          _pad(
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final km in _distances)
                  _Chip(
                    label: km == null ? 'Any' : 'Under ${formatKm(km)}',
                    selected: _f.maxKm == km,
                    onTap: () =>
                        _set(_f.copyWith(maxKm: () => km), rangeChanges: true),
                  ),
              ],
            ),
          ),
          if (_range case (final min, final max) when max > min) ...[
            _divider(),
            _pad(
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Price',
                      style: heading?.copyWith(color: colors.accentText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _f.maxPrice == null
                        ? 'Any price'
                        : 'Up to ${formatCedis(_f.maxPrice!)}',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
            _priceSlider(min, max),
          ],
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 210,
              child: MajorButton(
                horizontal: 0,
                vertical: 12,
                textonButton: 'Apply',
                onPress: () => Navigator.of(context).pop(_f),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pad(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: child,
      );

  Widget _divider() => const Divider(indent: 24, endIndent: 24, height: 40);

  /// Five stars; tapping the third keeps dishes rated 3 and up. Tapping the
  /// current one clears it.
  Widget _stars() {
    final min = _f.minRating;
    return Row(
      children: [
        for (var s = 1; s <= 5; s++)
          IconButton(
            tooltip: '$s star${s == 1 ? '' : 's'} and up',
            isSelected: min != null && s <= min,
            onPressed: () => _set(
              _f.copyWith(minRating: () => min == s ? null : s),
              rangeChanges: true,
            ),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.star_outline_rounded),
            selectedIcon: const Icon(Icons.star_rounded),
            color: AppColors.orange,
            iconSize: 28,
          ),
      ],
    );
  }

  /// The far right end means no price limit.
  Widget _priceSlider(double min, double max) {
    final value = (_f.maxPrice ?? max).clamp(min, max);
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: AppColors.orange,
        thumbColor: AppColors.orange,
        inactiveTrackColor: context.colors.divider,
        overlayColor: AppColors.orange.withValues(alpha: 0.12),
        valueIndicatorColor: AppColors.orange,
        trackHeight: 6,
      ),
      child: Slider(
        min: min,
        max: max,
        value: value,
        divisions: ((max - min) / 5).ceil().clamp(1, 100),
        label: value >= max ? 'Any' : formatCedis(value),
        semanticFormatterCallback: (v) =>
            v >= max ? 'Any price' : 'Up to ${formatCedis(v)}',
        onChanged: (v) => setState(
          () => _f = _f.copyWith(maxPrice: () => v >= max ? null : v),
        ),
      ),
    );
  }
}

/// The kit's peach pill chip; orange when selected.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.orange : colors.soft,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : colors.accentText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
