import 'package:flutter/material.dart';
import 'package:sie_camera_hand_cursor/ui/spike_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SieSpikeApp());
}

class SieSpikeApp extends StatelessWidget {
  const SieSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIE Camera Hand Cursor Spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0891B2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SpikeHomeScreen(),
    );
  }
}
