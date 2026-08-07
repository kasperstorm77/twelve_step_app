#!/usr/bin/env bash
# Prove that recovery data still moves between this application and Emotional
# Sobriety before anything reaches Google Play or App Store Connect.
#
# The two applications share five datasets through an exported JSON file: I-Am
# definitions, Fourth Step entries, Agnosticism pairs, Morning definitions and
# Morning history. A one-sided change to a shared key, an instant's zone, or a
# validation rule is a broken import — not a warning — and the person who finds
# out is someone who has already lost their work.
#
# Three checks, and all three must pass:
#
#   1. This application still imports payloads captured from theirs.
#   2. This application's live SyncPayloadBuilder still produces a payload that
#      THEIR OWN BackupValidator accepts. Not a fixture — the real builder,
#      seeded with the awkward cases (Danish text, an empty connected fear, an
#      archived pair, a randomized reading, contiguous sort orders). Fixtures on
#      both sides were hand-authored once, and that is exactly how the last
#      cross-application defect survived both suites.
#   3. Their suites still accept this side, run from their checkout.
#
# There is no flag that clears a release on one direction. --peer none runs what
# it can and then fails, so it can diagnose but never green-light a ship.
#
# Usage:
#   bash scripts/verify-cross-app-recovery.sh
#   bash scripts/verify-cross-app-recovery.sh --peer ../emotional_sobriety
#   bash scripts/verify-cross-app-recovery.sh --peer none   # diagnostic; still fails

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -t 1 ]]; then
  c_reset=$'\033[0m'; c_bold=$'\033[1m'
  c_red=$'\033[31m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_cyan=$'\033[36m'
else
  c_reset=""; c_bold=""; c_red=""; c_green=""; c_yellow=""; c_cyan=""
fi
say()    { printf "→ %s\n" "$*"; }
ok()     { printf "%s✓%s %s\n" "$c_green" "$c_reset" "$*"; }
warn()   { printf "%s!%s %s\n" "$c_yellow" "$c_reset" "$*"; }
err()    { printf "%s✗%s %s\n" "$c_red" "$c_reset" "$*" >&2; }
header() {
  printf "\n%s%s%s\n" "$c_bold$c_cyan" "$1" "$c_reset"
  printf "%s%s%s\n" "$c_bold$c_cyan" "────────────────────────────────────────────────────────────" "$c_reset"
}

peer="${EMOTIONAL_SOBRIETY_REPO:-../emotional_sobriety}"

while (( $# )); do
  case "$1" in
    --peer) shift; peer="${1:?--peer needs a path or 'none'}" ;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown flag: $1"; exit 2 ;;
  esac
  shift
done

# Suites on this side that pin the wire format and the import of their payloads.
# Their fixtures are captured from that application's real output.
local_suites=(
  test/shared_json_parity_test.dart
  test/emotional_sobriety_import_test.dart
  test/agnosticism_connected_fear_test.dart
  test/morning_ritual_randomizer_portability_test.dart
  test/morning_randomizer_catalog_generation_test.dart
)

# Produces build/cross_app/twelve_steps_export.json from the live builder.
export_suite="test/cross_app_export_fixture_test.dart"
export_json="build/cross_app/twelve_steps_export.json"

# Their suites that pin this application's export and the agreed key set.
peer_suites=(
  test/shared/sync/shared_recovery_contract_test.dart
  test/shared/sync/cross_app_agnosticism_test.dart
  test/shared/sync/shared_restore_service_test.dart
)

header "Pre-flight"
command -v flutter >/dev/null 2>&1 || { err "flutter is required"; exit 2; }
for suite in "${local_suites[@]}" "$export_suite"; do
  [ -f "$suite" ] || { err "missing cross-application suite: $suite"; exit 1; }
done
ok "Cross-application suites present"

header "1. This application imports their payload"
say "flutter test ${local_suites[*]}"
if ! flutter test "${local_suites[@]}"; then
  err "This application no longer accepts Emotional Sobriety's payload."
  exit 1
fi
ok "Their fixtures still decode and restore here"

header "2. Build a live export from this application"
rm -f "$export_json"
if ! flutter test "$export_suite"; then
  err "Could not build an export — the payload broke its own invariants."
  exit 1
fi
[ -f "$export_json" ] || { err "$export_suite did not write $export_json"; exit 1; }
ok "Live export: $export_json ($(wc -c < "$export_json" | tr -d ' ') bytes)"

# ─── the peer checkout ───────────────────────────────────────────────────────
if [ "$peer" = "none" ]; then
  header "Result"
  warn "Peer repository check was explicitly skipped with --peer none."
  warn "Only one transfer direction was proven. Do not release on this result."
  exit 1
fi

if [ ! -d "$peer" ]; then
  err "Emotional Sobriety repository not found at: $peer"
  err "Pass --peer PATH or set \$EMOTIONAL_SOBRIETY_REPO to its checkout."
  err "Both directions must be proven before a store release."
  exit 1
fi
peer_path=$(cd "$peer" && pwd -P)
[ -f "$peer_path/pubspec.yaml" ] || { err "Not a Flutter repository: $peer_path"; exit 1; }

header "3. Their validator accepts this live export"
# Their BackupValidator is library-private to their package, so the check has to
# run from inside their checkout. This drops one throwaway test there and always
# removes it again — the peer repository is left exactly as it was found.
probe_rel="test/shared/sync/zz_live_twelve_steps_export_probe_test.dart"
probe="$peer_path/$probe_rel"
cleanup() { rm -f "$probe"; }
trap cleanup EXIT

if [ -e "$probe" ]; then
  err "A probe file already exists at $probe_rel — refusing to overwrite it."
  exit 1
fi

cat > "$probe" <<'DART'
// TEMPORARY probe written by the Twelve Steps repository's
// scripts/verify-cross-app-recovery.sh. It is deleted when that script exits.
// If you are reading this in a diff, the script died — delete the file.
import 'dart:io';

import 'package:emotional_sobriety/features/morning_ritual/application/workshop_morning_randomizer_source.dart';
import 'package:emotional_sobriety/features/workshop/data/workshop_content_repository.dart';
import 'package:emotional_sobriety/features/workshop/domain/workshop_exercise.dart';
import 'package:emotional_sobriety/shared/settings/app_settings.dart';
import 'package:emotional_sobriety/shared/settings/settings_repository.dart';
import 'package:emotional_sobriety/shared/sync/backup_validator.dart';
import 'package:emotional_sobriety/shared/sync/decoded_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late BackupValidator validator;
  late WorkshopContentCatalog workshopContent;
  late WorkshopGuidedWorkshopDefinition guidedWorkshop;

  setUpAll(() async {
    workshopContent = await const WorkshopContentRepository().load();
    guidedWorkshop = workshopContent.guidedWorkshop;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('es_live_probe_');
    Hive.init(tmp.path);
    final settingsBox = await Hive.openBox<dynamic>('settings');
    validator = BackupValidator(
      settings: SettingsRepository(
        box: settingsBox,
        defaults: const AppSettingsDefaults(
          morningAutoStartEnabled: false,
          morningStartMinutes: 300,
          morningEndMinutes: 540,
          agnosticismMaxActivePairs: 5,
        ),
        fallbackLocaleCode: 'en',
        onPortableMutation: () async {},
      ),
      agnosticismMaxActivePairs: 5,
      guidedWorkshop: guidedWorkshop,
      morningRandomizerSource: WorkshopMorningRandomizerSource(workshopContent),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('a live Twelve Steps export decodes and keeps every shared dataset', () {
    final path = Platform.environment['TWELVE_STEPS_EXPORT'];
    expect(path, isNotNull, reason: 'TWELVE_STEPS_EXPORT must be set');

    final decoded = validator.decodeString(File(path!).readAsStringSync());
    expect(decoded, isA<DecodedTwelveStepsBackup>());
    final ts = decoded as DecodedTwelveStepsBackup;

    // Nothing may be silently dropped on the way in.
    expect(ts.shared.definitions, isNotEmpty, reason: 'I-Am definitions lost');
    expect(ts.shared.entries, isNotEmpty, reason: 'Fourth Step entries lost');
    expect(ts.shared.ritualItems, isNotEmpty, reason: 'Morning definitions lost');
    expect(ts.shared.ritualEntries, isNotEmpty, reason: 'Morning history lost');
    expect(ts.agnosticismPairs, isNotEmpty, reason: 'Agnosticism pairs lost');

    // An absent connected fear means "not recorded yet" and must survive as
    // empty rather than failing validation or being invented.
    expect(
      ts.agnosticismPairs.map((p) => p.connectedFear),
      contains(''),
      reason: 'a pair with no connected fear must still import',
    );
    expect(
      ts.agnosticismPairs.where((p) => p.isArchived),
      isNotEmpty,
      reason: 'an archived pair must survive the transfer',
    );

    // Danish text proves the UTF-8 path end to end. Read real fields — their
    // models have no toString(), so joining instances proves nothing.
    final danish = [
      ...ts.shared.definitions.map((d) => d.name),
      ...ts.shared.entries.map((e) => e.resentment ?? ''),
      ...ts.shared.entries.map((e) => e.reason ?? ''),
      ...ts.shared.ritualItems.map((i) => i.name),
    ].join(' ');
    expect(
      danish,
      matches(RegExp('[æøåÆØÅ]')),
      reason: 'non-ASCII text did not survive the transfer: $danish',
    );
  });
}
DART

# Resolve the export to an absolute path here — the probe runs after a cd.
export_abs="$(cd "$(dirname "$export_json")" && pwd -P)/$(basename "$export_json")"

say "flutter test $probe_rel  (in $peer_path)"
if ! (cd "$peer_path" && TWELVE_STEPS_EXPORT="$export_abs" flutter test "$probe_rel"); then
  err "Emotional Sobriety's validator REJECTED this application's live export."
  err "The shared JSON contract is broken — do not release."
  exit 1
fi
ok "Their real validator accepts this application's live export"

header "4. Their own suites still pass"
missing=0
for suite in "${peer_suites[@]}"; do
  if [ ! -f "$peer_path/$suite" ]; then
    warn "peer suite not found (renamed?): $suite"
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  err "The agreed wire format is no longer pinned on their side."
  exit 1
fi
say "flutter test ${peer_suites[*]}  (in $peer_path)"
if ! (cd "$peer_path" && flutter test "${peer_suites[@]}"); then
  err "Emotional Sobriety no longer accepts this application's export."
  exit 1
fi
ok "Their parity suites pass"

header "Result"
ok "Recovery data moves in both directions — safe to release"
printf "  %sthis app:%s %s\n" "$c_bold" "$c_reset" "$(pwd -P)"
printf "  %speer:%s     %s\n" "$c_bold" "$c_reset" "$peer_path"
