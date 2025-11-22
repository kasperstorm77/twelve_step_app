import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../shared/services/locale_provider.dart';
import '../shared/pages/app_router.dart';

class AppModule extends Module {
  @override
  void binds(Injector i) {
    // Shared services - singleton instances
    i.addSingleton<LocaleProvider>(LocaleProvider.new);
    
    // Hive boxes - lazy singletons (shared across apps)
    i.addLazySingleton<Box>(() => Hive.box('settings'));
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (context) => const AppHomePage());
  }
}

// Simple wrapper for locale management and routing
class AppHomePage extends StatelessWidget {
  const AppHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppRouter();
  }
}