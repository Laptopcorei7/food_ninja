import 'package:flutter/foundation.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:http/http.dart' as http;

/// Riders deliver up to this far; lists never show anything further.
const deliveryRangeKm = 12.0;

/// Food category slugs the server accepts, with their labels.
const foodCategories = {
  'rice': 'Rice dishes',
  'soups-stews': 'Soups & stews',
  'grills': 'Grills',
  'pizza-burgers': 'Pizza & burgers',
  'snacks': 'Snacks',
  'desserts': 'Desserts',
  'drinks': 'Drinks',
};

@immutable
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.deliveryTimeMins,
    required this.categories,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    this.address,
    this.description,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // GeoJSON order: [lng, lat].
    final coordinates =
        (json['location'] as Map<String, dynamic>?)?['coordinates'] as List?;
    return Restaurant(
      id: json['_id'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      deliveryTimeMins: (json['deliveryTimeMins'] as num?)?.toInt(),
      categories: [...?(json['categories'] as List?)?.cast<String>()],
      lat: (coordinates?[1] as num?)?.toDouble(),
      lng: (coordinates?[0] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      address: json['address'] as String?,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String name;
  final String? photoUrl;
  final double rating;
  final int? deliveryTimeMins;
  final String? address;
  final String? description;
  final List<String> categories;
  final double? lat;
  final double? lng;

  /// Null when the request had no lat/lng.
  final double? distanceKm;
}

@immutable
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.price,
    required this.category,
    required this.orderCount,
    required this.restaurantId,
    required this.restaurantName,
    required this.distanceKm,
    this.rating = 0,
    this.description,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Lists embed {_id, name}; a restaurant's own menu has only the id.
    final restaurant = json['restaurant'];
    return MenuItem(
      id: json['_id'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String?,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      restaurantId: restaurant is Map<String, dynamic>
          ? restaurant['_id'] as String?
          : json['restaurantId'] as String?,
      restaurantName: restaurant is Map<String, dynamic>
          ? restaurant['name'] as String?
          : null,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String name;
  final String? photoUrl;
  final double price;
  final double rating;
  final String? description;
  final String? category;
  final int orderCount;
  final String? restaurantId;
  final String? restaurantName;
  final double? distanceKm;
}

/// An offer for Home's banner. [discountAmount] is a flat GH₵ amount.
@immutable
class Voucher {
  const Voucher({
    required this.id,
    required this.title,
    required this.description,
    required this.discountAmount,
    required this.photoUrl,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
        id: json['_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
        photoUrl: json['photoUrl'] as String?,
      );

  final String id;
  final String title;
  final String? description;
  final double discountAmount;
  final String? photoUrl;
}

/// What the Menu tab shows, set by its category strip and the Filter screen.
@immutable
class MenuFilter {
  const MenuFilter({
    this.category,
    this.sort = 'popular',
    this.minRating,
    this.maxPrice,
    this.maxKm,
  });

  /// A [foodCategories] key; null is every category.
  final String? category;

  /// 'popular', 'rating' or 'distance'.
  final String sort;
  final int? minRating;
  final double? maxPrice;

  /// Null is the whole [deliveryRangeKm].
  final double? maxKm;

  MenuFilter copyWith({
    String? Function()? category,
    String? sort,
    int? Function()? minRating,
    double? Function()? maxPrice,
    double? Function()? maxKm,
  }) =>
      MenuFilter(
        category: category == null ? this.category : category(),
        sort: sort ?? this.sort,
        minRating: minRating == null ? this.minRating : minRating(),
        maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
        maxKm: maxKm == null ? this.maxKm : maxKm(),
      );

  /// How many filters beyond the category are on, for the filter badge.
  int get extraCount => [minRating, maxPrice, maxKm].nonNulls.length;

  @override
  bool operator ==(Object other) =>
      other is MenuFilter &&
      other.category == category &&
      other.sort == sort &&
      other.minRating == minRating &&
      other.maxPrice == maxPrice &&
      other.maxKm == maxKm;

  @override
  int get hashCode => Object.hash(category, sort, minRating, maxPrice, maxKm);
}

/// "GH₵ 50", or "GH₵ 12.50" when there are pesewas.
String formatCedis(double amount) => amount == amount.roundToDouble()
    ? 'GH₵ ${amount.toInt()}'
    : 'GH₵ ${amount.toStringAsFixed(2)}';

/// "0.9 km"
String formatKm(double km) =>
    '${km == km.roundToDouble() ? km.toInt() : km.toStringAsFixed(1)} km';

/// Restaurants and menu items. Lists come back as
/// `{ success, data: { items, page, totalPages, total } }`.
class CatalogService {
  static const _devHost =
      String.fromEnvironment('DEV_HOST', defaultValue: '10.0.2.2');
  static const _baseUrl = 'http://$_devHost:5000/api/v1';

  /// The server caps a page at 50.
  static const maxPage = 50;

  /// Restaurants within [deliveryRangeKm] (or [maxKm]), nearest first unless
  /// [sort] says otherwise, each with its distance from [lat], [lng].
  Future<List<Restaurant>> restaurants({
    required double lat,
    required double lng,
    String? search,
    double? maxKm,
    String? sort,
    int limit = maxPage,
  }) async {
    final data = await _get('restaurants', {
      'lat': '$lat',
      'lng': '$lng',
      'limit': '$limit',
      'maxKm': '${maxKm ?? deliveryRangeKm}',
      if (sort != null) 'sort': sort,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _items(data).map(Restaurant.fromJson).toList();
  }

  /// Dishes within [deliveryRangeKm], most ordered first unless [filter]
  /// sorts otherwise.
  Future<List<MenuItem>> menuItems({
    required double lat,
    required double lng,
    MenuFilter filter = const MenuFilter(),
    String? search,
    int limit = maxPage,
  }) async {
    final data = await _get('menu-items', {
      'lat': '$lat',
      'lng': '$lng',
      'limit': '$limit',
      'sort': filter.sort,
      'maxKm': '${filter.maxKm ?? deliveryRangeKm}',
      if (filter.category != null) 'category': filter.category!,
      if (filter.minRating != null) 'minRating': '${filter.minRating}',
      if (filter.maxPrice != null) 'maxPrice': '${filter.maxPrice}',
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return _items(data).map(MenuItem.fromJson).toList();
  }

  /// Dishes picked for this user from what they order; top-rated dishes
  /// near them until they have orders.
  Future<List<MenuItem>> forYou({
    required double lat,
    required double lng,
    int limit = 10,
  }) async {
    final data = await _get('menu-items/for-you', {
      'lat': '$lat',
      'lng': '$lng',
      'limit': '$limit',
    });
    return _items(data).map(MenuItem.fromJson).toList();
  }

  /// Cheapest and dearest dish matching [filter] (its maxPrice ignored), for
  /// the Filter screen's price slider. Null when nothing matches.
  Future<(double, double)?> priceRange({
    required double lat,
    required double lng,
    MenuFilter filter = const MenuFilter(),
  }) async {
    final data = await _get('menu-items', {
      'lat': '$lat',
      'lng': '$lng',
      'limit': '1',
      'maxKm': '${filter.maxKm ?? deliveryRangeKm}',
      if (filter.category != null) 'category': filter.category!,
      if (filter.minRating != null) 'minRating': '${filter.minRating}',
    });
    final range = data is Map<String, dynamic> ? data['priceRange'] : null;
    if (range is! Map<String, dynamic>) return null;
    final min = (range['min'] as num?)?.toDouble();
    final max = (range['max'] as num?)?.toDouble();
    return min == null || max == null ? null : (min, max);
  }

  /// One restaurant, with its distance when [lat], [lng] are given.
  Future<Restaurant> restaurant(String id, {double? lat, double? lng}) async {
    final data = await _get('restaurants/$id', {
      if (lat != null && lng != null) ...{'lat': '$lat', 'lng': '$lng'},
    });
    if (data is! Map<String, dynamic>) throw _unexpected('restaurant');
    return Restaurant.fromJson(data);
  }

  /// Every dish a restaurant sells.
  Future<List<MenuItem>> restaurantMenu(String id) async {
    final data = await _get('restaurants/$id/menu', {'limit': '100'});
    if (data is! List) throw _unexpected('menu');
    return data.cast<Map<String, dynamic>>().map(MenuItem.fromJson).toList();
  }

  /// Offers that are on now.
  Future<List<Voucher>> vouchers() async {
    final data = await _get('vouchers', {});
    final list = data is List ? data : _items(data);
    return list.cast<Map<String, dynamic>>().map(Voucher.fromJson).toList();
  }

  List<Map<String, dynamic>> _items(Object? data) {
    if (data is Map<String, dynamic>) {
      return [...?(data['items'] as List?)?.cast<Map<String, dynamic>>()];
    }
    throw _unexpected('list');
  }

  Exception _unexpected(String what) =>
      Exception("Couldn't load the $what. Please try again.");

  /// GETs [path] and returns the body's `data`.
  Future<Object?> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('$_baseUrl/$path')
        .replace(queryParameters: query.isEmpty ? null : query);
    if (kDebugMode) debugPrint('[CatalogService] GET $uri');
    final token = await AuthService().getToken();
    if (token == null) throw SessionExpiredException();

    final http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw toUserError(e);
    }

    if (response.statusCode == 401) throw SessionExpiredException();
    final body = decodeBody(response);
    if (response.statusCode == 200) return body['data'];
    throw Exception(
      (body['message'] as String?) ?? "Couldn't load $path. Please try again.",
    );
  }
}
