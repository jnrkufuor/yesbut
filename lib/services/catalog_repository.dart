import 'dart:convert';

import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

class CatalogItem {
  final String id;
  final String name;
  final String kind;
  final String category;
  final String color; // red | blue | green
  final String url;
  final String brand; // "#RRGGBB" brand color for badges

  const CatalogItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.category,
    required this.color,
    required this.url,
    this.brand = '#232120',
  });

  Color get brandColor {
    final h = brand.replaceFirst('#', '');
    final v = int.tryParse(h, radix: 16);
    return v == null || h.length != 6 ? const Color(0xFF232120) : Color(0xFF000000 | v);
  }

  String get initial => name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        id: j['id'].toString(),
        name: j['name'].toString(),
        kind: (j['kind'] ?? 'Terms').toString(),
        category: (j['category'] ?? 'Other').toString(),
        color: (j['color'] ?? 'blue').toString(),
        url: j['url'].toString(),
        brand: (j['brand'] ?? '#232120').toString(),
      );
}

/// Library of well-known terms pages.
///
/// Loads the bundled `assets/catalog.json`. To scale, add a remote source
/// (e.g. your API or a CDN JSON) and merge it in [load].
class CatalogRepository {
  List<CatalogItem>? _items;

  Future<List<CatalogItem>> load() async {
    if (_items != null) return _items!;
    final raw = await rootBundle.loadString('assets/catalog.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _items = (data['items'] as List)
        .whereType<Map>()
        .map((m) => CatalogItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return _items!;
  }
}
