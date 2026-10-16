# Bàn giao sửa lỗi IGNIVO Mobile

Ngày: 15/10/2026. Phạm vi: sửa app và tài liệu, giữ nguyên FireGuard/FireEye trên Pi.

## Kết quả kiểm tra cuối

| Kiểm tra | Kết quả |
|---|---|
| `flutter test --no-pub` | 96/96 tests pass |
| `flutter analyze --no-pub` | No issues found |
| `flutter build apk --debug --no-pub` | Thành công; APK tại `build/app/outputs/flutter-apk/app-debug.apk` |
| API công khai Pi cấu hình | Đã đọc health FireGuard và OpenAPI hai dịch vụ, HTTP 200 |
| Đăng nhập/refresh với tài khoản Pi thật | Chưa nghiệm thu; cookie/JSON refresh được kiểm thử bằng mock và đối chiếu mã backend local |
| Điện thoại Android | `adb devices` không có thiết bị kết nối; chưa cài APK hoặc thử âm thanh/rung/DND thật |
| iPhone | Chưa nghiệm thu |
| Backend | Không sửa hoặc triển khai backend; FireGuard local sạch, FireEye chỉ có `.testdeps/` untracked đã tồn tại trước lần sửa |

## Các sửa đổi đã thực hiện

- Refresh hỗ trợ request cookie của backend cũ và JSON của backend mobile, nhận token từ JSON hoặc Set-Cookie. Không chuyển cookie sang dịch vụ khác, không follow redirect. Token refresh được xác minh bằng `/api/auth/me` trước khi thay phiên dùng chung; nếu server từ chối thì yêu cầu đăng nhập lại.
- Giữ timestamp server sau ACK để bản cập nhật cũ không khởi động lại còi. ACK cục bộ khác với trạng thái đóng vĩnh viễn; chi tiết server đồng bộ lại mốc ACK.
- Tách sự cố ưu tiên hiển thị và sự cố đang phát âm. Tắt còi không mắc ở sự cố critical đã im lặng; watchdog giới hạn các sự cố đồng thời.
- Polling kiểm tra generation, phiên, origin và foreground trước khi thay coordinator. App resume không phát cache trước khi đồng bộ. ID đang theo dõi vắng trong danh sách giới hạn được đọc chi tiết.
- PTZ yêu cầu status valid, online true, ptz true và revision không rỗng khớp nhau. 404/501 ở endpoint integration trở thành unsupported; không dùng endpoint legacy để bỏ qua kiểm tra binding.
- Bỏ nút gọi thử trong danh bạ và lối vào chỉnh quy tắc gọi PCCC khỏi luồng chính. Các quy tắc tự động trên Pi không bị thay đổi.
- Logout không tạo installation ID mới chỉ để gọi endpoint notification không tồn tại. Registration cũ nếu có vẫn được thử thu hồi với timeout.
- Hiển thị lỗi audio từ adapter trên tổng quan. Tài liệu API được sửa để phân biệt bằng chứng Pi thật, mã local và mock.

## Tests bổ sung

- `mobile_completion_review_test.dart`: cập nhật critical cũ sau ACK; tắt âm nhiều sự cố; watchdog nhiều sự cố.
- `dashboard_resync_test.dart`: polling bị WS vượt trước không ghi đè âm thanh; resume phải đồng bộ ID vắng mặt trước khi phát.
- `legacy_refresh_test.dart`: refresh cookie hợp lệ/không hợp lệ; endpoint integration không tồn tại không fallback.
- `ptz_revision_test.dart`: thiếu status/online/ptz/revision hoặc unavailable đều khóa điều khiển.
- Fixture test PTZ hợp lệ được bổ sung capability/revision đầy đủ; không nới điều kiện app để làm tests xanh.

## Giới hạn phải giữ trong báo cáo

OpenAPI của Pi hiện không công bố `/api/integration/*` và `/notification-devices`: PTZ có binding và push nền chưa khả dụng trong bản app này. Không gọi đây là lỗi đã sửa ở backend.

Backend local có cơ chế tạo jti khi refresh cần kiểm chứng với phiên thực tế. Nếu token mới không được server chấp nhận, app đăng xuất/yêu cầu đăng nhập lại; app không thể sửa session DB hoặc JWT của backend.

Chưa xác nhận tính năng sửa/xóa khuôn mặt, phân quyền từng endpoint, timestamp bằng nhau/thiếu, camera/ảnh thật và chuỗi nhận xử lý trên Pi. Không thực hiện cuộc gọi thật, tạo sự cố hoặc di chuyển camera trong lần sửa này.

Thay đổi theme/main có sẵn khi tiếp tục công việc đã được giữ nguyên và đưa vào APK hiện tại, không được tính là thay đổi giao diện do đợt sửa lỗi này thực hiện. Chưa nghiệm thu trực quan toàn bộ giao diện sáng/tối trên thiết bị thật.

## Nghiệm thu thiết bị còn lại

1. Cài APK debug trên điện thoại thử nghiệm; đăng nhập vào Pi, kiểm tra refresh hoặc thông báo đăng nhập lại nếu server không chấp nhận.
2. Xem ảnh/MJPEG có đăng nhập; xác nhận PTZ unsupported hiển thị đúng trên Pi hiện tại.
3. Dùng môi trường mock hoặc sự cố thử đã được cấu hình không gọi thật để kiểm tra ACK, silence, nhiều sự cố, pause/resume và mất mạng.
4. Kiểm tra âm thật, rung, tắt còi, watchdog, chế độ im lặng/DND; ghi model điện thoại và phiên bản Android.
5. Chỉ xác nhận phát hành sau khi có kết quả các bước trên. APK debug hiện là bản để nghiệm thu, không phải bằng chứng hoàn thành toàn bộ kế hoạch.
