import 'package:flutter/material.dart';
import 'package:paw_match/core/app_theme.dart';
import 'package:paw_match/screens/welcome_screen.dart';

void main() {
  runApp(const PawMatchApp());
}

class PawMatchApp extends StatelessWidget {
  const PawMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paw Match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const WelcomeScreen(),
    );
  }
}
