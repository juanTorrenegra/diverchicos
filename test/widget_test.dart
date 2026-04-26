// Basic smoke test: app builds and embeds the Flame [GameWidget].

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diverchicos/main.dart';

void main() {
  testWidgets('Diverchicos app loads GameWidget', (WidgetTester tester) async {
    await tester.pumpWidget(const DiverchicosApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(GameWidget), findsOneWidget);
  });
}
