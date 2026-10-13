# Railway Ubuntu 24.04 VPS (OpenSSH + TCP Proxy)

Triển khai máy chủ ảo **Ubuntu 24.04 LTS** trên [Railway](https://railway.com) với **OpenSSH Server**, kết nối cố định qua **Railway TCP Proxy**.

Tích hợp sẵn môi trường phát triển (Python 3, Node.js, C/C++, git, tmux...) và sẵn sàng mở cổng chạy **API Server / AI Agent** ra internet.

---

## 🔐 Bảo mật (đọc trước khi deploy)

- **Mật khẩu root**: nếu bỏ trống `ROOT_PASSWORD`, container sẽ **tự tạo mật khẩu ngẫu nhiên 24 ký tự** ở lần chạy đầu tiên — xem trong deploy log và lưu lại. Mật khẩu được giữ nguyên qua các lần restart (lưu trong container).
- **SSH key được ưu tiên**: khi bạn nạp `SSH_PUB_KEY`, password auth sẽ **tự động tắt** (chế độ `auto`) — root chỉ đăng nhập được bằng key, chống brute-force hoàn toàn. Muốn ép hành vi cụ thể, đặt `PASSWORD_AUTH=yes|no`.
- Không bao giờ dùng mật khẩu yếu/phổ biến (`123456`, `password`...) — entrypoint sẽ cảnh báo trong log nếu phát hiện.

---

## 🌟 Tính năng

* **SSH Key hoặc Mật khẩu**: ưu tiên đăng nhập bằng SSH key; mật khẩu root chỉ là phương án dự phòng.
* **Mật khẩu ngẫu nhiên**: không đặt `ROOT_PASSWORD` thì tự sinh mật khẩu mạnh, không còn mật khẩu mặc định `123456`.
* **Kết nối cố định qua Railway TCP Proxy**: Host và Port giữ cố định qua các lần redeploy.
* **Chống Sleep & Keep-Alive**: `sleepApplicationStop: false`, `restartPolicyType: ALWAYS`, SSH `ClientAliveInterval 30`.
* **Tự chạy ứng dụng**: đặt `START_COMMAND` để API/Agent tự khởi động cùng container (log tại `/var/log/railway-vps/app.log`).
* **Sẵn sàng chạy API Server / AI Agent**: Python 3, Node.js (LTS) cài sẵn; bind vào `$PORT` (mặc định 8080) để ra public domain Railway.

---

## 🚀 Triển khai trên Railway

### 1. Deploy từ GitHub
1. Railway → **New Project** → **Deploy from GitHub repo**.
2. Chọn repository này (`minhdevtry/railway-vps`).

### 2. Biến môi trường (Variables)

| Biến | Mặc định | Ý nghĩa |
| :--- | :---: | :--- |
| `ROOT_PASSWORD` | *(tự sinh ngẫu nhiên)* | Mật khẩu root cho SSH. Bỏ trống = tạo mật khẩu mạnh 24 ký tự (xem deploy log lần đầu) |
| `SSH_PUB_KEY` | *(trống)* | SSH Public Key — **khuyên dùng**. Có key thì password auth tự tắt |
| `PASSWORD_AUTH` | `auto` | `yes` / `no` / `auto`. `auto` = tắt password khi đã có SSH key |
| `START_COMMAND` | *(trống)* | Lệnh tự chạy khi container khởi động, VD: `uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}` |

### 3. Bật TCP Proxy
1. **Settings** → **Networking** → **TCP Proxy**, thêm cổng `22`.
2. Railway cấp địa chỉ cố định, VD: `roundhouse.proxy.rlwy.net:12345`.

---

## 💻 Kết nối SSH

```bash
ssh root@<TCP_HOST> -p <TCP_PORT>
```

- Nếu dùng SSH key: đăng nhập thẳng không cần mật khẩu (password auth đã tự tắt).
- Nếu dùng mật khẩu: nhập mật khẩu root (bạn đặt trong `ROOT_PASSWORD`, hoặc mật khẩu ngẫu nhiên trong deploy log lần đầu).

---

## 🌐 Chạy API Server / AI Agent ra Internet

**Cách 1 — tự động (khuyên dùng):** đặt biến `START_COMMAND`, ví dụ:

```bash
uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
```

Ứng dụng tự chạy mỗi khi container khởi động. Xem log qua SSH: `tail -f /var/log/railway-vps/app.log`.

**Cách 2 — thủ công:** SSH vào rồi chạy tay (dùng `tmux` để giữ tiến trình sống sau khi thoát SSH).

Sau đó vào **Settings** → **Networking** → **Generate Domain** để lấy public domain (VD: `vps-production.up.railway.app`) — Railway forward về cổng `$PORT` của bạn.

---

## ⚠️ Lưu ý

- Đây là **container, không phải VPS thật**: filesystem bị xóa khi redeploy (restart thường thì giữ nguyên). Dữ liệu quan trọng hãy dùng Railway Volume hoặc lưu ra ngoài.
- Chạy 24/7 tốn usage credit của Railway (tính theo RAM×giờ) — nếu cần box chạy liên tục giá rẻ, thuê VPS thật sẽ kinh tế hơn.
- Đừng bao giờ để password auth mở với mật khẩu yếu trên internet.

---

© MIT License
