#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "🚀 Khởi động Railway Ubuntu 24.04 VPS (OpenSSH Server)"
echo "============================================================"

# 1. Lấy thông tin cấu hình từ biến môi trường
ROOT_PASS="${ROOT_PASSWORD:-${PASSWORD:-123456}}"
SSH_KEY="${SSH_PUB_KEY:-${AUTHORIZED_KEYS:-}}"
HTTP_PORT="${PORT:-8080}"

# 2. Chuẩn bị thư mục hệ thống
mkdir -p /var/run/sshd /run/sshd /etc/ssh/sshd_config.d /root/.ssh
chmod 0755 /var/run/sshd /run/sshd
chmod 0700 /root/.ssh

# Tạo SSH Host Keys nếu chưa có
ssh-keygen -A >/dev/null 2>&1 || true

# 3. Cấu hình OpenSSH: lắng nghe cổng 22, hỗ trợ mật khẩu và keep-alive chống ngắt kết nối
cat > /etc/ssh/sshd_config.d/01-railway-ssh.conf << 'EOF'
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
MaxStartups 100:30:200

# Keep-Alive: chống timeout, giữ phiên SSH liên tục không bị đứt
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 5
EOF

# Đảm bảo cấu hình chính không chặn mật khẩu root
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true

# 4. Đặt mật khẩu root
echo "root:${ROOT_PASS}" | chpasswd
echo "🔑 Mật khẩu root: Đã thiết lập thành công."

# 5. Nạp SSH Public Key (nếu có cấu hình)
if [[ -n "${SSH_KEY}" ]]; then
    printf '\n%b\n' "${SSH_KEY}" >> /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys
    echo "🔑 SSH Public Key: Đã nạp vào /root/.ssh/authorized_keys."
fi

# 6. Kiểm tra tính hợp lệ của file cấu hình SSH
if ! /usr/sbin/sshd -t; then
    echo "❌ Lỗi: Cấu hình SSH không hợp lệ!" >&2
    exit 1
fi

echo "============================================================"
echo "✨ SSH Server đang lắng nghe trên cổng 22."
echo "👉 Dùng Railway TCP Proxy (cổng 22) để lấy Host và Port kết nối cố định."
echo "👉 Đối với API Server / Agent, hãy bind vào cổng: ${HTTP_PORT} (PORT)"
echo "============================================================"

# Chạy SSH Server ở chế độ foreground (PID 1) để Railway quản lý tiến trình trực tiếp
exec /usr/sbin/sshd -D -e
