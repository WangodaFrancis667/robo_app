import 'package:flutter/material.dart';
import 'package:robo_app/screens/Dashboard/main_dashboard.dart';
import 'package:robo_app/utils/colors.dart';

void main() {
  runApp(const WeedingRobotApp());
}

class WeedingRobotApp extends StatelessWidget {
  const WeedingRobotApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Weeding Robot',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      ),
      home: MainDashboard(),
    );
  }
}
