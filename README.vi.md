# Railway VPS — Ubuntu 24.04 + OpenSSH

[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[Tiếng Việt] | [English](README.md)

Triển khai một máy **Ubuntu 24.04 LTS** trên [Railway](https://railway.com) với **OpenSSH**, truy cập qua **TCP Proxy** ổn định. Tích hợp sẵn bộ dev tools (Python 3, Node.js, git, tmux, build tools) và có thể mở **API server / AI agent** ra internet.

---

## ✨ Tính năng

- **Ưu tiên SSH key** — nạp `SSH_PUB_KEY` là password auth tự tắt (chống brute-force tuyệt đối). Mật khẩu root giữ làm phương án dự phòng.
- **Không còn mật khẩu mặc định** — bỏ trống `ROOT_PASSWORD`, lần boot đầu tiên sẽ tự sinh mật khẩu mạnh 24 ký tự: in một lần duy nhất trong deploy log, giữ nguyên qua các lần restart.
- **Endpoint ổn định** — Railway TCP Proxy giữ nguyên host:port qua mọi lần redeploy.
- **Luôn chạy** — `restartPolicyType: ALWAYS`, tắt sleep, SSH keep-alive (`ClientAliveInterval 30`).
- **Tự chạy ứng dụng** — đặt `START_COMMAND`, API/agent của bạn khởi động cùng container (log tại `/var/log/railway-vps/app.log`).
- **Sẵn sàng dev** — Python 3, Node.js LTS, gcc, git, tmux/screen, htop/btop, jq, sqlite3, zsh…

## 🚀 Triển khai

1. Trên Railway: **New Project → Deploy from GitHub repo**, chọn repo này.
2. *(Khuyên dùng)* Trong tab **Variables** của service, đặt `SSH_PUB_KEY` là public key của bạn (`~/.ssh/id_ed25519.pub`) và một `ROOT_PASSWORD` mạnh.
3. Trong **Settings → Networking**, thêm **TCP Proxy** cho cổng `22` — Railway cấp địa chỉ ổn định, ví dụ `roundhouse.proxy.rlwy.net:12345`.

## ⚙️ Cấu hình

| Biến | Mặc định | Mô tả |
| :--- | :---: | :--- |
| `ROOT_PASSWORD` | *(tự sinh)* | Mật khẩu root cho SSH. Bỏ trống = tự sinh mật khẩu mạnh 24 ký tự ở lần boot đầu (xem deploy log). Mỗi lần redeploy sẽ sinh mật khẩu **mới** — xem lại log |
| `SSH_PUB_KEY` | *(trống)* | Public key SSH của bạn — **khuyên dùng**. Nạp key là password auth tự tắt |
| `PASSWORD_AUTH` | `auto` | `yes` / `no` / `auto`. `auto` = tắt password auth khi đã có SSH key |
| `START_COMMAND` | *(trống)* | Lệnh tự chạy khi boot, ví dụ `uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}` |
| `PORT` | `8080` | Cổng cho Railway HTTP ingress (public domain) |

## 🔑 Kết nối SSH

```bash
ssh root@<TCP_HOST> -p <TCP_PORT>
# ví dụ
ssh root@roundhouse.proxy.rlwy.net -p 12345
```

- Dùng SSH key: đăng nhập thẳng, không cần mật khẩu (password auth đã tắt).
- Dùng mật khẩu: nhập mật khẩu root (`ROOT_PASSWORD` của bạn, hoặc mật khẩu tự sinh trong deploy log lần đầu).

## 🌐 Mở API server / AI agent ra Internet

**Tự động (khuyên dùng):** đặt `START_COMMAND`, ví dụ:

```bash
uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
```

Ứng dụng tự chạy mỗi khi boot. Xem log qua SSH: `tail -f /var/log/railway-vps/app.log`.

**Thủ công:** SSH vào rồi chạy tay (dùng `tmux` để tiến trình sống sau khi thoát SSH).

Sau đó **Settings → Networking → Generate Domain** để lấy public URL (ví dụ `vps-production.up.railway.app`) — Railway forward về `$PORT` của bạn.

> **TCP Proxy vs. public domain:** domain chỉ forward HTTP về `$PORT`. TCP thô (SSH, database, game server…) đi qua các TCP Proxy — thêm một entry cho mỗi cổng trong container tại **Settings → Networking**.

Cần nhiều hơn một port? Cứ thêm TCP Proxy entry — mỗi cổng trong container có một host:port public ổn định riêng.

## 🔐 Ghi chú bảo mật

- Đừng bao giờ mở password auth với mật khẩu yếu ra internet — entrypoint sẽ cảnh báo các mật khẩu phổ biến (`123456`, `password`, …).
- Ưu tiên SSH key. Với `PASSWORD_AUTH=auto` (mặc định), nạp key là password auth tắt hoàn toàn.
- Mật khẩu tự sinh chỉ in **một lần** trong deploy log — hãy lưu lại rồi đặt `ROOT_PASSWORD` cố định.

## ⚠️ Giới hạn

- Đây là **container, không phải VPS thật**: filesystem bị xóa khi redeploy (restart thường thì giữ nguyên). Dữ liệu quan trọng hãy dùng Railway Volume hoặc lưu ra ngoài.
- **Biết quota thật của bạn:** `nproc` và `free` trong container hiện thông số của máy *host*, không phải của bạn. Kiểm tra giới hạn CPU/RAM thật bằng:
  ```bash
  cat /sys/fs/cgroup/cpu.max
  cat /sys/fs/cgroup/memory.max
  ```
- Chạy 24/7 tốn usage credit của Railway (tính theo RAM×giờ) — VPS thuê riêng rẻ hơn nhiều cho box chạy liên tục.
- Railway có thể restart container khi bảo trì nền tảng; TCP Proxy endpoint giữ nguyên, nhưng mọi thứ trong RAM sẽ mất.

## 📄 Giấy phép

MIT — xem [LICENSE](LICENSE).
