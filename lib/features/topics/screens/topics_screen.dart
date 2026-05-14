import 'package:flutter/material.dart';

import '../../home/widgets/topic_grid.dart';

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Topics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [TopicGrid()],
      ),
    );
  }
}
