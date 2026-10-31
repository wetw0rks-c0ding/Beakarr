class BackupWrongPasswordException implements Exception {
  final String message;
  BackupWrongPasswordException([this.message = 'Wrong password']);
}

class BackupCorruptException implements Exception {
  final String message;
  BackupCorruptException([this.message = 'Backup file is corrupt']);
}

class BackupUnsupportedVersionException implements Exception {
  final int version;
  BackupUnsupportedVersionException(this.version);
}
