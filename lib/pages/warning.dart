import 'package:flutter/material.dart';

class WarningPage extends StatefulWidget {
  const WarningPage({super.key});

  @override
  _WarningPageState createState() => _WarningPageState();
}

class _WarningPageState extends State<WarningPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black, // Set background color to black
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/error.png',
                width: 350,
                height: 300,
              ),
              const SizedBox(height: 20),
              Text(
                'غير مسموح',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
