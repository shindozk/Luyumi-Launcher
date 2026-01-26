import 'package:flutter/material.dart';

class NewsItem {
  final String title;
  final String date;
  final String description;
  final String imageUrl;
  final String url;
  final String tag;

  NewsItem({
    required this.title,
    required this.date,
    required this.description,
    required this.imageUrl,
    required this.url,
    required this.tag,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? 'No Title',
      date: json['date'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      url: json['url'] ?? '',
      tag: json['tag'] ?? 'News',
    );
  }

  Color get color {
    switch (tag.toLowerCase()) {
      case 'update':
        return Colors.blue;
      case 'event':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'community':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }
}
