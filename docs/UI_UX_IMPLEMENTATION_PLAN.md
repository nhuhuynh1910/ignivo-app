# Implementation plan — cải tiến IGNIVO một Pi

Ngày: 15/10/2026. Trạng thái: kế hoạch triển khai, chưa thực hiện các thay đổi bên dưới.

## 1. Mục tiêu và quyết định kiến trúc

Người dùng chỉ cần hiểu một hệ thống IGNIVO: thiết lập địa chỉ một lần, đăng nhập, xem camera, biết sự cố ở đâu và thực hiện thao tác xử lý. Giữ kiến trúc một Pi, nhiều camera FireGuard và một Dahua PTZ FireEye.

Các quyết định cho đợt này:

- **Nhập một địa chỉ Pi, app sử dụng hai dịch vụ.** Mặc định FireEye cổng 8000, FireGuard cổng 8080; có cấu hình nâng cao cho URL/port khác. Không đổi sang đăng nhập qua FireGuard trong đợt này vì gateway hiện chưa có đầy đủ hợp đồng refresh mobile và các API FireEye.
- **FireEye vẫn là nguồn tài khoản duy nhất trong luồng chính.** Giữ refresh tự động, logout thu hồi phiên, phân quyền và kiểm soát phản hồi đến muộn khi đổi Pi.
- **Giữ yêu cầu mã khóa hệ thống của backend.** Tách cấu hình địa chỉ khỏi form đăng nhập không có nghĩa được bỏ trường xác thực này. Chưa tự lưu mật khẩu, mã khóa hoặc refresh token xuống SharedPreferences.
- **Không bắt buộc Firebase Auth để sử dụng push.** Nếu chọn FCM, giữ Firebase Core/Messaging và xây liên kết thiết bị nhận thông báo với phiên FireEye.
- **Cảnh báo nền là một mốc riêng.** Các cải tiến một Pi không phụ thuộc việc cloud relay đã được triển khai. Không chọn Foreground Service duy trì WebSocket làm phương án mặc định.
- **Không tự động gọi điện thật, xoay camera thật hoặc thay cấu hình Pi trong kiểm thử máy phát triển.** Nghiệm thu phần cứng được thực hiện riêng trên thiết bị đã xác định.

Ngoài phạm vi: tài khoản cloud mới, quản lý nhiều Pi đồng thời, claim thiết bị qua cloud, clip video, gateway một cổng đầy đủ, thay thuật toán nhận diện hoặc chính sách gọi điện hiện tại.

## 2. Luồng đích

```text
Chưa có cấu hình → Thiết lập Pi → Kiểm tra dịch vụ → Đăng nhập IGNIVO
Đã có cấu hình   → Đăng nhập IGNIVO
                                      ↓
                           FireEye xác thực tài khoản
                                      ↓
                           FireGuard kiểm tra phiên
                              ↙                 ↘
                         Thành công          Chưa kết nối
                              ↓                 ↓
                      Tự mở giám sát     Thử lại bằng phiên hiện có
```

Khi phiên hết hạn/thu hồi: chuyển về đăng nhập, giữ cấu hình hệ thống. Khi mất mạng/503: giữ phiên, hiện trạng thái chưa kết nối. Mở lại tiến trình app vẫn cần đăng nhập ở mốc này; “thiết lập một lần” chỉ áp dụng địa chỉ/tên hệ thống.

## 3. Các gói triển khai

| Gói | Nội dung | Repository | Phụ thuộc | Kết quả |
|---|---|---|---|---|
| 0 | Chốt baseline và dữ liệu kiểm thử | Cả ba | Không | Hợp đồng và test hiện tại được ghi nhận |
| 1 | Vị trí sự cố, liên kết PTZ có phiên bản | App + FireEye + FireGuard | 0 | Xử lý hai vấn đề P1 |
| 2 | Thiết lập Pi và đăng nhập đơn giản | App | 0 | Một luồng vào app, phục hồi kết nối một phần |
| 3 | Live, ảnh bằng chứng, chữ lớn, hồ sơ/lịch sử | App | 1–2 để tích hợp | Trải nghiệm một Pi hoàn chỉnh hơn |
| 4 | Điều phối cảnh báo foreground | App | 1–3 | Âm thanh/rung có quy tắc, không phát lặp |
| 5 | Push nền và relay | App + FireGuard + dịch vụ mới | 2, 4; hạ tầng push | Nhận và mở cảnh báo nền |
| 6 | Dọn phụ thuộc, đo build, nghiệm thu | Cả ba | 1–4; quyết định giữ FCM | Bản kiểm thử gọn và tài liệu cập nhật |

Gói 6 có thể thực hiện sau khi chốt dependency push, không cần chờ relay hoạt động; không xóa phần sẽ dùng ở gói 5.

### Gói 0 — Baseline và khả năng tái hiện

**Công việc**

- Ghi nhận thay đổi đang có trong từng repository; không ghi đè mã đang sửa của người dùng.
- Chạy các test liên quan để xác nhận baseline trước khi sửa. Kết quả đã ghi nhận ở lượt trước: 44 test Flutter, 21 test FireEye, 2 test FireGuard; cần xác minh lại khi bắt đầu triển khai.
- Chuyển harness UI tạm trong `build/uiux_review.dart` thành công cụ preview có thể lưu trong `test/`, bổ sung fixture camera_name/area/severity đầy đủ.
- Bổ sung fixture: nhiều camera, phân tích chưa xong, severity high/critical, sự cố mô phỏng, sự cố đã nhận xử lý, lỗi ảnh và FireGuard mất kết nối.

**Đạt khi:** test hiện có không hồi quy; fixture và lệnh render có thể chạy lại mà không cần Pi, tài khoản thật hoặc gọi điện.

### Gói 1 — Vị trí sự cố và liên kết PTZ

**1A. Vị trí và nội dung cảnh báo**

- Hiển thị tên camera, khu vực, loại sự cố, mức độ và thời gian ngay đầu chi tiết; banner sự cố đang mở cũng phải có vị trí.
- Chuẩn hóa nhãn FIRE/SMOKE và severity; khi thiếu dữ liệu dùng “Chưa xác định khu vực”/“Đang đánh giá mức độ”, không hiển thị `null`.
- Giữ rõ sự cố mô phỏng; không để lời mô tả AI là nguồn duy nhất xác định vị trí.

**File chính:** `lib/features/fireguard/incident_page.dart`, `fireguard_page.dart`, `monitor_widgets.dart`; có thể tách hàm trình bày sự cố dùng chung.

**1B. Hợp đồng liên kết PTZ có phiên bản**

1. FireGuard thêm `source_revision` dạng ID ngẫu nhiên không chứa thông tin nguồn vào dữ liệu camera. Tạo mới khi tạo camera và thay revision khi cấu hình nguồn thực tế thay đổi; đổi tên/khu vực/FPS không làm mất liên kết. Mọi đường ghi cấu hình camera phải đi qua cùng logic DB, bao gồm giao diện web. Xóa/tạo lại camera phải có revision khác.
2. FireEye lưu liên kết gồm `guard_device_id`, `guard_camera_id`, `source_revision` và định danh cấu hình camera Dahua của chính FireEye. Định danh không được tiết lộ mật khẩu/URL nguồn. Thay cấu hình nguồn/đích Dahua phải làm liên kết cũ không còn hợp lệ.
3. Khi bind và bắt đầu chuyển động, FireEye kiểm tra revision hiện tại từ FireGuard qua địa chỉ peer do server cấu hình, timeout ngắn và xác thực phù hợp; không tin revision do client gửi là bằng chứng duy nhất, không nhận URL peer tùy ý từ body.
4. Dùng tài khoản phiên hiện tại cho request xác minh peer hoặc cơ chế nội bộ giới hạn tương đương; không mở API camera công khai. Khi peer không truy cập được, từ chối bắt đầu chuyển động với lỗi có thể thử lại.
5. Thêm thao tác hủy/xác minh lại liên kết. Giao diện luôn có “Kiểm tra/liên kết lại camera”, kể cả đã bind. Chỉ cho xác nhận khi hai hình hiện tại đã tải thành công; hình lỗi hoặc ảnh cũ không đủ điều kiện.
6. Lệnh **dừng** của người có quyền vẫn được chấp nhận khi revision đã đổi hoặc xác minh peer thất bại. Giữ watchdog backend và hàng đợi stop sau start; vô hiệu hóa liên kết không được ngăn lệnh dừng.

**API dự kiến**

- FireGuard `GET /api/v1/emergency/cameras`: bổ sung `source_revision`.
- FireEye `GET/PUT /api/integration/camera`: thêm revision và trạng thái `unbound/valid/stale/unavailable`.
- FireEye `DELETE /api/integration/camera`: bỏ liên kết, chỉ OWNER/ADMIN.
- FireEye `POST /api/integration/ptz`: kiểm tra binding hiện hành trước lệnh chuyển động; liên kết cũ trả 409; peer chưa sẵn sàng trả 503. Lệnh stop có đường xử lý riêng như trên.

**File chính:** app `pi_camera_page.dart`, `camera_editor_page.dart`, `fireeye_api_service.dart`; FireGuard `app/db.py`, `app/routers/cameras.py`; FireEye `routes/integration_route.py`, `services/db_service.py`, cấu hình peer và camera.

**Migration:** thêm trường theo hướng không xóa dữ liệu. Binding cũ thiếu revision chuyển thành “Cần xác minh lại”; không tự tin cậy. Triển khai backend trước app; app gặp backend cũ không hỗ trợ revision sẽ tắt PTZ và hướng dẫn cập nhật, vẫn cho xem hình.

**Đạt khi**

- Sự cố có camera/khu vực đúng, kể cả mở từ banner và khi AI chưa phân tích.
- Sau khi cập nhật nguồn qua app hoặc web, lệnh chuyển động dùng binding cũ bị server từ chối. Kiểm thử cả nguồn URL trả về đã che mật khẩu.
- Camera khác ID, khác Pi, nguồn bị xóa/tạo lại, cấu hình Dahua thay đổi và peer offline không thể bắt đầu chuyển động qua binding cũ.
- Stop vẫn hoạt động khi binding hết hiệu lực; kiểm thử mạng bằng mock và nghiệm thu dừng trên Dahua thật riêng.

### Gói 2 — Một luồng thiết lập và đăng nhập

**Công việc**

- Tách `PiSetupPage` khỏi form đăng nhập. Form thiết lập có tên hệ thống, địa chỉ Pi và mục “Kết nối nâng cao” chứa hai URL đầy đủ.
- Dùng `Uri` để xử lý IP/domain/IPv6, scheme, port; không ghép chuỗi tùy tiện. Giữ URL HTTPS/port tùy chỉnh khi người dùng chọn chế độ nâng cao.
- Migrate hai URL đang lưu sang một connection profile có version. Nếu hai URL không theo cùng host/port mặc định, giữ nguyên dưới dạng cấu hình nâng cao; không tự ghi đè.
- Form đăng nhập hiển thị tên hệ thống, số điện thoại, mật khẩu, mã khóa hệ thống, nút hiện/ẩn mật khẩu và hành động sửa kết nối. Dán token nằm trong công cụ nâng cao, nêu rõ không có refresh nếu chỉ dán access token.
- Tách trạng thái `loadingProfile → needsSetup → signedOut → authenticating → checkingMonitor → ready/degraded`. Tránh nhiều bool làm UI hiển thị trạng thái không nhất quán.
- Tự điều hướng vào dashboard khi cả hai dịch vụ chấp nhận phiên, chỉ mở một route. Back không quay lại form còn mật khẩu; logout trở về đăng nhập.
- FireEye thành công nhưng FireGuard lỗi mạng/503: giữ phiên, hiện “Đã đăng nhập — chưa kết nối giám sát” và nút thử lại chỉ gọi kiểm tra giám sát. 401 thử refresh như hiện tại; refresh bị từ chối mới yêu cầu đăng nhập lại.
- Giữ cơ chế chống phản hồi muộn khi đổi Pi/logout; không đưa token, mật khẩu vào log hoặc lỗi hiển thị.

**File chính:** `lib/main.dart`, `features/settings/edge_connection_page.dart`; tạo page/controller/profile nhỏ theo trách nhiệm; `core/services/fireeye_api_service.dart`, `fireguard_api_service.dart`.

**Đạt khi**

- Cài mới → nhập một địa chỉ → đăng nhập → tự mở giám sát.
- Lần mở sau dùng cấu hình đã lưu, không hiện hai URL ở form chính.
- FireGuard offline rồi hoạt động trở lại: thử lại thành công mà không nhập lại mật khẩu.
- URL nâng cao cũ được giữ nguyên; đổi Pi không tái sử dụng phiên cũ.
- Đăng nhập sai, tài khoản bị vô hiệu hóa, refresh hết hạn, mạng chập chờn và bấm liên tiếp không mở trùng màn hình.

### Gói 3 — Live, bằng chứng và khả năng sử dụng

**Live**

- Thứ tự: sự cố đang mở → bộ chọn camera → hình trực tiếp → trạng thái camera/AI → readiness thu gọn → thông số thiết bị.
- Readiness dùng “Có N mục cần kiểm tra”, không ghi “Sẵn sàng” khi còn lỗi; sự cố khẩn cấp không bị thu vào accordion.
- Thêm Pause/Play: dừng HTTP stream và giải phóng subscription/client khi pause; resume tạo kết nối mới. Hiện rõ “Đã tạm dừng” nếu giữ ảnh cuối. Không dừng AI hoặc realtime cảnh báo khi pause hình.
- Đi nền, đổi camera/route/tab vẫn tuân theo lifecycle hiện có; không tạo nhiều luồng hình đồng thời.

**Bằng chứng**

- Thay Future ảnh cố định bằng trạng thái tải có retry. Refresh trang tải lại cả ảnh lỗi; dùng generation để bỏ kết quả request cũ.
- Thêm “Tải lại ảnh”, xem toàn màn hình và pinch-to-zoom. Giữ Bearer header, không nhúng token vào URL và không tự cache ảnh nhạy cảm ra file công khai.

**Form, hồ sơ, lịch sử**

- Sửa dropdown lịch sử với chiều rộng co giãn, nhãn dài và menu dùng được ở chữ lớn.
- Đưa danh sách người tham gia lên trước; mở form đăng ký ở trang riêng. Giữ consent và xác nhận xóa, kể cả thông báo về bằng chứng lịch sử.
- Dùng tên nghiệp vụ dễ hiểu, vẫn giữ nguồn dữ liệu/ID riêng. Chưa hợp nhất phân trang hai backend thành một timeline trong đợt này.
- Chuẩn hóa tiếng Việt, thời gian và trạng thái. Parse timestamp theo hợp đồng backend; không tự coi timestamp thiếu timezone là UTC. Nếu đổi API sang ISO8601 có offset phải duy trì khả năng đọc dữ liệu cũ.

**File chính:** `fireguard_page.dart`, `mjpeg_stream_view.dart`, `incident_page.dart`, `eye_events_page.dart`, `people_page.dart`, `monitor_widgets.dart`, cấu hình locale trong `main.dart`/`pubspec.yaml` nếu cần.

**Đạt khi**

- Với camera được cấu hình và không có banner khẩn cấp, vùng live xuất hiện ở viewport đầu 360×640, chữ mặc định.
- Tăng chữ 150% và 200%, mở bàn phím: không overflow và tất cả thao tác vẫn cuộn tới/bấm được; không bắt buộc toàn bộ hình camera phải nằm trong viewport khi chữ lớn.
- Ảnh lỗi một lần rồi mạng hồi phục: retry/refresh tải thành công ngay trong trang.
- Pause đóng request hình; cảnh báo vẫn nhận được; resume hiển thị hình mới, không nhân đôi stream.
- Đăng ký/xóa hồ sơ vẫn giữ phân quyền và consent như trước.

### Gói 4 — Âm thanh/rung foreground

**Công việc**

- Tạo `IncidentAlertCoordinator` ở phạm vi phiên hệ thống, không gắn âm thanh vào riêng một widget/dashboard. Tách chính sách sự kiện khỏi adapter phát âm thanh/haptic để kiểm thử.
- Nhận cả `incident.created`, `incident.analyzed`, `incident.updated`, `incident.closed` và kết quả đồng bộ khi reconnect.
- Chính sách mặc định đề xuất:
  - Created thật, chưa có severity: hiển thị vị trí và “Đang phân tích”, phát tín hiệu ngắn một lần.
  - Chuyển sang high/critical và còn đang mở: tín hiệu khẩn cấp nổi bật, có vòng phát giới hạn và hành động tắt rõ ràng.
  - AI chưa phân tích được: giữ trạng thái “Chưa xác định mức độ”, không chuyển thành an toàn hoặc im lặng chỉ vì severity null.
  - Mô phỏng: chỉ banner mặc định; âm báo thử phải do người dùng chủ động bật trong chế độ kiểm thử.
  - Đã nhận xử lý/đóng/báo nhầm: dừng tín hiệu tương ứng. Sự kiện cũ đến sau không được khởi động lại tín hiệu.
- Dedupe theo system ID + incident ID + lần chuyển mức độ; reconnect không phát lại cùng cấp. Sự cố mới vẫn cảnh báo; thay đổi mức độ sau khi người dùng tắt âm phải tuân theo chính sách ghi rõ trong UI và được test.
- “Tắt âm trên điện thoại” chỉ ảnh hưởng thiết bị này, không gọi ACK/resolve, không ngăn Stringee. “Nhận xử lý” vẫn là thao tác nghiệp vụ riêng.
- Dùng adapter/phụ thuộc âm thanh phù hợp Android/iOS sau khi đánh giá bản SDK hiện tại; không ép âm lượng hệ thống lên tối đa. Cho biết khi quyền/thao tác hệ điều hành khiến âm báo không khả dụng.

**File chính:** `fireguard_realtime_service.dart`, `fireguard_page.dart`, `incident_page.dart`; tạo coordinator và audio adapter; assets âm thanh có quyền sử dụng; cấu hình native nếu thư viện yêu cầu.

**Đạt khi**

- Created severity null → analyzed high chỉ kích hoạt từng mức theo đúng chính sách; không đợi created có severity.
- Duplicate/out-of-order, reconnect, nhiều sự cố và đổi Pi không phát lặp hoặc phát âm của phiên cũ.
- Tắt âm không gửi API nhận xử lý. ACK/close cập nhật từ thiết bị khác làm dừng âm sau đồng bộ.
- Unit/widget test dùng audio mock; nghiệm thu âm thanh/rung, nút tắt, chế độ im lặng và quyền trên điện thoại thật.

### Gói 5 — Push nền qua relay

**Thiết kế đích**

```text
FireGuard → outbox bền vững → HTTPS relay → FCM/APNs → điện thoại
App → API Pi có xác thực → đăng ký/thu hồi thiết bị nhận push tại relay
```

**Các quyết định cần chốt trước khi triển khai hạ tầng**

- Firebase project dùng cho thông báo, môi trường staging/production và nơi chạy relay.
- Android trước hay Android + iOS; iOS cần bundle/provisioning/APNs phù hợp.
- Tên miền HTTPS, tài khoản vận hành relay, retention và mức thông tin được hiện trên màn hình khóa.
- Dịch vụ relay mới được đặt ở repository nào. Mặc định thiết kế một service nhỏ có database/queue; chưa chọn nhà cung cấp hosting trong kế hoạch này.

Các quyết định trên không cản triển khai gói 1–4. Không tạo cloud resource hoặc đưa credential vào repository trong bước lập kế hoạch.

**Công việc backend**

- Không dựa hoàn toàn vào webhook hiện có: `app/realtime.py` hiện retry ba lần trong task bộ nhớ, chưa có outbox sống qua restart.
- Thêm event ID, version/sequence theo incident và outbox giao dịch cùng thay đổi trạng thái; dispatcher có retry/backoff, TTL, ghi nhận lỗi và tiếp tục sau restart. Relay xử lý idempotent; không hứa exactly-once qua mạng.
- Xác minh HMAC trên raw body, định danh Pi được provision phía server, timestamp và chống replay. Không tin system/user ID tự khai báo từ app.
- Bổ sung API đăng ký/thu hồi installation FCM token dưới quyền phiên hiện tại. Server lấy user/session từ xác thực, liên kết với Pi được phép; xử lý token rotation và token invalid.
- Logout, đổi Pi, vô hiệu hóa tài khoản hoặc hết hạn phiên phải thu hồi/cho hết hạn registration. Dùng registration lease và kiểm tra phiên định kỳ để giới hạn trường hợp điện thoại logout khi offline; ghi rõ thời gian tối đa còn hiệu lực trước khi nghiệm thu.
- Payload tối thiểu: event ID, system ID, incident ID, revision và nội dung thông báo theo lựa chọn riêng tư. Không gửi JWT, mật khẩu camera, ảnh khuôn mặt hoặc URL có credential.

**Công việc app**

- Thay phần TODO của `messaging_service.dart` bằng đăng ký qua API Pi; không lưu token vào Firestore mặc định.
- Khởi tạo Firebase Messaging, xử lý permission/token rotation và notification tap khi foreground/background/cold start theo cấu hình nền tảng.
- Đồng bộ với coordinator gói 4: WS và push cùng một sự cố không tạo hai cảnh báo trong app; thiết kế notification identifier/collapse phù hợp để hạn chế bản hiển thị trùng do hệ điều hành.
- Deep link giữ system/incident đích. Nếu chưa đăng nhập thì đi qua đăng nhập rồi mở đúng sự cố; không tự đổi sang Pi khác hoặc hiển thị chi tiết chưa xác thực.
- Push không tạo đường truy cập camera: mở ảnh/live vẫn cần LAN/Tailscale hoặc hạ tầng kết nối đã cấu hình.

**API dự kiến:** `POST/DELETE /api/v1/emergency/notification-devices` cho installation hiện tại; endpoint relay nhận sự kiện và đăng ký được xác thực bởi credential phía Pi. Chốt schema/lease trong một tài liệu hợp đồng trước khi code gói này.

**Đạt khi**

- Nhận thông báo và mở đúng incident trên thiết bị thật ở foreground, background và trạng thái app không chạy thông thường; ghi riêng giới hạn force-stop/quyền bị từ chối của hệ điều hành.
- Pi/relay mất mạng rồi hồi phục: outbox retry, không phát còi cho sự cố đã đóng hoặc thông báo quá TTL; thứ tự phiên bản được bảo toàn khi xử lý trạng thái.
- Không gửi cho sai tài khoản/Pi; thu hồi phiên, token rotation, replay và duplicate đều có test.
- Theo dõi được outbox pending/failure, relay receipt và kết quả gửi provider; không đánh đồng provider chấp nhận với người dùng đã đọc.

**Tài liệu nền tảng cần đối chiếu khi triển khai:** [FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [Android foreground service restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start), [Apple Critical Alerts](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts). Critical Alerts cần quy trình entitlement/quyền riêng, không coi là mặc định của gói này.

### Gói 6 — Dọn mã và đóng gói

- Lập đồ thị import/route từ `main.dart`, kiểm tra test và native plugin trước khi xóa màn hình/service cũ.
- Loại bỏ Firebase Auth, Firestore, Realtime Database, Storage, Google Sign-In chỉ khi đã xác nhận không còn chức năng cần giữ; giữ Core/Messaging nếu chọn gói 5 và local notifications nếu đang dùng.
- Xóa màn hình Firebase cũ không còn route sử dụng sau khi lưu snapshot Git phù hợp; không xóa Firebase project, tài khoản hay dữ liệu cloud.
- Cập nhật cấu hình native, dependency lock và plugin registrant bằng công cụ Flutter, không sửa file generated thủ công.
- Đo cùng loại APK release, cùng ABI và cờ build trước/sau; báo dung lượng thực đo. Không so debug fat APK với release split APK để kết luận mức giảm.
- Cập nhật README, `FIREGUARD_INTEGRATION.md`, `ONE_PI_DEPLOYMENT.md` và trạng thái từng mục trong UI/UX review.

**Đạt khi:** analyzer/test/build phù hợp đều đạt; route chính và push đã chọn không thiếu plugin; có bảng số đo và hướng dẫn triển khai tương ứng.

## 4. Kiểm thử và nghiệm thu chung

| Nhóm | Tình huống bắt buộc | Phương pháp |
|---|---|---|
| Auth | setup migration, một host, URL nâng cao, sai mật khẩu, 401/503, offline một phần, đổi Pi giữa request | Unit/widget + mock HTTP |
| Sự cố | nhiều camera, thiếu area, severity null/high/critical, mô phỏng, đóng từ thiết bị khác | Fixture + widget/event tests |
| PTZ | nguồn sửa qua app/web, legacy binding, peer offline, stop khi revision đổi | API test mock + nghiệm thu camera thật |
| Media | ảnh lỗi rồi retry, refresh, zoom, pause/resume, lifecycle | Widget + kiểm tra subscription/network |
| Layout | 360×640, 390×844, chữ 100/150/200%, bàn phím, nhãn dài | Render + thiết bị thật |
| Trợ năng | nhãn nút, focus, thứ tự đọc, nút stop/ack, lỗi không chỉ dùng màu | Semantics + TalkBack/VoiceOver |
| Alarm | duplicate, out-of-order, reconnect, silence khác ACK, đổi Pi | Unit state machine + audio mock |
| Push | quyền, cold start, rotation, revoke, replay, retry sau restart, WS/push trùng | Integration staging + điện thoại thật |

Không dùng số lượng test làm tiêu chí duy nhất. Mỗi gói cần test cho hành vi thay đổi và các lỗi có thể tái hiện. Không chạy lại toàn bộ kiểm tra đắt tiền nếu không có thay đổi liên quan.

## 5. Mốc bàn giao và thứ tự triển khai

**Mốc A — Một Pi dễ dùng hơn:** gói 0–3. Bàn giao APK debug, API migrations, test/report render và hướng dẫn nâng cấp. Chưa gọi là đã có cảnh báo nền.

**Mốc B — Cảnh báo trong app:** gói 4, nghiệm thu âm thanh/rung trên điện thoại. Chưa cam kết cảnh báo khi app đóng.

**Mốc C — Cảnh báo nền:** gói 5 và cập nhật gói 6, triển khai staging rồi nghiệm thu trước khi bật production.

Triển khai theo thứ tự FireGuard hỗ trợ revision → FireEye kiểm tra binding → app mới. Backup DB/cấu hình trước migration. Nếu cần rollback, giữ PTZ tắt cho tới khi xác minh hợp đồng/binding tương thích; không phục hồi liên kết cũ thành hợp lệ để bỏ qua kiểm tra. Các màn hình đọc dữ liệu vẫn hoạt động khi backend thiếu capability mới, kèm hướng dẫn cập nhật.

Kế hoạch hoàn tất khi từng mốc có bằng chứng test/build, các giới hạn được hiển thị đúng trong app và tài liệu, và các hành vi phần cứng đã được nghiệm thu riêng. Việc viết kế hoạch không đồng nghĩa các chức năng này đã được triển khai.
