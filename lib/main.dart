import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'screens/login_screen.dart';

final logFile = File('/tmp/irc_app.log');

void globalLog(String message) {
  final timestamp = DateTime.now().toString();
  final logMessage = '[$timestamp] $message\n';
  print(logMessage);
  try {
    logFile.writeAsStringSync(logMessage, mode: FileMode.append);
  } catch (e) {
    // Ignore write errors
  }
}

void main() {
  // Clear log file at start
  try {
    logFile.deleteSync();
  } catch (e) {
    // File doesn't exist yet
  }
  
  globalLog('========== APP STARTED ==========');
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cliente IRC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.deepPurpleAccent,
        ),
      ),
      themeMode: ThemeMode.light,
      home: const LoginScreen(),
    );
  }
}
