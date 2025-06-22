import 'package:flutter/material.dart';
import 'package:trailblaze_app/screens/welcome_screen.dart'; // Import your welcome screen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrailBlaze App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WelcomeScreen(), // Set WelcomeScreen as the initial screen
    );
  }
}