import 'package:flutter/material.dart';

/// Entry point. Intentionally minimal — no real UI is built until Phase 2
/// of ARCHITECTURE.md, once Phase 1 (services) is fully green.
void main() {
  runApp(const MathBlitzApp());
}

class MathBlitzApp extends StatelessWidget {
  const MathBlitzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MathBlitz',
      home: Scaffold(
        body: Center(child: Text('MathBlitz — under construction')),
      ),
    );
  }
}
