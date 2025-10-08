import 'package:flutter/material.dart';

class Category {
  final int? id;
  final String name;
  final String type;
  final int colorValue;
  final int iconCodePoint;

  Category({
    this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    required this.iconCodePoint,
  });

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      colorValue: map['colorValue'],
      iconCodePoint: map['iconCodePoint'],
    );
  }
}
