# IGNIVO: luồng giám sát một Pi

Luồng kết nối Pi sử dụng hai dịch vụ. Bản này có thay đổi API FireEye và sửa tương thích FireGuard; triển khai theo [ONE_PI_DEPLOYMENT.md](ONE_PI_DEPLOYMENT.md).

| Dịch vụ | URL gốc | Trách nhiệm |
|---|---|---|
| FireEye | `http://100.95.189.60:8000` | Tài khoản/refresh/logout, PTZ Dahua, hồ sơ khuôn mặt, lịch sử FireEye |
| FireGuard | `http://100.95.189.60:8080` | Camera RTSP/USB, Hailo, Gemini, sự cố, Stringee, WebSocket |

FireGuard cần được triển khai với `DETECTION_SOURCE=local` và quyền truy cập camera/Hailo-8L. Giữ API FireEye chạy để phục vụ xác thực, Dahua và đối chiếu khuôn mặt bằng CPU; dừng tiến trình AI cháy riêng của FireEye để không cạnh tranh Hailo. Thay đổi app không tự bật/tắt tiến trình hay đổi cấu hình Pi. Trạng thái thực tế lấy từ API, không suy ra từ việc đăng nhập thành công.

## Đăng nhập và sử dụng

1. Điện thoại/emulator phải truy cập được Pi qua Tailscale (được cấp quyền đến cả hai cổng) hoặc LAN. Việc Windows có Tailscale chưa đủ để khẳng định emulator có đường mạng; kiểm tra từ trình duyệt trên chính emulator. Với điện thoại thật, kết nối Tailscale vào cùng tailnet được cấp quyền.
2. Chạy `flutter run -d emulator-5554` để mở màn hình đăng nhập hệ thống Pi. Không cần `EDGE_ONLY` hay tài khoản Firebase. Khi cài mới, hai URL Tailscale đã được điền sẵn; có thể sửa để dùng Pi khác hoặc địa chỉ LAN.
3. Chỉ nhập URL gốc; `/docs` là tài liệu Swagger, không phải URL gốc của API.
4. Nhập số điện thoại, mật khẩu và mã khoá hệ thống FireEye; hoặc dùng token FireEye còn hạn.
5. Sau khi cả FireEye và FireGuard chấp nhận token, chọn **Mở tổng quan hệ thống**. Xem camera, trạng thái AI, cấu hình Gemini/Stringee, sự cố, ảnh phân tích và lịch sử cuộc gọi.

## Giao diện mobile dựa trên FireGuard Web

Giao diện lấy các luồng trong `fireguard/app/static/index.html` và gộp thành bốn tab:

| Tab | Chức năng trên app |
|---|---|
| Trực tiếp | Chọn một camera để xem MJPEG, FPS thực tế, trạng thái, điểm lửa/khói/người, phân tích Gemini gần nhất của camera |
| Sự cố | Lọc đang mở/đã đóng/mô phỏng; ảnh bằng chứng, lời đọc, lịch sử gọi; nhận xử lý/đóng; mở lịch sử FireEye riêng |
| Camera | Quản lý nguồn; OWNER/ADMIN so sánh hai hình để liên kết đúng Dahua và điều khiển PTZ |
| Cấu hình | Địa chỉ, danh bạ, quy tắc gọi, Gemini/Stringee; hồ sơ khuôn mặt, đồng ý tham gia, xóa hồ sơ, bật/tắt đối chiếu |

Camera offline, AI 0 FPS và dữ liệu lỗi không hiển thị như kết quả nhận diện mới. Model không hỗ trợ khói được ghi rõ. Chỉ phát một luồng camera; đổi tab, mở trang con hoặc đưa app xuống nền sẽ dừng luồng hình.

Form sửa camera gửi PUT các trường cơ bản, giữ nguyên mật khẩu nguồn nếu URL không đổi và không ghi đè kích thước USB/ngưỡng riêng/xoay ảnh. Form quy tắc gọi điện đọc lại cấu hình để giữ giọng đọc, tốc độ và số lần lặp không có trên form mobile. Lỗi API được hiển thị; không báo lưu thành công chỉ vì bấm nút.

Bản mobile lược bỏ tab kiểm tra API, mô phỏng sự cố, thử model, xem JSON, quét USB, xoá camera và nút gọi khẩn cấp tức thì. Chọn model, ngưỡng nhận diện, cấu hình Gemini nâng cao vẫn thực hiện trên web. Giữ thao tác gọi thử danh bạ đã có với xác nhận của người dùng.

Ảnh kiểm tra bố cục được tạo bằng dữ liệu giả lập tại `build/fireguard-preview/`; không phải ảnh xác nhận trạng thái Pi. Công cụ tạo ảnh: `test/preview_fireguard.dart` (chạy riêng bằng `flutter test test/preview_fireguard.dart --dart-define=GUARD_FONT_DIR=<Flutter SDK>/bin/cache/artifacts/material_fonts`).

## Chi tiết API

- FireEye auth: `POST /api/auth/login`, `GET /api/auth/me`, `POST /api/auth/refresh` (JSON `refresh_token`), `POST /api/auth/logout`. Login gửi `phone_number`, `secret_key`, `system_secret_key`, `device_name`; nhận `token`, `refresh_token`, `expires_in`.
- Cùng token được gửi bằng `Authorization: Bearer ...` tới FireGuard `/api/v1/emergency/...`. FireGuard hiện có sẵn cơ chế kiểm tra tài khoản qua FireEye, nên FireEye phải hoạt động để xác thực. App kiểm tra FireGuard `/auth/me` trước khi mở giám sát; FireGuard offline không có dashboard FireEye thay thế.
- FireGuard cung cấp `/system/info`, `/status`, `/cameras`, `/incidents`, `/incidents/active`, `/contacts`, `/settings/location`. FireEye bổ sung `/api/integration/camera`, `/api/integration/ptz`, `/api/faces/...`, `/api/events`, `/api/notifications/{id}/read`. Lịch sử hai dịch vụ có ID riêng; không trộn sự kiện khuôn mặt vào sự cố cháy FireGuard.
- Camera dùng ID FireGuard và `/cameras/{id}/stream`. Ảnh sự cố dùng `/incidents/{id}/images/{name}` với Bearer header. Không suy diễn ID FireGuard từ Firestore.
- WebSocket: `ws://100.95.189.60:8080/api/v1/emergency/ws?token=...`; HTTPS tự đổi thành WSS. Token query tương thích hợp đồng WebSocket hiện có; app không hiển thị URL chứa token trong lỗi.
- Nhận `incident.created`, `incident.updated`, `incident.analyzed`, `incident.closed`, `call.updated`. Sự cố mới có thông báo trong app và nút mở chi tiết. Các sự kiện cập nhật lại dữ liệu từ FireGuard; chi tiết theo dõi sự cố tương ứng.
- Mất kết nối: tự thử lại với khoảng chờ tăng dần. Sau khi kết nối lại, tải `/incidents/active` và lịch sử để đồng bộ sự cố có thể bỏ lỡ. Trạng thái/dashboard vẫn làm mới mỗi 5 giây khi đang xem.
- Trước khi access token hết hạn, hoặc khi HTTP 401/WebSocket 4401, app thử refresh dùng chung cho hai dịch vụ và thử lại một lần. Các yêu cầu đồng thời chỉ tạo một lần refresh. Refresh 401 mới xóa phiên; lỗi mạng/503 giữ phiên để thử lại. Token dán thủ công không có refresh token.

## Phiên và giới hạn

- URL được lưu, token chỉ giữ trong bộ nhớ và gắn với cặp URL. Đổi thiết bị xóa token; mở lại app cần đăng nhập. Access token 30 phút, phiên refresh tối đa 7 ngày. Đăng xuất gọi server thu hồi phiên rồi xóa phiên app; nếu mạng lỗi, phiên app vẫn được xóa nhưng server chưa chắc nhận được yêu cầu. Cache xác thực FireGuard có thể còn hiệu lực tối đa 30 giây.
- PTZ chỉ dùng cho camera Dahua đã được quản trị viên liên kết đúng device ID/camera ID. Thả nút, rời trang hoặc chạy nền sẽ gửi lệnh dừng sau lệnh bắt đầu. Backend có bộ hẹn giờ gửi dừng sau 1,5 giây và thử lại khi lỗi; không thể bảo đảm camera dừng nếu thiết bị/mạng không đáp ứng. Phải kiểm tra lại liên kết khi đổi nguồn camera.
- Đăng ký khuôn mặt chỉ dành cho OWNER/ADMIN, yêu cầu xác nhận đồng ý và đúng một khuôn mặt. Xóa hồ sơ xóa embedding/ảnh đăng ký và cập nhật cache đối chiếu; ảnh bằng chứng của sự kiện cũ vẫn theo chính sách lưu trữ. Hồ sơ cũ chưa có đồng ý không được dùng đối chiếu.
- WebSocket hoạt động khi luồng giám sát FireGuard đang mở, kể cả lúc vào trang camera/chi tiết/danh bạ. App chạy nền sẽ đóng kết nối, quay lại tự nối và đồng bộ. **Chưa có thông báo nền khi app đóng**; cần hạ tầng push riêng nếu muốn tính năng đó.
- Gemini, Stringee và Hailo đều chạy trên Pi. App hiển thị cấu hình/trạng thái từ API; chưa xác nhận một cuộc gọi thật hay suy luận AI thật chỉ bằng trạng thái “đã cấu hình”.
- Danh bạ/địa chỉ tuân theo quyền `OWNER`/`ADMIN`. Các nút nhận xử lý, đóng sự cố, báo nhầm gọi API FireGuard sẵn có. Nhận xử lý dừng các cuộc gọi tiếp theo, không cam kết ngắt cuộc gọi đang diễn ra.
- Tối đa 50 sự cố gần nhất; chưa đồng bộ Firestore hay quản lý nhiều Pi đồng thời. Mã màn hình Firebase cũ vẫn còn trong dự án nhưng không còn là lối vào mặc định của app. Cần chuyển dữ liệu và tính năng riêng nếu muốn dùng lại trong luồng Pi.

## Kiểm tra

`flutter analyze --no-pub` và `flutter test --no-pub` kiểm tra chia sẻ/refresh/thu hồi phiên, đổi Pi khi còn request, phân quyền, ảnh sự cố, phản hồi gọi thử, đồng ý/xóa khuôn mặt, lịch sử và thứ tự bắt đầu/dừng PTZ. Test WebSocket dùng server localhost để kiểm tra sự kiện, mất mạng/kết nối lại, 4401 và từ chối handshake. Widget test kiểm tra không mở giám sát nếu FireGuard offline. Backend có bộ test API cô lập trong `FireEye/FireEye/tests`, không cần phần cứng.

Kiểm tra trên Pi cần tài khoản hợp lệ: đăng nhập, xem trạng thái `local`/AI/camera, mở luồng camera và quan sát một sự cố thử có `real_calls=false` được chủ hệ thống tạo. Không gọi thật để thử kết nối.
