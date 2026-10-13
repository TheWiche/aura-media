import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medias_download/core/services/settings_service.dart';
import 'package:medias_download/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test - Aura loads correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.initialize();
    ReceiveSharingIntent.setMockValues(
      initialMedia: [],
      mediaStream: const Stream.empty(),
    );

    await tester.pumpWidget(const AuraApp(initialThemeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    expect(find.text('Aura'), findsWidgets);
  });
}
