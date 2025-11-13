import 'package:flutter/material.dart';

/// A reusable app bar component that handles the top navigation
/// This separates the app bar logic from the main page
class InventoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const InventoryAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );
}

/// A reusable language selector component
class LanguageSelector extends StatelessWidget {
  final Function(String) onLanguageChanged;

  const LanguageSelector({
    super.key,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onLanguageChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'da', child: Text('Dansk')),
      ],
      icon: const Icon(Icons.language),
      tooltip: 'Change Language',
    );
  }
}

/// A reusable action button component for the app bar
class DataManagementButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DataManagementButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('DataManagementButton is building!');
    return IconButton(
      icon: const Icon(
        Icons.settings,
        size: 32,
        color: Colors.orange,
      ),
      tooltip: 'Data Management',
      onPressed: () {
        debugPrint('Data Management button pressed!');
        onPressed();
      },
    );
  }
}