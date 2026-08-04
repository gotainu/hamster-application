import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/widgets/shine_border.dart';

void main() {
  testWidgets('AnimatedShiningBorder renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedShiningBorder(
            active: false,
            child: Text('記録する'),
          ),
        ),
      ),
    );

    expect(find.text('記録する'), findsOneWidget);
  });
}
