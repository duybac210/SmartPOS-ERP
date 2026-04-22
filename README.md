# SmartPOS ERP

Ứng dụng quản lý bán hàng & kho hàng xây dựng bằng Flutter + Firebase (Firestore).

## Tính năng

### Quản lý sản phẩm & kho
- **Danh sách sản phẩm** — realtime stream, hiển thị tồn kho, lọc theo danh mục
- **Thêm / chỉnh sửa / xoá sản phẩm** — kèm phân loại danh mục
- **Danh mục sản phẩm** — CRUD danh mục, gắn vào sản phẩm
- **Điều chỉnh tồn kho thủ công** — kiểm kê, bù trừ chênh lệch (tăng/giảm) kèm lý do

### Nhập hàng
- **Phiếu nhập hàng** — draft → confirm → cancel; gắn nhà cung cấp
- **Quản lý nhà cung cấp** — CRUD, hiển thị trên phiếu nhập

### Bán hàng (POS)
- **Đơn bán hàng** — tạo đơn, thêm sản phẩm từ tìm kiếm realtime, swipe-to-delete dòng hàng
- **Khách hàng** — CRUD, tích điểm và tổng chi tiêu tự động cập nhật sau mỗi đơn
- **Chiết khấu** — nhập số tiền chiết khấu trực tiếp trên đơn
- **Phương thức thanh toán** — tiền mặt / chuyển khoản / thẻ
- **Xác nhận thanh toán** — trừ tồn kho tự động, cộng điểm khách hàng

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

| Field        | Type   | Mô tả                        |
|--------------|--------|------------------------------|
| name         | string | Tên sản phẩm                 |
| sku          | string | Mã SKU                       |
| price        | number | Giá bán                      |
| stock        | number | Tồn kho hiện tại             |
| categoryId   | string | ID danh mục (tuỳ chọn)       |
| categoryName | string | Tên danh mục (snapshot)      |

### Collection `categories`

| Field       | Type   | Mô tả        |
|-------------|--------|--------------|
| name        | string | Tên danh mục |
| description | string | Mô tả        |

### Collection `suppliers`

| Field   | Type      | Mô tả              |
|---------|-----------|--------------------|
| name    | string    | Tên nhà cung cấp   |
| phone   | string?   | Số điện thoại      |
| email   | string?   | Email              |
| address | string?   | Địa chỉ            |
| createdAt | timestamp | Ngày tạo         |

### Collection `purchase_receipts`

| Field        | Type      | Mô tả                               |
|--------------|-----------|--------------------------------------|
| code         | string    | Mã phiếu (PN-YYYYMMDD-HHMMSS)       |
| status       | string    | `draft` / `confirmed` / `cancelled`  |
| supplierId   | string?   | ID nhà cung cấp                      |
| supplierName | string?   | Tên NCC (snapshot)                   |
| note         | string?   | Ghi chú                              |
| totalQty     | number    | Tổng số lượng                        |
| totalAmount  | number    | Tổng tiền                            |
| createdAt    | timestamp | Thời điểm tạo                        |
| updatedAt    | timestamp | Thời điểm cập nhật                   |
| confirmedAt  | timestamp | Thời điểm xác nhận                   |

### Subcollection `purchase_receipts/{id}/items`

| Field        | Type   | Mô tả              |
|--------------|--------|--------------------|
| productId    | string | ID sản phẩm        |
| skuSnapshot  | string | SKU tại thời điểm  |
| nameSnapshot | string | Tên SP tại thời điểm|
| qty          | number | Số lượng nhập      |
| importPrice  | number | Giá nhập           |
| lineTotal    | number | qty × importPrice  |

### Collection `stock_adjustments`

| Field               | Type      | Mô tả                          |
|---------------------|-----------|--------------------------------|
| productId           | string    | ID sản phẩm                    |
| productNameSnapshot | string    | Tên SP tại thời điểm           |
| delta               | number    | Dương = tăng, âm = giảm        |
| reason              | string    | Lý do điều chỉnh               |
| note                | string?   | Ghi chú                        |
| adjustedAt          | timestamp | Thời điểm điều chỉnh           |

### Collection `customers`

| Field      | Type      | Mô tả                   |
|------------|-----------|-------------------------|
| name       | string    | Tên khách hàng          |
| phone      | string?   | Số điện thoại           |
| email      | string?   | Email                   |
| address    | string?   | Địa chỉ                 |
| points     | number    | Điểm tích luỹ           |
| totalSpent | number    | Tổng tiền đã chi        |
| createdAt  | timestamp | Ngày tạo                |

### Collection `sale_orders`

| Field         | Type      | Mô tả                              |
|---------------|-----------|------------------------------------|
| code          | string    | Mã đơn (HD-YYYYMMDD-HHMMSS)        |
| status        | string    | `draft` / `paid` / `cancelled`     |
| customerId    | string?   | ID khách hàng                      |
| customerName  | string?   | Tên khách (snapshot)               |
| totalQty      | number    | Tổng số lượng                      |
| totalAmount   | number    | Tổng tiền trước chiết khấu         |
| discount      | number    | Số tiền chiết khấu                 |
| finalAmount   | number    | Thành tiền (totalAmount - discount)|
| paymentMethod | string    | `cash` / `transfer` / `card`       |
| note          | string?   | Ghi chú                            |
| createdAt     | timestamp | Thời điểm tạo                      |
| updatedAt     | timestamp | Thời điểm cập nhật                 |
| paidAt        | timestamp | Thời điểm thanh toán               |

### Subcollection `sale_orders/{id}/items`

| Field         | Type   | Mô tả                     |
|---------------|--------|---------------------------|
| productId     | string | ID sản phẩm               |
| nameSnapshot  | string | Tên SP tại thời điểm bán  |
| priceSnapshot | number | Giá bán tại thời điểm bán |
| qty           | number | Số lượng                  |
| lineTotal     | number | qty × priceSnapshot       |

## Cấu trúc code

```
lib/
├── models/
│   ├── product_model.dart
│   ├── category_model.dart
│   ├── supplier_model.dart
│   ├── purchase_receipt_model.dart
│   ├── purchase_item_model.dart
│   ├── stock_adjustment_model.dart
│   ├── customer_model.dart
│   ├── sale_order_model.dart
│   └── sale_item_model.dart
├── services/
│   └── database_service.dart        # Tất cả Firestore operations
├── screens/
│   ├── inventory/
│   │   ├── product_list_screen.dart        # Home + Drawer navigation
│   │   ├── add_product_screen.dart         # Thêm / sửa SP + chọn danh mục
│   │   ├── stock_adjustment_list_screen.dart
│   │   └── add_stock_adjustment_screen.dart
│   ├── category/
│   │   ├── category_list_screen.dart
│   │   └── add_category_screen.dart
│   ├── supplier/
│   │   ├── supplier_list_screen.dart
│   │   └── add_supplier_screen.dart
│   ├── purchase/
│   │   ├── purchase_list_screen.dart
│   │   ├── purchase_detail_screen.dart
│   │   └── add_purchase_item_screen.dart
│   ├── customer/
│   │   ├── customer_list_screen.dart
│   │   └── add_customer_screen.dart
│   └── sales/
│       ├── sale_list_screen.dart
│       ├── create_sale_screen.dart         # POS cart
│       └── sale_detail_screen.dart
└── main.dart
```

## Roadmap (sau MVP)

- [ ] Báo cáo doanh thu / lợi nhuận
- [ ] FIFO / Lot tracking
- [ ] Đổi trả hàng (Return Order)
- [ ] Xác thực người dùng + phân quyền

