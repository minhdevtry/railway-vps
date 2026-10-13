#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "🚀 Khởi động Railway Ubuntu 24.04 VPS (OpenSSH Server)"
echo "============================================================"

# 1. Cấu hình từ biến môi trường
SSH_KEY="${SSH_PUB_KEY:-${AUTHORIZED_KEYS:-}}"
HTTP_PORT="${PORT:-8080}"
PW_STORE="/etc/railway-vps/.root_pw"

# --- Mật khẩu root ---
# Ưu tiên ROOT_PASSWORD. Nếu bỏ trống: dùng lại mật khẩu đã tạo ở lần chạy
# trước (lưu trong container, sống sót qua restart), nếu chưa có thì tạo
# ngẫu nhiên 24 ký tự và in ra log deploy để bạn lưu lại.
if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    ROOT_PASS="${ROOT_PASSWORD}"
    case "${ROOT_PASS}" in
        123456|password|root|admin|qwerty|letmein|changeme)
            echo "⚠️  CẢNH BÁO: ROOT_PASSWORD đang dùng mật khẩu yếu/phổ biến — hãy đổi ngay!" >&2
            ;;
    esac
else
    mkdir -p "$(dirname "${PW_STORE}")"
    if [[ -f "${PW_STORE}" ]]; then
        ROOT_PASS="$(cat "${PW_STORE}")"
        echo "🔑 Dùng lại mật khẩu root đã tạo trước đó."
        echo "   (Đặt biến môi trường ROOT_PASSWORD để cố định mật khẩu.)"
    else
        ROOT_PASS="$(python3 -c 'import secrets,string; print("".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(24)))')"
        printf '%s' "${ROOT_PASS}" > "${PW_STORE}"
        chmod 600 "${PW_STORE}"
        echo "🔑 ROOT_PASSWORD chưa được đặt — đã tạo mật khẩu ngẫu nhiên:"
        echo ""
        echo "      ${ROOT_PASS}"
        echo ""
        echo "   Hãy lưu lại và đặt vào biến môi trường ROOT_PASSWORD."
    fi
fi

# --- Chế độ xác thực SSH ---
# PASSWORD_AUTH=yes|no|auto (mặc định: auto)
#   auto = có SSH key  -> TẮT password (chỉ key mới đăng nhập được, chống brute-force)
#          chưa có key -> giữ password (tránh tự khóa mình ngoài cửa)
PASSWORD_AUTH="${PASSWORD_AUTH:-auto}"
case "${PASSWORD_AUTH,,}" in
    auto)
        if [[ -n "${SSH_KEY}" ]]; then PA="no"; else PA="yes"; fi
        ;;
    yes|no)
        PA="${PASSWORD_AUTH,,}"
        ;;
    *)
        echo "❌ PASSWORD_AUTH không hợp lệ: '${PASSWORD_AUTH}' (chỉ nhận yes/no/auto)." >&2
        exit 1
        ;;
esac

if [[ "${PA}" == "no" && -z "${SSH_KEY}" ]]; then
    echo "❌ PASSWORD_AUTH=no nhưng không có SSH_PUB_KEY — bạn sẽ bị khóa ngoài. Hủy bỏ." >&2
    exit 1
fi

# 2. Chuẩn bị thư mục hệ thống
mkdir -p /var/run/sshd /run/sshd /etc/ssh/sshd_config.d /root/.ssh
chmod 0755 /var/run/sshd /run/sshd
chmod 0700 /root/.ssh

# Tạo SSH Host Keys nếu chưa có
ssh-keygen -A >/dev/null 2>&1 || true

# 3. Cấu hình OpenSSH
cat > /etc/ssh/sshd_config.d/01-railway-ssh.conf << EOF
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication ${PA}
KbdInteractiveAuthentication ${PA}
MaxAuthTries 3
LoginGraceTime 60
MaxStartups 100:30:200

# Keep-Alive: chống timeout, giữ phiên SSH liên tục không bị đứt
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 5
EOF

# Đảm bảo cấu hình chính không mâu thuẫn với drop-in
sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication ${PA}/" /etc/ssh/sshd_config 2>/dev/null || true
sed -i "s/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication ${PA}/" /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true

# 4. Đặt mật khẩu root
echo "root:${ROOT_PASS}" | chpasswd
if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    echo "🔑 Mật khẩu root: đã thiết lập từ biến ROOT_PASSWORD."
else
    echo "🔑 Mật khẩu root: đã thiết lập (ngẫu nhiên — xem log phía trên)."
fi

# 5. Nạp SSH Public Key (nếu có cấu hình)
if [[ -n "${SSH_KEY}" ]]; then
    printf '\n%b\n' "${SSH_KEY}" >> /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys
    echo "🔑 SSH Public Key: đã nạp vào /root/.ssh/authorized_keys."
fi

# 6. Kiểm tra tính hợp lệ của file cấu hình SSH
if ! /usr/sbin/sshd -t; then
    echo "❌ Lỗi: Cấu hình SSH không hợp lệ!" >&2
    exit 1
fi

# 7. Tự động chạy ứng dụng (tùy chọn qua START_COMMAND)
if [[ -n "${START_COMMAND:-}" ]]; then
    echo "▶️  Tự động chạy: ${START_COMMAND}"
    mkdir -p /var/log/railway-vps
    setsid bash -c "${START_COMMAND}" >>/var/log/railway-vps/app.log 2>&1 < /dev/null &
    echo "   Log ứng dụng: /var/log/railway-vps/app.log"
fi

echo "============================================================"
echo "✨ SSH Server đang lắng nghe trên cổng 22."
if [[ "${PA}" == "no" ]]; then
    echo "🔒 Chỉ cho phép đăng nhập bằng SSH key (password auth đã TẮT)."
else
    echo "🔑 Đăng nhập root bằng mật khẩu (hoặc SSH key nếu đã nạp)."
fi
echo "👉 Dùng Railway TCP Proxy (cổng 22) để lấy Host và Port kết nối cố định."
echo "👉 API Server / Agent: bind vào cổng ${HTTP_PORT} (PORT)."
echo "============================================================"

# Chạy SSH Server ở chế độ foreground (PID 1) để Railway quản lý tiến trình trực tiếp
exec /usr/sbin/sshd -D -e
