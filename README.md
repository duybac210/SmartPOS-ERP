# SmartPOS ERP

Ứng dụng quản lý kho hàng MVP xây dựng bằng Flutter + Firebase (Firestore).

## Tính năng

- **Danh sách sản phẩm** — realtime stream, hiển thị tồn kho
- **Thêm sản phẩm** — có quét barcode bằng camera để điền SKU tự động
- **Nhập hàng (Purchase Receipt)** — tạo phiếu nhập draft → thêm dòng hàng → xác nhận → tồn kho tự động cập nhật

## Cách chạy

### Yêu cầu

- Flutter SDK >= 3.11.3
- Android SDK (target Android 7.0+) hoặc iOS 12+
- Firebase project với Firestore được cấu hình

### Bước chạy

```bash
flutter pub get
flutter run
```

> **Lưu ý**: Cần có file `google-services.json` (Android) tại `android/app/` và `GoogleService-Info.plist` (iOS) tại `ios/Runner/` từ Firebase Console.

## Cấu trúc Firestore

### Collection `products`

| Field   | Type   | Mô tả                        |
|---------|--------|------------------------------|
| name    | string | Tên sản phẩm                 |
| sku     | string | Mã SKU / barcode             |
| price   | number | Giá bán                      |
| stock   | number | Tồn kho hiện tại (default 0) |

### Collection `purchase_receipts`

| Field       | Type      | Mô tả                              |
|-------------|-----------|-------------------------------------|
| code        | string    | Mã phiếu (PN-YYYYMMDD-HHMMSS)      |
| status      | string    | `draft` / `confirmed` / `cancelled` |
| note        | string?   | Ghi chú (tuỳ chọn)                  |
| totalQty    | number    | Tổng số lượng tất cả dòng hàng      |
| totalAmount | number    | Tổng tiền tất cả dòng hàng          |
| createdAt   | timestamp | Thời điểm tạo phiếu                 |
| updatedAt   | timestamp | Thời điểm cập nhật gần nhất         |
| confirmedAt | timestamp | Thời điểm xác nhận (nếu có)         |

### Subcollection `purchase_receipts/{receiptId}/items`

| Field        | Type   | Mô tả                         |
|--------------|--------|-------------------------------|
| productId    | string | ID sản phẩm trong `products`  |
| skuSnapshot  | string | SKU tại thời điểm nhập        |
| nameSnapshot | string | Tên SP tại thời điểm nhập     |
| qty          | number | Số lượng nhập                 |
| importPrice  | number | Giá nhập                      |
| lineTotal    | number | qty × importPrice             |

## Cấu trúc code

```
lib/
├── models/
│   ├── product_model.dart
│   ├── purchase_receipt_model.dart
│   └── purchase_item_model.dart
├── services/
│   └── database_service.dart        # Tất cả Firestore operations
├── screens/
│   ├── inventory/
│   │   ├── product_list_screen.dart  # Home + Drawer navigation
│   │   ├── add_product_screen.dart   # Thêm SP + quét barcode
│   │   └── barcode_scanner_screen.dart
│   └── purchase/
│       ├── purchase_list_screen.dart # Danh sách phiếu nhập
│       ├── purchase_detail_screen.dart # Chi tiết + confirm
│       └── add_purchase_item_screen.dart # Thêm dòng hàng
└── main.dart
```

## Roadmap (sau MVP)

- [ ] Quản lý nhà cung cấp (Suppliers)
- [ ] FIFO / Lot tracking
- [ ] Báo cáo tồn kho
- [ ] Tích hợp POS bán hàng
