# ignivo_app

IGNIVO - Developing a Security and Fire Protection System applying Computer Vision and IoT

## Kết nối hệ thống Pi

Xem [hướng dẫn kết nối](docs/FIREGUARD_INTEGRATION.md) và [triển khai, nghiệm thu một Pi](docs/ONE_PI_DEPLOYMENT.md). FireEye (8000) cung cấp tài khoản/phiên, PTZ Dahua, hồ sơ khuôn mặt có đồng ý và lịch sử FireEye. FireGuard (8080) cung cấp camera, AI cháy/khói, sự cố, cuộc gọi và cảnh báo WebSocket. Cần triển khai đồng bộ các thay đổi trong cả ba repository.

Chạy `flutter run` để mở trực tiếp màn hình đăng nhập hệ thống Pi. App dùng tài khoản FireEye của Pi; không cần tài khoản Firebase. Địa chỉ Tailscale `100.95.189.60` được điền sẵn khi cài mới và có thể đổi trên màn hình đăng nhập.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
