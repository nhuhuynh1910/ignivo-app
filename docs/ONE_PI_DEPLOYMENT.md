# Triển khai và nghiệm thu IGNIVO trên một Pi

Bản này hoàn thiện nền API và luồng mobile để thử nghiệm một Raspberry Pi 5. Kiểm thử trên máy phát triển dùng camera/mạng giả lập; chưa xác nhận Hailo, Dahua, InsightFace hay cuộc gọi thật trên Pi.

## 1. Sao lưu và cấu hình

- Sao lưu SQLite FireEye, thư mục `static/faces`, `static/snapshots`, cấu hình và dữ liệu FireGuard trước khi cập nhật. Không đưa mật khẩu camera, JWT secret, Stringee key vào Git.
- Giữ nguyên `JWT_SECRET_KEY` nếu đang cấu hình. Nếu chưa có, FireEye tạo khóa ngẫu nhiên bền vững tại `data/.jwt-signing-key`; giữ file này qua mỗi lần triển khai và chỉ cho tài khoản dịch vụ đọc. Bản cũ dùng khóa mặc định sẽ phải đăng nhập lại. Không xóa thư mục data khi cập nhật.
- `init_db()` tự thêm cột consent và bảng notification_reads/app_settings, không xóa dữ liệu. Hồ sơ khuôn mặt cũ chưa ghi nhận đồng ý sẽ ngừng được dùng để đối chiếu; chỉ đăng ký lại sau khi người tham gia đồng ý.
- FireEye hiện hỗ trợ một camera Dahua. Cấu hình camera của FireEye phải trỏ đúng camera sẽ được liên kết PTZ trong app. Camera USB hoặc camera khác trong FireGuard không tự có PTZ.
- Dùng LAN tin cậy hoặc Tailscale giữa điện thoại và hai cổng dịch vụ. Không mở API HTTP trực tiếp ra Internet. Với triển khai qua Internet cần thêm HTTPS và thiết kế lại xác thực worker/proxy.

## 2. Cập nhật FireEye

Trong thư mục backend `FireEye/FireEye`, dùng virtualenv đang chạy được trên Pi và cài các dependency cần thiết từ `requirements.txt`. Giữ thư viện Hailo theo bản hệ điều hành đang dùng. OpenCV giới hạn `<5` vì bộ nhận diện khuôn mặt hiện dùng CascadeClassifier. InsightFace/ONNX và model phải được cài riêng theo cấu hình Pi; nếu thiếu, app báo đối chiếu chưa sẵn sàng.

Lệnh chạy API (đưa các tùy chọn tương đương vào ExecStart của dịch vụ hiện có):

```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1 --no-proxy-headers
```

Chạy từ đúng thư mục backend để SQLite, media và signing key được tìm đúng đường dẫn. Chỉ một worker vì luồng camera, cache khuôn mặt và bộ hẹn giờ PTZ nằm trong bộ nhớ tiến trình.

API đọc dữ liệu/media yêu cầu phiên; PTZ, quản lý khuôn mặt, MQTT và sprinkler yêu cầu OWNER/ADMIN. API ghi nhận diện/cảm biến chỉ nhận từ worker nội bộ. FireGuard chạy cùng Pi sử dụng loopback; worker khác phải gửi `X-FireEye-Internal-Key` khớp biến môi trường `FIREEYE_INTERNAL_KEY`. Không đặt reverse proxy loopback trước API theo cấu hình này: loopback được tin cậy và forwarded headers không được dùng để quyết định quyền.

Web/client cũ đăng ký khuôn mặt phải bổ sung `consent=true`. Không mở lại endpoint công khai chỉ để tương thích client cũ. API lỗi giữ trường `detail` và bổ sung `error.code`; validation không trả lại mật khẩu/token đầu vào.

## 3. Cập nhật FireGuard

Triển khai cùng thay đổi `app/auth.py` và `app/services/fireeye.py`: lỗi FireEye 5xx trở thành 503 thay vì đăng xuất nhầm; worker gửi internal key khi cấu hình. Trong môi trường chạy dịch vụ:

```dotenv
FIREEYE_BASE_URL=http://127.0.0.1:8000
DETECTION_SOURCE=local
DETECTOR_BACKEND=hailo
```

Nếu dùng internal key, đặt cùng giá trị `FIREEYE_INTERNAL_KEY` trong **môi trường tiến trình** của hai dịch vụ (không ghi giá trị thật vào tài liệu). Trường hợp cùng Pi qua loopback không cần key này.

Hailo chỉ được một worker nhận diện cháy sử dụng. Dừng `fireeye-ai-worker.service`, giữ API FireEye chạy; sau đó restart FireGuard. Repository có `sudo bash deploy/switch-source.sh local` để chuyển nguồn nếu các tên dịch vụ trên đúng với Pi và `.env` đã có dòng DETECTION_SOURCE. Kiểm tra log và trạng thái sau khi chuyển, không suy ra Hailo hoạt động chỉ từ việc dịch vụ đã khởi động. Worker đối chiếu khuôn mặt FireEye chạy CPU, bật riêng từ app và theo dõi nhiệt độ/FPS khi nghiệm thu.

## 4. Cài app và đi hết luồng

```bash
flutter pub get
flutter build apk --debug
```

APK kiểm thử: `build/app/outputs/flutter-apk/app-debug.apk`. Bản phát hành cần cấu hình signing riêng. Android dùng AGP 8.9.1 / Gradle 8.11.1 để đáp ứng thư viện image picker; [bảng tương thích chính thức](https://developer.android.com/build/releases/agp-8-9-0-release-notes) yêu cầu Gradle 8.11.1 cho AGP 8.9.

1. Kết nối điện thoại với mạng có thể truy cập Pi. Nhập URL FireEye:8000 và FireGuard:8080, tài khoản/mật khẩu/mã hệ thống; mở tổng quan sau khi hai dịch vụ chấp nhận phiên.
2. Kiểm tra bảng sẵn sàng: nguồn `local`, camera online, FPS AI mới, model đúng, địa chỉ/danh bạ, Gemini/Stringee. “Đã cấu hình” không chứng minh đã suy luận hoặc gọi thành công. Thiết lập địa chỉ và người liên hệ bằng OWNER/ADMIN.
3. Mở live một camera. Tắt nguồn camera thử, xác nhận app báo mất hình/dữ liệu cũ; khôi phục và tải lại. Đưa app xuống nền rồi quay lại để kiểm tra đồng bộ.
4. Trong Camera, mở PTZ. So sánh live FireGuard với ảnh Dahua FireEye rồi xác nhận cùng camera. Thử nhấn ngắn, thả, rời trang, đưa app xuống nền và mất mạng để quan sát dừng. Bộ hẹn giờ backend là cơ chế dự phòng, không thay thế xác nhận hành vi trên camera thật. Sau khi đổi nguồn/thiết bị phải đối chiếu và liên kết lại trước khi dùng.
5. Trong Cấu hình → hồ sơ khuôn mặt, lấy sự đồng ý, nhập tên và chọn một ảnh rõ có một khuôn mặt (thư viện/camera điện thoại/camera Pi). Bật đối chiếu khi API báo sẵn sàng; xem sự kiện trong lịch sử FireEye. Xóa thử hồ sơ, xác nhận không còn được đối chiếu. Bằng chứng sự kiện cũ được lưu riêng theo chính sách retention.
6. Chủ hệ thống tạo sự cố mô phỏng có `real_calls=false` bằng công cụ FireGuard. App phải báo sự cố khi đang mở, mở được ảnh, nhận xử lý, đóng/báo nhầm và tìm lại trong lịch sử. Nhận xử lý ngăn lượt gọi tiếp theo, không cam kết ngắt cuộc gọi đã bắt đầu. “Đã kết thúc lượt gọi” không đồng nghĩa người nhận đã nghe.
7. Giữ app hơn 30 phút để kiểm tra refresh, thử ngắt/kết nối mạng; logout rồi thử lại token cũ phải bị từ chối (FireGuard có cache tối đa 30 giây). Thử STAFF: đọc được dữ liệu nhưng không sửa cấu hình, PTZ hoặc hồ sơ khuôn mặt.

Không gọi điện thật để kiểm tra kết nối. Nếu cần nghiệm thu cuộc gọi thật, chủ hệ thống phải phối hợp người nhận trước khi dùng nút gọi thử có xác nhận.

## 5. Kiểm tra hồi quy và giới hạn

```bash
# Trong ignivo-app
flutter analyze --no-pub
flutter test --no-pub

# Trong FireEye/FireEye, virtualenv kiểm thử riêng
python -m pip install -r requirements-test.txt
python -m pytest tests -q

# Trong fireguard, virtualenv có các dependency của dịch vụ
python -m unittest discover -s tests -v
```

Bộ test mới dùng SQLite/media tạm và mock camera/mạng; không chạy lifespan điều khiển thiết bị. Không dùng script `test_auth_api.py` cũ để thay thế vì nó không cô lập dữ liệu như bộ test mới.

Phạm vi hiện tại: một Pi mỗi phiên, nhiều camera FireGuard nhưng một Dahua PTZ, live MJPEG, ảnh bằng chứng, cảnh báo khi app đang mở, hai lịch sử và hồ sơ khuôn mặt có đồng ý. Chưa có claim/pair qua cloud, quản lý nhiều Pi đồng thời, push khi app đóng, clip video ngắn hoặc đồng bộ Firestore. Đăng ký hồ sơ có checkbox là bước ghi nhận của quản trị viên; cần quy trình giải thích và lưu bằng chứng đồng ý phù hợp khi triển khai thực tế.
