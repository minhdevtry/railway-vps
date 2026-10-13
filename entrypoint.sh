#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo "Starting Railway Ubuntu 24.04 VPS (OpenSSH Server)"
echo "============================================================"

# 1. Configuration from environment variables
SSH_KEY="${SSH_PUB_KEY:-${AUTHORIZED_KEYS:-}}"
HTTP_PORT="${PORT:-8080}"
PW_STORE="/etc/railway-vps/.root_pw"

# --- Root password ---
# Priority: ROOT_PASSWORD. If empty, reuse the password generated on the
# previous run (persisted inside the container, survives restarts); otherwise
# generate a random 24-character password and print it to the deploy log.
if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    ROOT_PASS="${ROOT_PASSWORD}"
    case "${ROOT_PASS}" in
        123456|password|root|admin|qwerty|letmein|changeme)
            echo "WARNING: ROOT_PASSWORD looks weak or common — please change it!" >&2
            ;;
    esac
else
    mkdir -p "$(dirname "${PW_STORE}")"
    if [[ -f "${PW_STORE}" ]]; then
        ROOT_PASS="$(cat "${PW_STORE}")"
        echo "Reusing the previously generated root password."
        echo "(Set the ROOT_PASSWORD env var to use a fixed password.)"
    else
        ROOT_PASS="$(python3 -c 'import secrets,string; print("".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(24)))')"
        printf '%s' "${ROOT_PASS}" > "${PW_STORE}"
        chmod 600 "${PW_STORE}"
        echo "ROOT_PASSWORD is not set — generated a random password:"
        echo ""
        echo "      ${ROOT_PASS}"
        echo ""
        echo "Save it and set it as the ROOT_PASSWORD environment variable."
    fi
fi

# --- SSH authentication mode ---
# PASSWORD_AUTH=yes|no|auto (default: auto)
#   auto = SSH key present -> DISABLE password auth (key-only login, brute-force proof)
#          no key          -> keep password auth (avoid locking yourself out)
PASSWORD_AUTH="${PASSWORD_AUTH:-auto}"
case "${PASSWORD_AUTH,,}" in
    auto)
        if [[ -n "${SSH_KEY}" ]]; then PA="no"; else PA="yes"; fi
        ;;
    yes|no)
        PA="${PASSWORD_AUTH,,}"
        ;;
    *)
        echo "ERROR: invalid PASSWORD_AUTH='${PASSWORD_AUTH}' (expected yes/no/auto)." >&2
        exit 1
        ;;
esac

if [[ "${PA}" == "no" && -z "${SSH_KEY}" ]]; then
    echo "ERROR: PASSWORD_AUTH=no but no SSH_PUB_KEY provided — you would be locked out. Aborting." >&2
    exit 1
fi

# 2. Prepare system directories
mkdir -p /var/run/sshd /run/sshd /etc/ssh/sshd_config.d /root/.ssh
chmod 0755 /var/run/sshd /run/sshd
chmod 0700 /root/.ssh

# Generate SSH host keys if missing
ssh-keygen -A >/dev/null 2>&1 || true

# 3. OpenSSH configuration
cat > /etc/ssh/sshd_config.d/01-railway-ssh.conf << EOF
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication ${PA}
KbdInteractiveAuthentication ${PA}
MaxAuthTries 3
LoginGraceTime 60
MaxStartups 100:30:200

# Keep-alive: prevent timeouts and keep SSH sessions alive
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 5
EOF

# Make sure the main config does not conflict with the drop-in
sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication ${PA}/" /etc/ssh/sshd_config 2>/dev/null || true
sed -i "s/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication ${PA}/" /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true

# 4. Set the root password
echo "root:${ROOT_PASS}" | chpasswd
if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    echo "Root password: set from ROOT_PASSWORD."
else
    echo "Root password: set (random — see the log above)."
fi

# 5. Load the SSH public key (if provided)
if [[ -n "${SSH_KEY}" ]]; then
    printf '\n%b\n' "${SSH_KEY}" >> /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys
    echo "SSH public key: loaded into /root/.ssh/authorized_keys."
fi

# 6. Validate the SSH configuration
if ! /usr/sbin/sshd -t; then
    echo "ERROR: invalid SSH configuration!" >&2
    exit 1
fi

# 7. Auto-start the application (optional, via START_COMMAND)
if [[ -n "${START_COMMAND:-}" ]]; then
    echo "Auto-starting: ${START_COMMAND}"
    mkdir -p /var/log/railway-vps
    setsid bash -c "${START_COMMAND}" >>/var/log/railway-vps/app.log 2>&1 < /dev/null &
    echo "Application log: /var/log/railway-vps/app.log"
fi

echo "============================================================"
echo "SSH server listening on port 22."
if [[ "${PA}" == "no" ]]; then
    echo "Key-only authentication (password auth is DISABLED)."
else
    echo "Root login via password (or SSH key if loaded)."
fi
echo "Use the Railway TCP Proxy (port 22) for a stable host and port."
echo "API Server / Agent: bind to port ${HTTP_PORT} (PORT)."
echo "============================================================"

# Run the SSH server in the foreground (PID 1) so Railway manages it directly
exec /usr/sbin/sshd -D -e
