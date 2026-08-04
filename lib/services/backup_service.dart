class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  Future<String?> createBackup() async => null;
  Future<bool> restoreFromBackup(String path) async => false;
}
