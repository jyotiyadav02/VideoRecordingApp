import 'package:flutter/material.dart';

class VideoModel {
  String path;
  int likes;
  bool isLiked; // Added property
  late DateTime timestamp;
  late String id; // Unique identifier

  VideoModel({required this.path, this.likes = 0, this.isLiked = false}) {
    timestamp = DateTime.now();
    id = UniqueKey().toString(); // Unique identifier initialization
  }
}
