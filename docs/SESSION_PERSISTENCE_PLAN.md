# Kế hoạch lưu phiên đăng nhập IGNIVO

Ngày lập: 17/10/2026. Trạng thái: đề xuất, chưa triển khai.

## Mục tiêu và phạm vi

Cho phép người dùng đóng ứng dụng, khởi động lại điện thoại rồi mở lại IGNIVO mà không nhập lại thông tin đăng nhập, nếu phiên còn hợp lệ. Phạm vi đầu tiên: Android/iOS, một hệ thống Pi đang được cấu hình. Không bao gồm đăng nhập nhiều tài khoản, sinh trắc học hoặc bảo đảm giám sát nền.

Đề xuất tùy chọn “Giữ đăng nhập trên thiết bị này” tại màn hình đăng nhập, mặc định chưa chọn. Thời hạn tối đa ban đầu: 7 ngày tính từ lúc đăng nhập, do server quyết định; gia hạn access token không tự kéo dài vô hạn thời hạn này. Người dùng không chọn vẫn dùng phiên trong RAM.

## Căn cứ trong mã nguồn

- `lib/core/services/system_session_controller.dart`: `initialize()` chỉ khôi phục cấu hình Pi; chưa khôi phục thông tin đăng nhập. `handleSessionExpired()` đã tồn tại nhưng chưa có nơi gọi trong luồng hiện tại.
- `lib/core/services/fireguard_api_service.dart`: token nằm trong RAM; `_load()` chủ động xóa khóa token cũ trong SharedPreferences. `login()` chỉ lấy trường `token`. Có sẵn hooks `beforeRequest`, `renewSession` và stream `sessionChanges` để tích hợp.
- `lib/core/services/fireeye_api_service.dart`: có cơ chế refresh và gộp yêu cầu refresh đồng thời, nhưng luồng chính `AppEntryGate → SystemSessionController → FireguardApiService` chưa kết nối cơ chế này. Không tạo hai bộ quản lý token cùng hoạt động.
- `../FireEye/FireEye/services/auth_service.py`: access token 30 phút, refresh token 7 ngày trong mã nguồn hiện tại. Chưa xác minh cấu hình thực tế trên Pi.
- `../FireEye/FireEye/routes/auth_route.py`: bản ghi session hết hạn theo access token; `/refresh` chỉ nhận cookie, tạo access token với `jti` mới mà không tạo bản ghi session tương ứng, chưa kiểm tra session của refresh token bị thu hồi. Trong khi `/me` yêu cầu `jti` tồn tại và còn hạn trong DB. Cần sửa trước khi sử dụng refresh để lưu phiên lâu dài.
- `../fireguard/app/routers/auth.py`: login chuyển refresh token thành cookie nhưng JSON trả về mobile chỉ có `token`, `user`; chưa có endpoint refresh.
- `../fireguard/app/auth.py`: một số phản hồi lỗi upstream đang bị quy thành 401; cần phân biệt lỗi dịch vụ để tránh xóa nhầm phiên đã lưu.

## Thiết kế đề xuất

Luồng chính thống nhất: Flutter → FireGuard → FireEye. FireEye là nơi cấp, xác minh và thu hồi phiên; FireGuard chuyển tiếp hợp đồng API cho mobile. Controller của app điều phối duy nhất vòng đời phiên và token dùng chung cho API/camera/WebSocket.

- Giữ access token trong RAM. Khi bật giữ đăng nhập, lưu refresh token và metadata tối thiểu trong secure storage: phiên bản định dạng, origin đã chuẩn hóa của hệ thống, định danh phiên, hạn tuyệt đối, device ID nếu đã xác minh được.
- Không lưu mật khẩu, `secret_key`, `system_secret_key`, hoặc dùng thông tin user cache để cấp quyền. SharedPreferences chỉ giữ cấu hình Pi và lựa chọn giao diện không nhạy cảm.
- Dùng abstraction `SessionStore` để dễ kiểm thử; triển khai bằng `flutter_secure_storage`, chọn phiên bản tương thích khi thực hiện. Plugin cung cấp lưu trữ theo nền tảng, gồm Keychain trên iOS và cơ chế bảo vệ khóa trên Android. Xem [tài liệu của dự án](https://github.com/juliansteenbakker/flutter_secure_storage).
- Cấu hình backup/restore Android và Keychain iOS theo phiên bản plugin đã chọn. Lỗi đọc/ghi secure storage không được làm treo app hoặc thông báo sai rằng đã ghi nhớ. Nếu ghi không được, cho phép tiếp tục phiên RAM và thông báo không thể lưu phiên.
- Ràng buộc token với origin đã cấu hình; không chuyển tiếp qua redirect hoặc gửi token của Pi cũ đến Pi mới. Device ID là kiểm tra bổ sung, không thay thế xác minh máy chủ. Dùng HTTPS hoặc mạng riêng được bảo vệ trong triển khai thực tế.

## Thứ tự triển khai

### 1. Sửa vòng đời phiên trên FireEye

- Tách thời hạn access token khỏi thời hạn session/refresh trong DB; lưu thời gian UTC nhất quán.
- Dùng định danh session ổn định để access token mới vẫn được `/me` xác minh và logout thu hồi đúng session.
- `/refresh` hỗ trợ JSON cho mobile và giữ tương thích cookie cho web. Xác minh chữ ký, loại token, hạn, user và session còn hiệu lực trước khi cấp token.
- Đổi refresh token sau mỗi lần dùng thành công; lưu hash định danh/bí mật refresh thay vì token thô. Cập nhật DB nguyên tử để token cũ không dùng lại được; xác định rõ xử lý phát lại và lỗi kết nối sau khi server đã đổi token.
- Login/refresh trả JSON nhất quán: `token`, `refresh_token`, `expires_in`, `refresh_expires_at`, `session_id`; login có `user`. Refresh không làm phiên vượt quá hạn tuyệt đối 7 ngày đã chọn.
- Logout thu hồi cả access/refresh của phiên; hỗ trợ thu hồi bằng refresh credential nếu access đã hết hạn. Phiên bị xóa bởi giới hạn thiết bị cũng không refresh được.
- Có migration DB cho phiên hiện có: không tự nâng các phiên cũ 30 phút thành phiên dài hạn; yêu cầu đăng nhập lại để dùng tính năng mới.

### 2. Hoàn thiện hợp đồng API qua FireGuard

- Truyền các trường token/thời hạn của login về JSON cho mobile; bổ sung `/api/v1/emergency/auth/refresh` và chuyển tiếp logout phù hợp.
- Giữ tương thích cookie và response cũ cho client hiện có.
- Phân biệt 401 do token/phiên không hợp lệ, 403 do thiếu quyền và 503/timeout do dịch vụ hoặc mạng. Lỗi 5xx từ FireEye không được biến thành hết hạn phiên.
- Xóa cache xác thực liên quan khi logout/thu hồi mà FireGuard biết; xác định giới hạn trễ của cache khi thu hồi trực tiếp ở FireEye. Kiểm tra hành vi của kết nối WebSocket đã mở khi phiên bị thu hồi.
- Không ghi token trong log. Không báo đã thu hồi phía server nếu upstream thực tế thất bại.

### 3. Thêm lưu trữ và quản lý phiên phía Flutter

- Thêm `session_store.dart`, implementation secure storage, model dữ liệu phiên và dependency trong `pubspec.yaml` cùng cấu hình Android/iOS.
- Chuyển kết quả login từ boolean/token rời rạc sang dữ liệu phiên có kiểu rõ ràng; lưu refresh credential sau khi `/auth/me` xác minh thành công.
- Một coordinator sở hữu thao tác refresh; tích hợp hooks của `FireguardApiService`, đồng bộ với các client FireEye phụ trợ và WebSocket. Tái sử dụng cơ chế hiện có nếu phù hợp, không để singleton và instance riêng ghi đè token của nhau.
- Refresh trước khi access token hết hạn hoặc một lần sau 401 xác thực. Các request đồng thời chờ cùng một tác vụ refresh. Không tự gửi lại thao tác ghi khi chỉ gặp timeout hoặc kết quả không rõ ràng.
- Sau refresh thành công, cập nhật credential đã lưu trước khi công bố trạng thái ổn định. Dùng revision/generation và hàng đợi lưu trữ để kết quả login/refresh cũ không ghi lại phiên sau logout, đổi Pi hoặc đăng nhập tài khoản khác.
- Giữ việc loại bỏ token plaintext cũ trong SharedPreferences; không phục hồi token từ kho cũ.

### 4. Khôi phục phiên và giao diện

- Thêm trạng thái `restoringSession` và `restoreUnavailable` vào controller. `AppEntryGate` hiển thị “Đang khôi phục phiên…” trong lúc đọc và xác minh.
- Có refresh token đúng hệ thống → gọi refresh → gọi `/auth/me` → cập nhật user/quyền hiện tại → vào `IgnivoShell` và bắt đầu monitoring.
- Không có phiên đã lưu → màn hình đăng nhập như hiện tại.
- Token hết hạn, bị thu hồi hoặc dữ liệu lưu sai định dạng → xóa phiên, thông báo ngắn và yêu cầu đăng nhập.
- Mất mạng/Pi tắt/503 → giữ credential đã lưu, hiển thị “Chưa kết nối được hệ thống” với “Thử lại” và lựa chọn đăng nhập/đổi kết nối. Chưa coi user là authenticated và chưa khởi động giám sát khi chưa xác minh được.
- Bổ sung checkbox giữ đăng nhập và giải thích thời hạn. Trong Cài đặt có lựa chọn bỏ lưu phiên; bỏ lưu chỉ xóa credential lâu dài, phiên RAM hiện tại tiếp tục cho tới khi đăng xuất/hết hạn.
- Cập nhật nội dung hộp thoại đăng xuất đang nói “xóa khỏi RAM” để phản ánh việc xóa cả phiên đã lưu.

### 5. Hoàn thiện các đường kết thúc phiên

- Logout: chặn tác vụ khôi phục/gia hạn mới, xóa credential cục bộ và trạng thái quyền, dừng monitoring/camera/WebSocket; gửi yêu cầu thu hồi server với credential đã chụp trong RAM, timeout hữu hạn. Logout offline vẫn xóa cục bộ, nhưng không khẳng định server đã thu hồi.
- Đổi Pi/ngắt kết nối: vô hiệu hóa tác vụ cũ, xóa credential và binding trước khi cấu hình origin mới.
- Hết hạn/thu hồi: nối `sessionChanges` và kết quả xác thực cuối cùng về controller để giao diện quay lại đăng nhập đúng lúc. 403 của một thao tác riêng không xóa phiên.
- Khi app resume, xác minh/gia hạn theo thời hạn hiện tại, rồi kết nối lại realtime bằng token mới; chưa khôi phục thành công thì không hiển thị giám sát đang hoạt động.

### 6. Kiểm thử và triển khai

- Backend: access mới dùng được ở `/me` qua cả FireEye và FireGuard; refresh sau mốc 30 phút vẫn được trong hạn session; token bị thu hồi, token cũ sau rotation và phiên vượt 7 ngày bị từ chối.
- App: bật/tắt giữ đăng nhập, restart tiến trình, restart điện thoại, token thiếu/hỏng, lỗi secure storage, refresh đồng thời, logout trong lúc refresh và đổi Pi trong lúc restore.
- Lỗi mạng: không xóa phiên khi timeout/503; không vòng lặp refresh; không gửi lại thao tác sự cố/camera chỉ vì timeout; 403 không gây logout.
- Điều hướng: không nháy màn hình login trước khi restore xong; không mở shell khi chỉ có user cache; quyền mới từ `/me` có hiệu lực; realtime/camera nhận token mới.
- Kiểm tra Android/iOS thực tế, gồm backup/restore và cài lại app; phiên cũ không được tự phục hồi nhầm vào cấu hình Pi mới.
- Chạy lại bộ test hiện có về session, entry, API, realtime và monitoring. Bổ sung test hồi quy có ý nghĩa cho các nhánh mới.
- Thứ tự phát hành: FireEye → FireGuard → app. Chỉ bật tùy chọn giữ đăng nhập khi backend xác nhận hỗ trợ hợp đồng mới; Pi cũ vẫn đăng nhập bình thường theo phiên RAM.

## Tiêu chí nghiệm thu

1. Khi bật giữ đăng nhập, mở lại app/khởi động lại điện thoại không cần nhập mật khẩu nếu Pi truy cập được và refresh session còn hợp lệ.
2. Access token hết hạn sau 30 phút vẫn được gia hạn hợp lệ trong thời hạn tối đa của session.
3. Logout, đổi Pi hoặc thu hồi server ngăn khôi phục phiên cũ; response muộn không làm phiên sống lại.
4. Mất mạng không đồng nghĩa với đăng xuất; app không báo đang giám sát khi chưa xác minh được phiên.
5. Không có mật khẩu/mã hệ thống/token plaintext trong SharedPreferences hoặc log.

## Giới hạn của phương án chỉ sửa app

Có thể lưu access token để khôi phục khi token còn hạn, nhưng với backend hiện tại trải nghiệm thường chỉ kéo dài trong cửa sổ 30 phút kể từ login. Đây không đáp ứng mục tiêu giữ đăng nhập nhiều ngày. Đề xuất triển khai trọn luồng backend và mobile nêu trên.
