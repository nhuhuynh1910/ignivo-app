# Tương thích IGNIVO Mobile với FireGuard Pi

Cập nhật: 16/10/2026. Áp dụng cho luồng phát hành FireGuard-First Mobile UX. Chỉ thay đổi app; không sửa, deploy, restart hoặc thay cấu hình backend Pi.

## 1. Ranh giới và Nguồn nghiệp vụ Duy nhất

- **FireGuard (`/api/v1/emergency`)** là nguồn nghiệp vụ và xác thực duy nhất mà app di động gọi trực tiếp.
- **FireEye (`:8000`)** đóng vai trò hệ thống xác thực đứng sau proxy FireGuard. App di động không gọi trực tiếp cổng 8000 trong luồng phát hành.
- **Chính sách phiên:** Token chỉ giữ trong RAM (bộ nhớ tạm), không lưu mật khẩu hoặc token vào `SharedPreferences`. Khi app khởi động lạnh (cold start) hoặc token bị từ chối, yêu cầu đăng nhập lại.
- **Hợp đồng xác thực phiên:** Phiên chỉ được coi là hợp lệ (`isAuthenticated == true`) sau khi token được xác nhận thành công qua `GET /api/v1/emergency/auth/me`.

---

## 2. Bảng Hợp đồng API FireGuard

| Chức năng | Endpoint FireGuard | Request Body / Params | Response & Hành vi App |
|---|---|---|---|
| **Health Check** | `GET /api/v1/emergency/health` | Không | HTTP 200 `{"status":"ok","service":"fireguard"}`. Dùng để kiểm tra kết nối Pi ở màn hình thiết lập. |
| **System Info** | `GET /api/v1/emergency/system/info` | Bearer token | `{"hostname": "...", "device_id": "...", "cpu_temp_c": ...}`. Lấy và lưu `deviceId` vào connection profile. |
| **System Status** | `GET /api/v1/emergency/status` | Bearer token | `{"vision": {"ready": true, "total_ai_fps": ...}, ...}`. Lấy trạng thái giám sát AI, Gemini, Stringee. |
| **Đăng nhập Proxy** | `POST /api/v1/emergency/auth/login` | JSON `{phone_number, secret_key, system_secret_key, device_name}` | Trả về `{token, user}`. Lỗi 401 giữ nguyên message chi tiết ("Sai số điện thoại hoặc mật khẩu"), không kích hoạt renew callback. Lỗi 503 báo không kết nối được FireEye. |
| **Xác thực Phiên** | `GET /api/v1/emergency/auth/me` | Header `Authorization: Bearer <token>` | Trả về thông tin `{id, username, phone_number, full_name, role}`. Nếu 401 $\rightarrow$ xóa token và yêu cầu đăng nhập lại. |
| **Đăng xuất Proxy** | `POST /api/v1/emergency/auth/logout` | Header `Authorization: Bearer <token>` | Trả về `{ok: true}`. Luôn xóa token cục bộ và dừng toàn bộ kết nối WebSocket/stream/polling. |
| **Danh sách Camera** | `GET /api/v1/emergency/cameras` | Bearer token | Danh sách camera `{id, name, area, enabled, detect_enabled, ...}`. |
| **Cập nhật Camera** | `PUT /api/v1/emergency/cameras/{id}` | JSON `CameraUpdate` | Chỉ cho phép OWNER/ADMIN. Chỉ gửi các trường thay đổi (tên, khu vực, detect_enabled, ai_fps). |
| **Live Stream** | `GET /api/v1/emergency/cameras/{id}/stream` | Header `Authorization: Bearer <token>` | Luồng MJPEG. Dừng ngay khi rời màn hình, đổi tab, route bị che hoặc app vào nền. |
| **Snapshot Camera** | `GET /api/v1/emergency/cameras/{id}/snapshot` | Header `Authorization: Bearer <token>` | Ảnh JPEG gần nhất, dùng cho thumbnail Trang chủ và danh sách Camera. |
| **Danh sách Sự cố** | `GET /api/v1/emergency/incidents` | Query `limit=50&status=...` | Danh sách sự cố gần nhất. App merge danh sách và không coi vắng mặt là sự cố đã đóng. |
| **Chi tiết Sự cố** | `GET /api/v1/emergency/incidents/{id}` | Bearer token | Chi tiết sự cố, ảnh phân tích và lịch sử cuộc gọi. Đăng ký ID xem chi tiết vào polling chung. |
| **Ảnh Sự cố** | `GET /api/v1/emergency/incidents/{id}/images/{name}` | Header `Authorization: Bearer <token>` | Ảnh JPEG bằng chứng. Không đưa token vào query string. |
| **Tiếp nhận Xử lý (ACK)** | `POST /api/v1/emergency/incidents/{id}/ack` | JSON `{"note": "..."}` | Cho phép mọi role hợp lệ (USER, ADMIN, OWNER). Dừng các lượt gọi tự động tiếp theo, sự cố vẫn mở. |
| **Đóng Sự cố (Resolve)** | `POST /api/v1/emergency/incidents/{id}/resolve` | JSON `{"note": "..."}` | Đã xử lý xong hỏa hoạn, đóng sự cố. Trả 409 nếu sự cố đã đóng trước đó. |
| **Báo nhầm (False Alarm)**| `POST /api/v1/emergency/incidents/{id}/false-alarm` | JSON `{"note": "..."}` | Đóng sự cố và ghi nhận báo nhầm. |
| **Danh bạ Khẩn cấp** | `GET /api/v1/emergency/contacts` | Bearer token | Danh sách người thân và PCCC. Mọi vai trò đều được xem. |
| **Thêm Người liên hệ** | `POST /api/v1/emergency/contacts` | JSON `ContactIn` | Chỉ OWNER/ADMIN. USER bị chặn trên UI (tránh nhận lỗi 403). |
| **Sửa/Xóa Liên hệ** | `PUT/DELETE /api/v1/emergency/contacts/{id}`| JSON / ID | Chỉ OWNER/ADMIN. |
| **Địa chỉ Khẩn cấp** | `PUT /api/v1/emergency/settings/location` | JSON `LocationSettings` đầy đủ | Chỉ OWNER/ADMIN. Phải gửi đầy đủ object location. |
| **WebSocket Realtime** | `GET /api/v1/emergency/ws?token=...` | Query `token` | Cập nhật sự cố thời gian thực (`incident.created`, `incident.updated`, `incident.closed`). URL WS không ghi log. |

---

## 3. Danh mục Mã Legacy Cách ly khỏi Luồng Phát hành

Các thành phần sau được giữ nguyên trong kho mã nguồn nhưng cách ly hoàn toàn khỏi luồng khởi động (`main.dart` $\rightarrow$ `AppEntryGate` $\rightarrow$ `IgnivoShell`):

1. **Firebase Services:** `auth_service.dart`, `firestore_service.dart`, `realtime_database_service.dart`, `main_navigation.dart`, `features/auth/auth_wrapper.dart`.
2. **FireEye Services trực tiếp:** `fireeye_api_service.dart` (và cơ chế tự động cài refresh callback vào FireGuard cũ).
3. **Tính năng không thuộc phạm vi FireGuard:** Điều khiển PTZ (`ptz_control.dart`), đăng ký khuôn mặt (`people_page.dart`), sự kiện FireEye (`eye_events_page.dart`), form tạo mới camera trực tiếp trên mobile (`camera_editor_page.dart` ở chế độ tạo mới).
