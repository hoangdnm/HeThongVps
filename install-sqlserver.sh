#!/bin/bash

echo "🔧 Đang cập nhật hệ thống và cài Docker..."

# Update & cài Docker
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

echo "✅ Docker đã được cài."

# Tạo thông tin cấu hình
DB_NAME="mssql"
SA_PASSWORD="YourStrong!Passw0rd"

echo "🐳 Đang kéo image SQL Server Express 2022..."
sudo docker pull mcr.microsoft.com/mssql/server:2022-lts

echo "🚀 Đang tạo và chạy container SQL Server..."
sudo docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=$SA_PASSWORD" \
  -p 1433:1433 \
  --name $DB_NAME \
  --restart=always \
  -d mcr.microsoft.com/mssql/server:2022-lts

# Mở firewall nếu cần
echo "🌐 Đang cấu hình firewall..."
if command -v ufw >/dev/null && sudo ufw status | grep -q "Status: active"; then
  echo "   - Mở port 1433 cho UFW..."
  sudo ufw allow 1433/tcp
fi

# Kiểm tra iptables firewall
if command -v iptables >/dev/null; then
  echo "   - Kiểm tra iptables..."
  # Thêm rule cho iptables nếu cần (thường VPS provider đã config)
fi

# Kiểm tra container đã chạy thành công
echo "🔍 Kiểm tra container..."
sleep 3
if sudo docker ps | grep -q $DB_NAME; then
  echo "✅ Container $DB_NAME đang chạy!"
else
  echo "❌ Container không chạy. Kiểm tra logs:"
  sudo docker logs $DB_NAME
fi

# Lấy IP của VPS
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "IP_CUA_VPS")

echo "✅ Hoàn tất cài đặt!"
echo "============================================"
echo "🔗 Kết nối SQL Server:"
echo "   📍 Server: $VPS_IP,1433 (hoặc localhost,1433)"
echo "   👤 User: sa"
echo "   🔑 Password: $SA_PASSWORD"
echo "   🌐 Port: 1433"
echo ""
echo "💡 Cách kết nối từ máy khác:"
echo "   - Server: $VPS_IP"
echo "   - Port: 1433"
echo "   - Authentication: SQL Server Authentication"
echo "   - Username: sa"
echo "   - Password: $SA_PASSWORD"
echo ""
echo "🛠️ Test kết nối:"
echo "   telnet $VPS_IP 1433"
echo ""
echo "📦 Container: $DB_NAME"
echo "🔧 Quản lý: sudo docker [start|stop|restart] $DB_NAME"
echo "============================================"
