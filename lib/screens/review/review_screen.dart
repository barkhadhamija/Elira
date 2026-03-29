import 'package:flutter/material.dart';
import '../../theme/app_colours.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: Center(
        child: Text(
          'Review Screen — Coming Day 3',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
