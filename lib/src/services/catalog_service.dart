import 'package:flutter/foundation.dart';
import 'package:food_ninja/src/services/auth_service.dart';
import 'package:food_ninja/src/utils/network_error.dart';
import 'package:http/http.dart' as http;

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
    );
  }

  final String id;
  final String name;
  final String? photoUrl;
  final double rating;
  final int? deliveryTimeMins;
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
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>?;
    return MenuItem(
      id: json['_id'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String?,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      restaurantId: (restaurant?['_id'] ?? json['restaurantId']) as String?,
      restaurantName: restaurant?['name'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;
  final String? photoUrl;
  final double price;
  final String? category;
  final int orderCount;
  final String? restaurantId;
  final String? restaurantName;
  final double? distanceKm;
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

  /// Restaurants nearest first, each with its distance from [lat], [lng].
  Future<List<Restaurant>> restaurants({
    required double lat,
    required double lng,
    String? search,
    double? maxKm,
  }) async {
    final items = await _list('restaurants', {
      'lat': '$lat',
      'lng': '$lng',
      'limit': '$maxPage',
      if (search != null && search.isNotEmpty) 'search': search,
      if (maxKm != null) 'maxKm': '$maxKm',
    });
    return items.map(Restaurant.fromJson).toList();
  }

  /// Menu items, most ordered first unless [sort] says otherwise.
  Future<List<MenuItem>> menuItems({
    required double lat,
    required double lng,
    String? search,
    double? maxKm,
    String sort = 'popular',
  }) async {
    final items = await _list('menu-items', {
      'lat': '$lat',
      'lng': '$lng',
      'limit': '$maxPage',
      'sort': sort,
      if (search != null && search.isNotEmpty) 'search': search,
      if (maxKm != null) 'maxKm': '$maxKm',
    });
    return items.map(MenuItem.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> _list(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse('$_baseUrl/$path').replace(queryParameters: query);
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
    final data = body['data'];
    if (response.statusCode == 200 && data is Map<String, dynamic>) {
      return [...?(data['items'] as List?)?.cast<Map<String, dynamic>>()];
    }
    throw Exception(
      (body['message'] as String?) ?? "Couldn't load $path. Please try again.",
    );
  }
}
