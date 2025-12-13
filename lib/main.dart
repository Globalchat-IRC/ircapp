import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'screens/login_screen.dart';
import 'providers/theme_provider.dart';

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

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'Cliente IRC',
      theme: appTheme.toThemeData(),
      darkTheme: appTheme.toDarkThemeData(),
      themeMode: ThemeMode.light,
      home: const LoginScreen(),
    );
  }
}
