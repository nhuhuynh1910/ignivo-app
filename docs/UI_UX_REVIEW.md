# Rà soát UI/UX IGNIVO — 15/10/2026

## Kết luận

App có đủ cấu trúc cho thử nghiệm một Pi, nhưng còn vấn đề ở việc xác định vị trí sự cố, xác minh lại camera PTZ, phục hồi lỗi và khả năng đọc trên màn hình nhỏ. Nên xử lý các mục P1/P2 dưới đây trước khi giao cho người dùng không chuyên kỹ thuật. Đây là đánh giá mã nguồn và giao diện render bằng dữ liệu giả lập, chưa phải nghiệm thu trên điện thoại/Pi thật.

## Phạm vi và bằng chứng

Đã đọc luồng đang được `main.dart` sử dụng: EdgeConnectionPage → FireguardPage. Các màn hình Firebase cũ không nằm trong luồng này.

Render 9 màn hình/trạng thái: kết nối, trực tiếp, danh sách sự cố, camera, cấu hình, chi tiết sự cố, người tham gia, lịch sử FireEye, PTZ. Chạy ở ba cấu hình:

| Kích thước logic | Cỡ chữ | Kết quả kiểm tra layout |
|---|---|---|
| 390 × 844 | 100% | Không ghi nhận overflow trong các trạng thái render |
| 360 × 640 | 100% | Không ghi nhận overflow; camera nằm dưới vùng nhìn đầu tiên khi thiếu cấu hình |
| 360 × 640 | 150% | RenderFlex overflow bên phải 24 px ở bộ lọc lịch sử FireEye |

Ảnh lưu trong `build/uiux-review/{standard,small,large-text}/`. Harness dùng để rà soát là `build/uiux_review.dart`, tạo từ `test/preview_fireguard.dart`; cả harness và ảnh là artifact tạm, sẽ mất khi xóa thư mục build. Luồng MJPEG trả HTTP 400 do môi trường widget test chặn mạng; đây không phải kết luận Pi đang lỗi. Chưa kiểm tra TalkBack/VoiceOver, bàn phím thật, quyền camera trên máy thật hoặc độ trễ mạng thực tế. Không thay đổi mã sản phẩm trong lần rà soát này.

## Các vấn đề cần sửa

### 1. P1 — Chi tiết cảnh báo thiếu camera và khu vực

`lib/features/fireguard/incident_page.dart:224` chỉ hiển thị trạng thái, trigger_type, severity và thời gian. API đã có camera_name và area, nhưng trang không hiển thị chúng; thanh báo sự cố đang mở cũng chỉ nêu ID/trạng thái. Người dùng mở nhanh một cảnh báo không biết cần đến đâu, nhất là khi hệ thống có nhiều camera. Không thể phụ thuộc vào việc Gemini luôn nhắc lại vị trí trong phần mô tả.

Đề xuất: đặt “Camera phòng khách · Tầng 1” ngay đầu trang, tiếp theo là “Phát hiện lửa · Mức cao”, thời gian theo định dạng địa phương và trạng thái xử lý. Đưa vị trí vào banner cảnh báo. Giữ nút nhận xử lý cố định ở cuối như hiện tại.

Bằng chứng: [chi tiết sự cố](../build/uiux-review/standard/incident-detail.png). Dữ liệu giả lập đã có camera_name/area/severity, nhưng camera và khu vực không được render.

### 2. P1 — Không có luồng xác minh lại liên kết PTZ

`lib/features/fireguard/pi_camera_page.dart:32` xác định đã liên kết chỉ bằng device ID và camera ID. Tại dòng 223, ảnh đối chiếu Dahua và nút liên kết chỉ xuất hiện khi chưa liên kết. Trong khi đó camera editor cho phép thay nguồn nhưng giữ ID (`camera_editor_page.dart:45`). Sau khi đổi nguồn, app có thể hiển thị feed mới và vẫn coi liên kết với Dahua cũ là đúng. Người dùng cũng không có nút xác minh lại tại trang PTZ.

Đề xuất: vô hiệu hóa liên kết khi nguồn camera thay đổi, yêu cầu đối chiếu lại hai hình trước khi bật điều khiển; luôn có thao tác “Kiểm tra/liên kết lại camera”. Cần xử lý đồng bộ ở dữ liệu liên kết và giao diện, không chỉ đổi nhãn nút.

### 3. P2 — Ảnh bằng chứng lỗi không tải lại khi bấm làm mới

`lib/features/fireguard/incident_page.dart:345` giữ Future tải ảnh trong `late final`. Khi request ảnh lỗi mạng, widget chỉ trả dòng lỗi; nút làm mới trang tải lại incident nhưng giữ cùng key/tên ảnh và Future cũ. Vì vậy mạng khôi phục vẫn không tải lại bằng chứng ngay trong trang.

Đề xuất: thêm nút “Tải lại ảnh”, tái tạo request khi làm mới và cung cấp mở toàn màn hình/phóng to để kiểm tra chi tiết. Giữ nguyên quyền xác thực ảnh.

### 4. P2 — Bộ lọc lịch sử bị tràn khi người dùng tăng chữ

Đã tái hiện ở 360 × 640, cỡ chữ 150%: overflow bên phải 24 px. `lib/features/fireguard/eye_events_page.dart:103` dùng DropdownButtonFormField không giới hạn bề rộng nội dung theo không gian còn lại; nhãn dài nhất làm rộng bố cục ngay cả khi đang chọn “Tất cả”.

Đề xuất: dùng `isExpanded: true`, xử lý nhãn nhiều dòng hoặc ellipsis hợp lý và chiều cao menu phù hợp; kiểm tra lại ở 150% và 200%.

Bằng chứng: [ảnh tràn bộ lọc](../build/uiux-review/large-text/eye-events.png), [log](../build/uiux-review/large-text/layout-issues.txt).

### 5. P2 — Tab Trực tiếp dành quá nhiều diện tích cho thông tin phụ

`lib/features/fireguard/fireguard_page.dart:885` chèn toàn bộ bảng readiness trước nội dung live. Ở 360 × 640 với cấu hình chưa hoàn chỉnh, màn hình đầu tiên chỉ chứa trạng thái kết nối, danh sách vấn đề, lời giải thích và card thiết bị; người dùng phải cuộn mới thấy vùng camera. Một số thông báo vẫn cần thiết nhưng thứ tự trình bày làm chậm thao tác chính.

Đề xuất: giữ sự cố khẩn cấp ở đầu; đưa camera ngay sau bộ chọn camera, thu gọn readiness thành một dòng như “4 mục cần kiểm tra” có thể mở rộng. Đưa thông số Hailo/model/nhiệt độ xuống phần tình trạng thiết bị.

Bằng chứng: [tab trực tiếp trên màn hình nhỏ](../build/uiux-review/small/live.png).

### 6. P2 — Kết nối một phần không có thao tác thử lại phù hợp

Trong `lib/features/settings/edge_connection_page.dart:95`, nếu FireEye đăng nhập thành công nhưng FireGuard tạm offline, app xóa mật khẩu/mã hệ thống và không mở dashboard. Giao diện không có nút kiểm tra lại FireGuard bằng phiên còn hợp lệ; người dùng phải nhập lại các trường đăng nhập để đi tiếp sau khi dịch vụ hoạt động trở lại.

Đề xuất: hiển thị riêng “Tài khoản: đã xác thực” và “Giám sát: chưa kết nối”, kèm nút “Thử kết nối lại”. Chỉ yêu cầu nhập lại thông tin khi phiên thực sự hết hạn hoặc bị thu hồi.

### 7. P2 — Màn hình vào app yêu cầu quá nhiều kiến thức kỹ thuật

`lib/features/settings/edge_connection_page.dart:133` giải thích FireEye, FireGuard, Gemini, Stringee, URL, cổng, Tailscale và token ngay trước phần đăng nhập. Người dùng phổ thông phải hiểu kiến trúc backend để bắt đầu. Trên 390 × 844, nút đăng nhập nằm gần cuối màn hình; ở máy nhỏ phải cuộn.

Đề xuất: tách thiết lập kết nối ban đầu khỏi đăng nhập hằng ngày; sau khi thiết lập chỉ hiện tên hệ thống, trạng thái, số điện thoại/mật khẩu và hành động chính. Chuyển URL, token và công cụ kỹ thuật vào “Kết nối nâng cao”. Quét QR/claim có thể bổ sung khi hạ tầng sẵn sàng, không cần chặn cải thiện giao diện hiện tại.

Bằng chứng: [màn hình kết nối](../build/uiux-review/standard/login.png).

### 8. P3 — Nội dung và cách phân nhóm chưa thống nhất

- Màn hình đăng nhập vẫn nói “Token ... Khi hết hạn, đăng nhập lại” (`edge_connection_page.dart:222`) dù luồng đăng nhập tài khoản đã có refresh tự động; cần phân biệt token dán thủ công và phiên tài khoản.
- Chi tiết sự cố hiển thị trực tiếp FIRE/high và timestamp kỹ thuật; nên dịch nhãn và định dạng ngày/giờ thống nhất. App chưa cấu hình locale tiếng Việt nên thời gian dashboard đang render kiểu AM/PM trong môi trường kiểm tra.
- Tên “Lịch sử FireEye” và “Sự cố FireGuard” buộc người dùng hiểu nguồn backend. Có thể tổ chức theo “Cháy/khói”, “Người”, “Thiết bị”, vẫn giữ nguồn/ID tách biệt trong dữ liệu.
- Danh sách người tham gia nằm sau toàn bộ form đăng ký. Khi chữ lớn, người muốn xem/xóa hồ sơ phải cuộn dài. Nên để danh sách trước và mở form từ nút “Thêm người”.

## Những điểm nên giữ

- Bốn tab chính rõ ràng, các thao tác cấu hình phân quyền OWNER/ADMIN.
- Dữ liệu offline, AI chưa có FPS và model không hỗ trợ khói được phân biệt với kết quả mới.
- Nhận xử lý/đóng/báo nhầm nằm cố định cuối trang; đóng và báo nhầm có xác nhận.
- Sự cố mô phỏng được đánh dấu; lịch sử cuộc gọi không đánh đồng kết thúc lượt gọi với đã nghe máy.
- Đăng ký khuôn mặt yêu cầu đồng ý; xóa có xác nhận và giải thích dữ liệu lịch sử còn được giữ.
- App nói rõ giới hạn cảnh báo khi chạy nền.

## Thứ tự xử lý đề nghị

1. Vị trí sự cố và việc xác minh lại PTZ.
2. Khôi phục tải ảnh, khôi phục kết nối một phần, lỗi chữ lớn.
3. Bố cục live và màn hình đăng nhập.
4. Chuẩn hóa nhãn, thời gian và tổ chức lịch sử/hồ sơ.

Sau sửa, kiểm tra trên điện thoại thật với mạng chậm/mất mạng, phiên hết hạn, camera offline, nhiều camera, bàn phím mở và cỡ chữ lớn; nghiệm thu PTZ riêng trên đúng camera đã liên kết.
