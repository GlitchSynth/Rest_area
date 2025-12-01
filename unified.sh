#!/bin/bash

DOMAIN="HostDare.wesley.ink"
PANEL_PORT="2053"
HY2_PASS="H9vN3pQ7zR2w"

echo "=== 更新系统 ==="
apt update -y
apt install -y curl wget sudo socat jq unzip

echo "=== 启用 BBR ==="
cat <<EOF >/etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward = 1
EOF
sysctl -p

echo "=== 安装 3X-UI ==="
bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh)

echo "=== 配置 3X-UI 面板端口为 $PANEL_PORT ==="
sed -i "s/54321/$PANEL_PORT/" /etc/x-ui/x-ui.db 2>/dev/null

systemctl restart x-ui

echo "=== 安装 Xray-core（Reality） ==="
mkdir -p /etc/xray
wget -O /usr/local/bin/xray https://github.com/XTLS/Xray-core/releases/latest/download/xray-linux-64.zip
unzip xray-linux-64.zip -d /tmp/xray
mv /tmp/xray/xray /usr/local/bin/xray
chmod +x /usr/local/bin/xray

REALITY_KEY=$(xray x25519 | grep Private | awk '{print $3}')
REALITY_PUB=$(xray x25519 | grep Public | awk '{print $3}')

echo "=== 生成 Reality 配置 ==="

cat <<EOF >/etc/xray/config.json
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$(uuidgen)",
            "flow": "",
            "email": "reality"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": ["www.microsoft.com"],
          "privateKey": "$REALITY_KEY",
          "shortIds": ["3f2b1a"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray-Core Reality
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

echo "=== 安装 Hysteria2 ==="
bash <(curl -fsSL https://get.hy2.sh/) <<EOF
8443
$HY2_PASS
$DOMAIN
EOF

echo "=== Final 输出 ==="
echo "==============================================="
echo "3X-UI 面板：http://$DOMAIN:$PANEL_PORT"
echo "Reality 公钥：$REALITY_PUB"
echo "Hysteria2 密码：$HY2_PASS"
echo "==============================================="
