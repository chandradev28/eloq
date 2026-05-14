import 'package:flutter/material.dart';

class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.prompt,
    required this.difficulty,
  });

  final String id;
  final String name;
  final IconData icon;
  final String description;
  final String prompt;
  final String difficulty;
}
