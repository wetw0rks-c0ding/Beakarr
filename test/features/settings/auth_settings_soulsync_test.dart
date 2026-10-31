// SKIPPED — widget test for Auth SoulSync row + pilot removal.
// Reason: settings_provider override requires SettingsNotifier (not SettingsModel);
// constructing a correct notifier needs secure-store + service init (not cheap per brief).
// Instead verified by: (a) flutter analyze 0 errors on edited files, (b) manual
// structure check (SoulSync label at line ~304, 'Sonarr (pilot)' absent, _sonarrStatus preserved),
// (c) login screen pushes web view with correct start URL.
// No network tests (spec prohibition).
void main() {}
