# Tương thích IGNIVO Mobile với Pi hiện hữu

Cập nhật: 15/10/2026. Chỉ thay đổi app; không sửa, deploy, restart hoặc thay cấu hình backend.

## Bằng chứng và giới hạn

Đã đọc qua HTTP từ Pi cấu hình `100.95.189.60`:
- FireGuard `:8080/api/v1/emergency/health`: HTTP 200.
- FireEye `:8000/openapi.json` và FireGuard `:8080/openapi.json`: HTTP 200.
- Schema công khai không chứa token hoặc thông tin xác thực. Không đăng nhập, gọi thử, tạo sự cố, quay camera hay sửa dữ liệu Pi trong lần kiểm tra này.
- Đây là kiểm chứng endpoint công khai, không phải nghiệm thu API có đăng nhập hoặc thiết bị thật end-to-end. Fixture/unit tests không thay thế kiểm tra Pi.

## Hợp đồng được app sử dụng

| Chức năng | Bằng chứng / hợp đồng | Hành vi app |
|---|---|---|
| Login | Pi công bố POST `/api/auth/login`; backend local trả JSON token/refresh_token | Một phiên dùng chung, chưa nghiệm thu đăng nhập Pi bằng tài khoản thật |
| Refresh | Pi công bố POST `/api/auth/refresh` không có schema body. Backend local đọc cookie `refresh_token`, trả cookie `access_token` và JSON success | Gửi cookie và JSON đến đúng auth origin, không follow redirect; đọc token từ JSON hoặc Set-Cookie; kiểm tra `/api/auth/me` trước khi thay token |
| Refresh bị backend từ chối | Backend local tạo access token refresh với jti mới; cần nghiệm thu session được server chấp nhận | Nếu `/me` trả 401, xóa phiên và yêu cầu đăng nhập lại; không sửa hoặc giả lập JWT ở app |
| Danh sách/chi tiết sự cố | Pi công bố GET `/incidents`, `/incidents/active`, `/incidents/{incident_id}` dưới `/api/v1/emergency` | Merge danh sách giới hạn; đọc chi tiết ID đang theo dõi nếu vắng mặt; không suy diễn vắng mặt = đã đóng |
| ACK/resolve/false alarm | Pi công bố các POST tương ứng | Chỉ thực hiện khi người dùng thao tác; ACK khác với kết thúc và tắt âm |
| Camera | Pi công bố cameras, snapshot, stream | Dùng MJPEG/ảnh API hiện có; không tuyên bố WebRTC hoặc event clip |
| PTZ có xác minh binding | OpenAPI Pi **không công bố** `/api/integration/camera` hoặc `/api/integration/ptz` | 404/501 chuyển thành unsupported, khóa điều khiển; không fallback sang lệnh PTZ legacy |
| PTZ legacy | Pi công bố `/api/camera/left`, right, up, down, stop... | Không dùng thay thế endpoint binding vì chưa xác minh camera đích và cơ chế bảo vệ |
| Notification registration | OpenAPI Pi **không công bố** `/notification-devices` | Push chưa bật. Logout không tạo installation ID mới; đăng ký cũ nếu có được thử thu hồi có timeout, không hứa đã thu hồi khi lỗi |
| Gọi điện | Pi có endpoint test/call, escalate và settings/escalation | Đã bỏ nút gọi thử và lối vào sửa quy tắc gọi PCCC khỏi luồng mobile chính. Các quy tắc tự động trên Pi không thay đổi |
| Khuôn mặt | Pi công bố faces/register, register-camera, people; không công bố DELETE people/{id} | Luồng chỉnh sửa/xóa và dữ liệu consent còn cần đối chiếu phiên bản Pi; không ghi toàn bộ chức năng đã tương thích |

Prefix FireGuard: `/api/v1/emergency`. WebSocket, quyền từng endpoint, response có đăng nhập và ảnh/stream thật còn cần phiên kiểm thử phù hợp; OpenAPI không đủ chứng minh hành vi thực thi.

## Quy tắc cảnh báo mobile

- Giữ mốc `updated_at` kể cả khi ACK đã xóa sự cố khỏi tập đang phát còi. Bản cập nhật cũ không được mở lại âm thanh; tăng mức sau ACK cần mốc mới hơn.
- Sự cố ưu tiên hiển thị và sự cố đang phát âm được chọn riêng. Tắt âm xử lý sự cố còn phát âm, không mắc ở sự cố critical đã im lặng.
- Watchdog giới hạn toàn phiên âm thanh của các sự cố đồng thời; silence không gửi ACK.
- Polling chỉ áp dụng sau khi kiểm tra generation sự kiện, phiên, origin và foreground. Resume giữ im lặng đến khi đồng bộ mới thành công.
- Snapshot giới hạn được merge. Các ID đang theo dõi nhưng không có trong snapshot được đọc chi tiết; lỗi mạng không được coi là kết thúc.
- `ai_dismissed` là nhận định bổ sung, có thể phân tích lại. App không thay đổi logic gọi của backend.
- Không cam kết thứ tự tuyệt đối nếu backend không cung cấp timestamp/revision đáng tin cậy. Cần kiểm chứng timestamp và các trường hợp bằng nhau trên Pi.

## Trạng thái bàn giao

Xem `MOBILE_ONLY_VERIFICATION.md` để biết kết quả test/analyzer/build của lần sửa hiện tại. Chưa nghiệm thu âm thanh, rung, DND và thao tác xử lý sự cố trên điện thoại thật; chưa khẳng định toàn bộ kế hoạch mobile-only hoàn tất.
