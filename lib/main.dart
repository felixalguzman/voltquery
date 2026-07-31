import 'package:flutter/material.dart';

// Scaffold only. App architecture (shell, theming, DB layer) is pending
// the /wayfinder planning pass — see docs/UI_STACK.md for the locked stack
// and the decision tickets to resolve before building.
void main() => runApp(const VoltQueryApp());

class VoltQueryApp extends StatelessWidget {
  const VoltQueryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoltQuery',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(child: Text('VoltQuery — scaffold. Run /wayfinder to chart the build.')),
      ),
    );
  }
}
