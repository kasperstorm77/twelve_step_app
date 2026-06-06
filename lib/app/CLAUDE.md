# Core / bootstrap — area rules

App shell wiring. This folder holds `app_module.dart` (Flutter Modular
DI + the `/` route) and `app_widget.dart` (root `MaterialApp.router`).
The bootstrap itself lives in [lib/main.dart](../main.dart). See
[architecture.md §6](../../docs/architecture.md).

## main.dart bootstrap rules
- **Register all 17 Hive adapters BEFORE opening any box.** The frozen
  typeId map is in [architecture.md §2.1](../../docs/architecture.md);
  next free id is 17.
- **Keep the open-box set in sync with `SyncPayloadBuilder`** — it reads
  every box unguarded, so a box it expects but `main.dart` didn't open
  throws at upload.
- **Every data box opens with the delete-and-recreate-on-corruption
  fallback;** the `settings` box has none (corrupt `settings` = startup
  throws — intentional). Don't add a fallback to `settings`.

## app_widget rules
- **Morning-ritual force-load runs in two places** — `main.dart` at
  startup (after Drive sync, so restored settings win) and
  `AppWidget.didChangeAppLifecycleState` on resume — both guarded
  once-per-day. Keep both.
- The post-frame **"Newer Data Available"** dialog appears when
  `AllAppsDriveService.uploadsBlocked`: *Fetch* restores the newest
  backup (`createSafetyBackup: false`), *Keep Local* unblocks uploads.
- `use_build_context_synchronously` is **intentionally ignored** here:
  dialog contexts are re-fetched from
  `Modular.routerDelegate.navigatorKey`, not the stale widget context.
  Don't "fix" the async-gap re-fetches.
- `AppHomePage` wraps `AppRouter` in a `ValueListenableBuilder` on
  `DataRefreshService.revision` so a restore rebuilds the whole tree.
</content>
