# Railway Ubuntu 24.04 VPS with OpenSSH
FROM ubuntu:24.04

# Khử interactive prompt trong quá trình build
ENV DEBIAN_FRONTEND=noninteractive

# Xóa user ubuntu mặc định trên Ubuntu 24.04 (nếu có)
RUN userdel -r ubuntu 2>/dev/null || true

# Kích hoạt universe repositories
RUN sed -i 's/^Components: .*/Components: main restricted universe/' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true

# Cài đặt OpenSSH, dev tools, mạng và các tiện ích cơ bản
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates gnupg apt-transport-https software-properties-common \
        openssh-server sudo \
        curl wget \
        iproute2 iputils-ping net-tools dnsutils traceroute whois telnet nmap lsof \
        vim nano micro \
        htop btop ncdu \
        tmux screen less tree bat ripgrep fd-find jq zsh \
        unzip zip tar gzip bzip2 xz-utils p7zip-full \
        git build-essential cmake pkg-config autoconf automake libtool gcc g++ \
        python3 python3-pip python3-venv python3-dev \
        nodejs npm \
        rsync sqlite3 \
        locales ncurses-term \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Cấu hình Locale UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV TERM=xterm-256color

# Alias python -> python3
RUN ln -sf /usr/bin/python3 /usr/local/bin/python \
    && ln -sf /usr/bin/pip3 /usr/local/bin/pip

# Copy SSH login banner và entrypoint
COPY welcome.sh /etc/profile.d/welcome.sh
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh /etc/profile.d/welcome.sh \
    && chmod +x /entrypoint.sh /etc/profile.d/welcome.sh

# Expose cổng 22 (cho SSH TCP Proxy) và 8080 (cho API Server / Web Agent)
EXPOSE 22 8080

ENTRYPOINT ["/entrypoint.sh"]
