import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
