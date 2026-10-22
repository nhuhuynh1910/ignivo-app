import 'package:flutter_test/flutter_test.dart';
import 'package:ignivo_app/core/models/pi_connection_profile.dart';
import 'package:ignivo_app/core/models/system_record.dart';
import 'package:ignivo_app/core/services/system_registry_repository.dart';
import 'package:ignivo_app/core/services/system_session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Registry Sync & Multi-Platform Persistence Tests', () {
    const testUid = 'user_web_mobile_sync_123';

    test('isCloudSyncSupported is false when running in pure unit test without Firebase', () {
      final repo = SystemRegistryRepository();
      expect(repo.isCloudSyncSupported, isFalse);
    });

    test('syncFromCloud falls back cleanly to local SharedPreferences when offline/standalone', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SystemRegistryRepository(prefs: prefs);

      final record = SystemRecord(
        systemId: 'sys_warehouse_01',
        systemName: 'Kho Đông Lạnh A',
        guardUrl: 'http://192.168.1.88:8080',
        role: 'OWNER',
        addedAt: DateTime.now(),
      );

      await repo.saveSystem(testUid, record, token: 'jwt-token-alpha');
      expect((await repo.getSystems(testUid)).length, 1);

      // syncFromCloud without cloud backend returns local systems safely
      final synced = await repo.syncFromCloud(testUid);
      expect(synced.length, 1);
      expect(synced.first.systemId, 'sys_warehouse_01');
      expect(synced.first.systemName, 'Kho Đông Lạnh A');
    });

    test('watchCloudSystems returns empty stream without throwing when cloud is unavailable', () async {
      final repo = SystemRegistryRepository();
      final stream = repo.watchCloudSystems(testUid);
      expect(await stream.isEmpty, isTrue);
    });

    test('SystemSessionManager initializes and triggers cloud sync without race condition or disposal errors', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SystemRegistryRepository(prefs: prefs);

      final recordA = SystemRecord(
        systemId: 'sys_01',
        systemName: 'Nhà Chính',
        guardUrl: 'http://192.168.1.10:8080',
        role: 'OWNER',
        addedAt: DateTime.now(),
      );
      final recordB = SystemRecord(
        systemId: 'sys_02',
        systemName: 'Văn Phòng',
        guardUrl: 'http://192.168.1.20:8080',
        role: 'ADMIN',
        addedAt: DateTime.now(),
      );

      await repo.saveSystem(testUid, recordA);
      await repo.saveSystem(testUid, recordB);

      final manager = SystemSessionManager(registry: repo, uid: testUid);
      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(manager.systems.length, 2);
      expect(manager.activeSystemId, 'sys_01');

      // Dispose cleanly without uncaught timer or stream exceptions
      manager.dispose();
    });

    test('removed system is never resurrected by migrateLegacyProfile or subsequent logins', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SystemRegistryRepository(prefs: prefs);

      // Save a legacy profile as if user setup a single Pi before
      final legacyProfile = PiConnectionProfile.fromGuardUrl(
        'http://192.168.1.99:8080',
        systemName: 'Xưởng Cũ',
      );
      await legacyProfile.save(prefs);

      // 1. First migration imports the legacy profile
      final migrated = await repo.migrateLegacyProfile(testUid);
      expect(migrated, isNotNull);
      expect(migrated!.systemName, 'Xưởng Cũ');
      expect((await repo.getSystems(testUid)).length, 1);

      // 2. User explicitly removes the system
      await repo.removeSystem(testUid, migrated.systemId);
      expect((await repo.getSystems(testUid)).isEmpty, isTrue);

      // 3. User logs in again -> migrateLegacyProfile is called again
      final secondMigrate = await repo.migrateLegacyProfile(testUid);
      expect(secondMigrate, isNull);

      // Systems list MUST remain empty - no ghost system resurrected!
      final systemsAfterRelogin = await repo.getSystems(testUid);
      expect(systemsAfterRelogin.isEmpty, isTrue);
    });
  });
}
