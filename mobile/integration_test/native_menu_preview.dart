import 'package:flutter/material.dart';
import 'package:mobile/features/world/world_composer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = TextEditingController();
  final focus = FocusNode();
  runApp(
    MaterialApp(
      theme: ThemeData(
        brightness: const bool.fromEnvironment('DARK_MENU')
            ? Brightness.dark
            : Brightness.light,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xfff6f3ee),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: WorldComposer(
              controller: controller,
              focusNode: focus,
              onChanged: (_) {},
              onAttach: () {},
              onVoice: () {},
              onSend: null,
              onSourceSelected: (value) {
                debugPrint('NATIVE_MENU_SELECTED $value');
              },
              busy: false,
              listening: false,
              compact: false,
            ),
          ),
        ),
      ),
    ),
  );
}
