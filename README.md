# Railway Ubuntu 24.04 VPS (OpenSSH + TCP Proxy)

Triển khai máy chủ ảo **Ubuntu 24.04 LTS** trên [Railway](https://railway.com) với **OpenSSH Server**, hỗ trợ kết nối cố định qua **Railway TCP Proxy** và đăng nhập trực tiếp bằng **mật khẩu root**.

Tích hợp sẵn môi trường phát triển (Python 3, Node.js, C/C++, git, tmux...) và sẵn sàng mở cổng chạy **API Server / AI Agent** ra internet.

---

## 🌟 Tính năng nổi bật
* **Đăng nhập bằng Mật khẩu**: Đăng nhập `root` trực tiếp bằng mật khẩu (không bắt buộc dùng SSH Key).
* **Kết nối cố định qua Railway TCP Proxy**: Host và Port TCP Proxy được giữ cố định qua các lần redeploy.
* **Chống Sleep & Giữ kết nối (Keep-Alive)**:
  * Đã bật cấu hình `sleepApplicationStop: false` và `restartPolicyType: ALWAYS` để container chạy liên tục 24/7.
  * Cấu hình OpenSSH `ClientAliveInterval 30` & `TCPKeepAlive yes` giữ phiên SSH luôn sống, không bị timeout đứt kết nối.
* **Sẵn sàng chạy API Server / AI Agent**: Cài sẵn **Python 3** và **Node.js (LTS)**. Khi chạy service trên cổng `PORT` (mặc định 8080), bạn có thể truy cập qua public domain của Railway.

---

## 🚀 Hướng dẫn Triển khai trên Railway

### 1. Deploy từ GitHub
1. Đăng nhập vào [Railway](https://railway.com/) → **New Project** → **Deploy from GitHub repo**.
2. Chọn repository này (`minhdevtry/railway-vps`).

### 2. Cấu hình biến môi trường (Variables)
Trong tab **Variables** của service trên Railway:

| Biến | Mặc định | Ý nghĩa |
| :--- | :---: | :--- |
| `ROOT_PASSWORD` | `123456` | Mật khẩu root để đăng nhập SSH (khuyên đổi mật khẩu của riêng bạn) |
| `SSH_PUB_KEY` | *(Trống)* | SSH Public Key (tùy chọn, nếu muốn đăng nhập tự động không cần mật khẩu) |

### 3. Bật TCP Proxy để lấy Port SSH cố định
1. Vào mục **Settings** → phần **Networking**.
2. Nhấn **TCP Proxy** và thêm cổng `22`.
3. Railway sẽ cấp cho bạn một địa chỉ cố định, ví dụ:
   * **Host:** `roundhouse.proxy.rlwy.net`
   * **Port:** `12345`

---

## 💻 Cách kết nối SSH

Từ Terminal trên máy tính của bạn:
```bash
ssh root@<TCP_HOST> -p <TCP_PORT>
```
*Ví dụ:*
```bash
ssh root@roundhouse.proxy.rlwy.net -p 12345
```
Nhập mật khẩu root (mặc định `123456` hoặc mật khẩu bạn đặt trong `ROOT_PASSWORD`), bạn sẽ vào thẳng shell của VPS!

---

## 🌐 Chạy API Server / AI Agent ra Internet

Nếu bạn muốn mở API server (FastAPI, Flask, Express, Agent UI, v.v.):

1. Trong tab **Settings** → **Networking** trên Railway, nhấn **Generate Domain** (ví dụ: `vps-production.up.railway.app`).
2. Trong VPS, khởi chạy ứng dụng của bạn và bind vào `0.0.0.0` với cổng `${PORT:-8080}`:
   * **FastAPI / Uvicorn:**
     ```bash
     uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
     ```
   * **Flask:**
     ```bash
     python3 app.py --port ${PORT:-8080}
     ```
   * **Node.js / Express:**
     ```bash
     node server.js
     ```
3. Truy cập vào domain Railway của bạn (`https://vps-production.up.railway.app`) là API đã hoạt động ngay lập tức!

---

© MIT License
