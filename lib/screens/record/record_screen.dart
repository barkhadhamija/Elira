import 'package:flutter/material.dart';
import '../../theme/app_colours.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: Center(
        child: Text(
          'Record Screen — Coming Day 3',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
