import 'package:flutter_test/flutter_test.dart';

import 'package:galaxy_image_viewer/main.dart';

void main() {
  testWidgets('App starts with correct title', (WidgetTester tester) async {
    await tester.pumpWidget(const GalaxyImageViewerApp());
    await tester.pumpAndSettle();

    expect(find.text('Galaxy 图片查看器'), findsOneWidget);
  });
}
