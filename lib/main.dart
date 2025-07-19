import 'package:flutter/material.dart';
import 'package:trailblaze_app/screens/welcome_screen.dart'; // Import your welcome screen
// import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg; // Temporariamente comentado

// Define a custom MaterialColor for the green theme
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrailBlaze App',
      theme: ThemeData(
        // Use the createMaterialColor function to generate a MaterialColor swatch
        primarySwatch: createMaterialColor(Color(0xFF4F695B)), // Use your desired green hex color
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WelcomeScreen(), // Set WelcomeScreen as the initial screen
    );
  }
}

/*
// Função temporariamente comentada devido ao plugin flutter_background_geolocation
void headlessTask(bg.HeadlessEvent headlessEvent) async {
  print(' headlessTask: $headlessEvent');
  // Implement your headless task logic here.
}
*/