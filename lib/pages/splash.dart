import 'package:elprof/pages/login.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Offset _splashOffset = const Offset(0, 0);
  Offset _progressBarOffset = const Offset(0, 0);
  Offset _smallLogoOffset = const Offset(0, 0);

  @override
  void initState() {
    super.initState();
    // Add a delay of 2 seconds before navigating to the WebPage
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _splashOffset += details.delta;
                });
              },
              child: Center(
                child: Transform.translate(
                  offset: _splashOffset,
                  child: Image.asset(
                    'assets/splash.png',
                    height: 120,
                    width: 300,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 550,
              left: MediaQuery.of(context).size.width / 2 - 100,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _progressBarOffset += details.delta;
                  });
                },
                child: Transform.translate(
                  offset: _progressBarOffset,
                  child: SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      color: Color(0xFF672c7b),
                      backgroundColor: Colors.grey.withOpacity(0.5),
                      value: null,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 200,
              left: 110,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _smallLogoOffset += details.delta;
                  });
                },
                child: Transform.translate(
                  offset: _smallLogoOffset,
                  child: Image.asset(
                    'assets/small.png',
                    height: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
