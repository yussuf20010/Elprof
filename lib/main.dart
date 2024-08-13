import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_android_developer_mode/flutter_android_developer_mode.dart';
import 'package:elprof/pages/warning.dart';
import 'package:root_checker_plus/root_checker_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:elprof/pages/splash.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDkcqIk-Fl96sGDtrqtVU1xbAIUyTq0KWg',
      appId: '1:562410516751:android:ec0c92bfce9a110c510e7a',
      messagingSenderId: '562410516751',
      projectId: 'marwa-911fd',
      storageBucket: 'marwa-911fd.appspot.com',
    ),
  );
  await initializeApp();
  }

Future<void> initializeApp() async {
  await screenRestrictions();
  bool isEmulator = await checkIfEmulator();
  bool isDeveloperModeEnabled = await checkIfDeveloperModeEnabled();
  bool isRooted = await checkIfRooted();
  String currentVersion = await getAppVersion();
  const String minRequiredVersion = '1.0.0';
  bool isVersionValid = isVersionSupported(currentVersion, minRequiredVersion);

  runApp(MyApp(
    isEmulator: isEmulator,
    isDeveloperModeEnabled: isDeveloperModeEnabled,
    isRooted: isRooted,
    isVersionValid: isVersionValid,
  ));
}

Future<void> screenRestrictions() async {
  await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
}

Future<bool> checkIfEmulator() async {
  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return !androidInfo.isPhysicalDevice;
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return !iosInfo.isPhysicalDevice;
  }
  return false;
}

Future<bool> checkIfDeveloperModeEnabled() async {
  try {
    return await FlutterAndroidDeveloperMode.isAndroidDeveloperModeEnabled;
  } catch (e) {
    return false;
  }
}

Future<bool> checkIfRooted() async {
  if (Platform.isAndroid) {
    return await _checkAndroidRooted();
  } else {
    return false;
  }
}

Future<bool> _checkAndroidRooted() async {
  try {
    bool isRooted = (await RootCheckerPlus.isRootChecker())!;
    bool isDevMode = (await RootCheckerPlus.isDeveloperMode())!;
    return isRooted || isDevMode;
  } catch (e) {
    return false;
  }
}

Future<String> getAppVersion() async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  return info.version;
}

bool isVersionSupported(String currentVersion, String minRequiredVersion) {
  return currentVersion.compareTo(minRequiredVersion) >= 0;
}

class MyApp extends StatelessWidget {
  final bool isEmulator;
  final bool isDeveloperModeEnabled;
  final bool isRooted;
  final bool isVersionValid;

  const MyApp({
    Key? key,
    required this.isEmulator,
    required this.isDeveloperModeEnabled,
    required this.isRooted,
    required this.isVersionValid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITalent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: _getHomePage(),
    );
  }

  Widget _getHomePage() {
    if (isEmulator || isDeveloperModeEnabled || isRooted || !isVersionValid) {
      return WarningPage(); // Show WarningPage for invalid conditions
    } else {
      return SplashScreen();
    }
  }
}
