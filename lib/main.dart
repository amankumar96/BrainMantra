import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

/// Entry point. Phase 2 is now wired up: the app launches straight into
/// HomeScreen instead of the earlier "under construction" placeholder.
void main() {
  runApp(const MathBlitzApp());
}

class MathBlitzApp extends StatelessWidget {
  const MathBlitzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MathBlitz',
      home: HomeScreen(),
    );
  }
}
