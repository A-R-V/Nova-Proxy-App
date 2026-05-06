#!/bin/bash
# NovaProxy VPS Server - Install Script
# Compatible with: Ubuntu 20.04+ / Debian 11+

set -e

# ─────────────────────────────────────────
# 1. تنظیم رمز احراز هویت
# ─────────────────────────────────────────
printf "لطفاً رمز احراز هویت را وارد کنید (Enter = تولید خودکار): "
read -r input_secret

if [ -z "$input_secret" ]; then
    AUTH_SECRET="SNI_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)"
else
    AUTH_SECRET="$input_secret"
fi

LISTEN_PORT=443
INSTALL_DIR="/opt/sni-server"

echo ""
echo "=== نصب‌کننده سرور VPS NovaProxy ==="
echo ""
echo "رمز احراز هویت: $AUTH_SECRET"
echo "پورت: $LISTEN_PORT"
echo "مسیر نصب: $INSTALL_DIR"
echo ""

# ─────────────────────────────────────────
# 2. بررسی دسترسی root
# ─────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "[خطا] این اسکریپت باید با دسترسی root اجرا شود."
    exit 1
fi

# ─────────────────────────────────────────
# 3. نصب Caddy
# ─────────────────────────────────────────
if ! command -v caddy > /dev/null 2>&1; then
    echo "[*] در حال نصب Caddy..."

    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        | tee /etc/apt/sources.list.d/caddy-stable.list

    apt-get update
    apt-get install -y caddy

    echo "[✓] Caddy نصب شد."
else
    echo "[✓] Caddy از قبل نصب است."
fi

# ─────────────────────────────────────────
# 4. ایجاد مسیر نصب
# ─────────────────────────────────────────
mkdir -p "$INSTALL_DIR"

# دانلود باینری sni-server از GitHub Releases
BINARY_URL="https://github.com/IRNova/Nova-Proxy-App/releases/latest/download/sni-server-linux-amd64"

echo "[*] در حال دانلود باینری sni-server..."
curl -fsSL "$BINARY_URL" -o "$INSTALL_DIR/sni-server"
chmod +x "$INSTALL_DIR/sni-server"
echo "[✓] باینری دانلود شد."

# ─────────────────────────────────────────
# 5. ایجاد سرویس systemd
# ─────────────────────────────────────────
echo "[*] در حال ایجاد سرویس systemd..."

cat > /etc/systemd/system/sni-server.service << EOF
[Unit]
Description=NovaProxy VPS Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/sni-server -port ${LISTEN_PORT} -secret ${AUTH_SECRET}
Restart=always
RestartSec=5
Environment=AUTH_SECRET=${AUTH_SECRET}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sni-server
systemctl start sni-server

echo "[✓] سرویس sni-server فعال و در حال اجراست."

# ─────────────────────────────────────────
# 6. خروجی نهایی
# ─────────────────────────────────────────
echo ""
echo "=================================================="
echo "          نصب با موفقیت انجام شد ✓"
echo "=================================================="
echo "  رمز احراز هویت : $AUTH_SECRET"
echo "  پورت گوش‌دهی   : $LISTEN_PORT"
echo "--------------------------------------------------"
echo "  فرمت مسیر:"
echo "  /{TOKEN}/{TargetHost}/{Path}"
echo ""
echo "  نمونه درخواست:"
echo "  https://your.domain.com/$AUTH_SECRET/www.google.com/"
echo "--------------------------------------------------"
echo "  اگر از Cloudflare Tunnel استفاده می‌کنید:"
echo "  cloudflared tunnel run --token YOUR_TOKEN"
echo "  (تونل را به http://localhost:$LISTEN_PORT هدایت کنید)"
echo ""
echo "  پیکربندی پیشنهادی Caddy:"
echo "  caddy reverse-proxy --from your.domain.com --to localhost:$LISTEN_PORT"
echo "=================================================="
