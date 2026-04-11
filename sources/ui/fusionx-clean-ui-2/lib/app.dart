import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/editor/presentation/screens/fusionx_clean_ui_screen.dart';

class ReFusionApp extends StatelessWidget {
  const ReFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReFusion',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: buildFxTheme(),
      darkTheme: buildFxTheme(),
      home: const FusionXCleanUiScreen(),
    );
  }
}
