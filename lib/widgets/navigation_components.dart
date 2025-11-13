import 'package:flutter/material.dart';

/// Reusable navigation components for tab-based interfaces
class InventoryTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<Tab> tabs;

  const InventoryTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      tabs: tabs,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);
}

/// A factory for creating tabs - returns actual Tab widgets
class InventoryTabFactory {
  static Tab createTab({
    required String text,
    IconData? icon,
  }) {
    if (icon != null) {
      return Tab(
        icon: Icon(icon),
        text: text,
      );
    } else {
      return Tab(text: text);
    }
  }
}

/// A container for tab content that provides consistent styling
class TabContentContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const TabContentContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      child: child,
    );
  }
}