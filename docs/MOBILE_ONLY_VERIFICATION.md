# Báo Cáo Nghiệm Thu IGNIVO Mobile (FireGuard-First UX)

Ngày thực hiện: 16/10/2026  
Nhánh phát triển: `ignivo-v2`  
Mục tiêu: Triển khai toàn diện kiến trúc FireGuard-First UX trên ứng dụng di động (`ignivo-app`), thống nhất proxy xác thực và nghiệp vụ giám sát duy nhất qua FireGuard (`/api/v1/emergency`), tuân thủ chính sách phiên RAM-only, loại bỏ hoàn toàn mã ngoài phạm vi (Firebase, PTZ, Face registration, cloud claim), giữ 100% test passing và 0 analyzer warning.

---

## 1. Kết Quả Kiểm Tra Cuối (Acceptance Checklist)

| Hạng mục kiểm tra | Lệnh thực hiện | Kết quả thực tế |
|---|---|---|
| **Bộ kiểm thử hồi quy** | `flutter test --no-pub` | **122/122 tests pass** (100% thành công) |
| **Phân tích mã nguồn** | `flutter analyze --no-pub` | **No issues found!** (0 error, 0 warning) |
| **Biên dịch Android APK** | `flutter build apk --debug --no-pub` | **Thành công** (`build/app/outputs/flutter-apk/app-debug.apk`, 26.5s) |
| **Phiên bản kiến trúc** | Local Git Branch | `ignivo-v2` |

---

## 2. Nhật Ký Triển Khai Theo Gói (Phased Delivery Log)

### Gói 0 — Baseline & Hợp Đồng Dữ Liệu
- **Commit:** `e41848c`
- **Nội dung:**
  - Cập nhật tài liệu hợp đồng `docs/MOBILE_API_COMPATIBILITY.md` phản ánh trung thực FireGuard Edge API.
  - Tạo bộ fixture chuẩn hóa trong `test/fixtures/`: `fireguard_auth_login.json`, `fireguard_auth_me.json`, `fireguard_auth_user.json`, `fireguard_system_info.json`, `fireguard_error_401.json`, `fireguard_error_403.json`, `fireguard_error_503.json`.
  - Phân biệt rõ lỗi 401 khi đăng nhập (sai mật khẩu/mã hệ thống) và 401 khi gọi API được bảo vệ (phiên hết hạn).
  - Bổ sung `test/contract_fixtures_test.dart` kiểm chứng toàn vẹn hợp đồng.

### Gói 1 — Quản Lý Phiên & Cổng Vào Thống Nhất (P0)
- **Commit:** `5e0ce16`
- **Nội dung:**
  - Nâng cấp `PiConnectionProfile` lên schema v3 với trường `isConfigured` và `deviceId`, di chuyển an toàn từ v1/v2 mà không làm mất URL hợp lệ.
  - Xây dựng `SystemSessionController` (kế thừa `ChangeNotifier`) với 5 trạng thái: `unconfigured`, `unauthenticated`, `authenticating`, `authenticated`, `sessionExpired`.
  - Thực thi nghiêm ngặt chính sách RAM-only: Token chỉ tồn tại trong bộ nhớ RAM của ứng dụng, không lưu mật khẩu hoặc JWT vào `SharedPreferences`.
  - Trạng thái `isAuthenticated` chỉ kích hoạt sau khi `/auth/me` xác thực thành công.
  - Tạo `ConnectionSetupPage`, `SystemLoginPage` và cổng điều phối `AppEntryGate` gắn vào `main.dart`.
  - Kiểm thử: `test/app_entry_test.dart` và `test/system_session_controller_test.dart`.

### Gói 2 — Bộ Điều Khiển Trạng Thái Giám Sát & Shell Trung Tâm (P0)
- **Commit:** `65b87a8`
- **Nội dung:**
  - Xây dựng `MonitoringController` làm đầu mối quản lý tài nguyên duy nhất: 1 kết nối WebSocket, 1 nhịp polling định kỳ 5 giây, điều phối âm báo qua `IncidentAlertCoordinator`.
  - Xây dựng `IgnivoShell` lắng nghe vòng đời ứng dụng `WidgetsBindingObserver` (pause/resume đúng lúc), hiển thị SnackBar cảnh báo có rung phản hồi haptic khi có sự cố mới.
  - Hợp nhất cơ chế cập nhật sự cố chi tiết: trang chi tiết đăng ký/hủy đăng ký ID sự cố qua `registerDetailedIncident` và `unregisterDetailedIncident`, loại bỏ hoàn toàn timer polling riêng lẻ gây xung đột.
  - Sửa `FireguardPage` để không dispose `realtime` hoặc `coordinator` được inject từ ngoài.
  - Kiểm thử: `test/monitoring_controller_test.dart`.

### Gói 3 — Trang Chủ Giám Sát & Chuẩn Hóa Trạng Thái An Toàn (P1)
- **Commit:** `3adea55`
- **Nội dung:**
  - Xây dựng `GuardHomePage` gồm:
    - Header hiển thị tên địa điểm và mốc thời gian đồng bộ dữ liệu.
    - Banner cảnh báo an toàn được hiệu chỉnh cẩn trọng: dùng câu chữ chính xác *"Chưa ghi nhận cảnh báo trong dữ liệu hiện có"* khi an toàn; không dùng nhãn phô trương *"An toàn tuyệt đối"*.
    - Banner sự cố khẩn cấp dạng pulsing alert card khi có sự cố mở, kèm nút bấm trực tiếp vào xử lý.
    - Thẻ mức sẵn sàng giám sát: trạng thái trực tuyến của camera và cấu hình gọi khẩn cấp Stringee.
    - Danh sách cuộn ngang xem nhanh các Camera.
    - Lịch sử hoạt động gần đây (tối đa 4 sự cố mới nhất).
  - Tích hợp `GuardHomePage` vào Tab 0 của `IgnivoShell`.
  - Sửa `FireguardApiService.getActiveIncident` trả về `null` an toàn khi dữ liệu rỗng.
  - Kiểm thử: `test/guard_home_page_test.dart`.

### Gói 4 — Camera & Live View Thời Gian Thực (P1)
- **Commit:** `5dc868f`
- **Nội dung:**
  - Xây dựng `GuardCamerasPage` (Tab 1):
    - Danh sách camera với trạng thái trực tuyến (ONLINE / OFFLINE), chip trạng thái AI nhận diện, tốc độ FPS mục tiêu.
    - Nút "Sửa cấu hình" hiển thị độc quyền cho vai trò `OWNER`/`ADMIN`, ẩn đối với vai trò `USER`.
    - Hộp thoại giải thích quy trình thêm camera mới trên Edge Box.
  - Xây dựng `CameraLivePage`:
    - Xem luồng video MJPEG chuyên biệt với tính năng phóng to toàn màn hình (Fullscreen toggle).
    - Hiển thị thông số chi tiết của camera, tốc độ khung hình LIVE AI, trạng thái Hailo NPU.
  - Nâng cấp `MjpegStreamView`: bổ sung `WidgetsBindingObserver` tự động tạm dừng phát luồng khi app chạy nền và tiếp tục khi trở lại tiền cảnh, tránh rò rỉ băng thông.
  - Tái sử dụng `GuardCameraEditor`: cập nhật từng phần (tên, khu vực, FPS, bật/tắt AI), không để lộ RTSP raw hay credential.
  - Kiểm thử: `test/guard_cameras_page_test.dart`.

### Gói 5 — Lịch Sử Hoạt Động & Thao Tác Sự Cố Chi Tiết (P0/P1)
- **Commit:** `9a06ead`
- **Nội dung:**
  - Xây dựng `GuardActivityPage` (Tab 2):
    - Tải tối đa 50 sự cố gần nhất qua `api.getIncidents(limit: 50)`.
    - 5 bộ lọc linh hoạt: *Tất cả*, *Cần chú ý* (`analyzing`, `notifying`, `notified`, `ai_dismissed`), *Đang xử lý* (`acknowledged`), *Đã kết thúc* (`resolved`, `false_alarm`), *Mô phỏng* (`is_simulation`).
    - Thẻ sự cố hiển thị icon theo loại kích hoạt (lửa, khói, nhiệt, mô phỏng), mức độ nghiêm trọng, nhãn trạng thái và thời gian.
  - Đồng bộ chuẩn xác các endpoint xử lý sự cố trong `FireguardIncidentPage`:
    - Nhận xử lý (ACK): `POST /api/v1/emergency/incidents/{id}/ack` (nhãn *"Nhận xử lý • Dừng gọi tiếp"*).
    - Đã xử lý (Resolve): `POST /api/v1/emergency/incidents/{id}/resolve` (kèm dialog xác nhận đóng sự cố).
    - Báo nhầm (False Alarm): `POST /api/v1/emergency/incidents/{id}/false-alarm` (kèm dialog xác nhận).
    - Tắt còi trên điện thoại: ngắt âm thanh và rung cục bộ qua `coordinator.silenceAlarm()`, không gửi ACK ngầm lên server.
    - Xử lý xung đột 409: thông báo lỗi từ backend và tự động tải lại chi tiết sự cố mới nhất.
  - Kiểm thử: `test/guard_activity_page_test.dart`.

### Gói 6 — Cài Đặt Hệ Thống & Chẩn Đoán Chuyên Sâu (P1)
- **Commit:** `acbedaf`
- **Nội dung:**
  - Xây dựng `GuardSettingsPage` (Tab 3):
    - Thông tin tài khoản, số điện thoại và vai trò tài khoản (`OWNER`, `ADMIN`, `USER`).
    - Lối vào cấu hình danh bạ gọi điện khẩn cấp (`EmergencyContactsPage` qua `/contacts`).
    - Lối vào cấu hình vị trí địa chỉ khẩn cấp (`EmergencyLocationPage` qua `/settings/location`).
    - Khối giải thích cơ chế âm thanh & rung khi ứng dụng đang mở, cảnh báo chế độ Không Làm Phiền (DND).
    - Lối vào màn hình chẩn đoán hệ thống.
    - Chức năng "Đăng xuất tài khoản" (xóa token khỏi RAM, đưa về trang Login).
    - Chức năng "Đổi kết nối Pi khác" (xóa cấu hình và phiên, gọi `sessionController.disconnect()`).
  - Xây dựng `DiagnosticsPage`:
    - Giám sát sức khỏe kết nối WebSocket và thời gian đồng bộ dữ liệu gần nhất.
    - Thông số phần cứng Edge Pi: Hostname, Device ID.
    - Trạng thái bộ tăng tốc AI Hailo NPU và tổng FPS nhận diện.
    - Trạng thái tổng đài Stringee, số liên hệ người thân và PCCC.
    - Bảo mật: Token được che dấu an toàn (`eyJhbG••••••••z123`), khẳng định chính sách lưu phiên trong bộ nhớ RAM.
  - Kiểm thử: `test/guard_settings_page_test.dart`.

---

## 3. Ranh Giới Kỹ Thuật Đã Bảo Toàn

1. **Nguồn dữ liệu & xác thực duy nhất:** Toàn bộ dữ liệu xuất phát từ backend FireGuard trên Pi (`/api/v1/emergency/*`).
2. **Không phụ thuộc Firebase:** Ứng dụng hoạt động hoàn chỉnh mà không cần Firebase Authentication, Firestore, hay Cloud Messaging khi chưa có backend nền.
3. **Không tính năng giả định:** Đã loại bỏ hoặc đóng băng các chức năng không được FireGuard hỗ trợ (PTZ, Face registration, WebRTC, cloud claim).
4. **Quản lý tài nguyên tập trung:** Toàn bộ ứng dụng duy trì chính xác 1 WebSocket và 1 chu kỳ polling (5 giây) qua `MonitoringController`, không rò rỉ socket khi chuyển tab hay mở chi tiết.
5. **Dừng stream đúng vòng đời:** `MjpegStreamView` và các route camera tự động tạm dừng khi app xuống nền hoặc khi trang bị che lấp.

---

## 4. Nghiệm Thu Thiết Bị Thực Tế Còn Lại (Thực hiện khi có phần cứng)

1. Cài đặt file `app-debug.apk` trên thiết bị Android vật lý.
2. Kết nối vào mạng LAN hoặc Tailscale của Pi và đăng nhập với tài khoản thật.
3. Xác minh luồng MJPEG hiển thị mượt mà với camera IP/USB thực tế.
4. Kích hoạt sự cố thử nghiệm để kiểm tra âm thanh còi hú, rung và phản hồi watchdog khi nhận cuộc gọi.
