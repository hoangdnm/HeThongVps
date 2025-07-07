#!/bin/bash

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Đang cập nhật hệ thống và cài Docker...${NC}"

# Kiểm tra OS
if ! command -v apt >/dev/null; then
    echo -e "${RED}❌ Script này chỉ hỗ trợ Ubuntu/Debian${NC}"
    exit 1
fi

# Kiểm tra quyền sudo
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Script cần quyền sudo. Vui lòng nhập password khi được yêu cầu.${NC}"
fi

# Update & cài Docker
sudo apt update || { echo -e "${RED}❌ Lỗi khi update package list${NC}"; exit 1; }
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

# Kiểm tra Docker đã cài thành công chưa
if ! sudo docker --version >/dev/null 2>&1; then
    echo -e "${RED}❌ Lỗi khi cài Docker${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker đã được cài thành công.${NC}"

# Thêm user hiện tại vào group docker để không cần sudo
sudo usermod -aG docker $USER
echo -e "${YELLOW}💡 Đã thêm user vào docker group. Logout/login lại để áp dụng.${NC}"

# Tạo thông tin cấu hình
DB_NAME="mssql"
SA_PASSWORD="YourStrong!Passw0rd"

# Kiểm tra container đã tồn tại chưa
if sudo docker ps -a --format 'table {{.Names}}' | grep -q "^$DB_NAME$"; then
    echo -e "${YELLOW}⚠️  Container $DB_NAME đã tồn tại. Xóa container cũ...${NC}"
    sudo docker stop $DB_NAME 2>/dev/null
    sudo docker rm $DB_NAME 2>/dev/null
fi

echo -e "${GREEN}🐳 Đang kéo image SQL Server 2022...${NC}"
sudo docker pull mcr.microsoft.com/mssql/server:2022-latest || {
    echo -e "${RED}❌ Lỗi khi kéo image SQL Server${NC}"
    exit 1
}

echo -e "${GREEN}🚀 Đang tạo và chạy container SQL Server...${NC}"
sudo docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=$SA_PASSWORD" \
  -p 1433:1433 \
  --name $DB_NAME \
  --restart=always \
  -d mcr.microsoft.com/mssql/server:2022-latest

# Kiểm tra container đã chạy thành công chưa
sleep 5
if ! sudo docker ps --format 'table {{.Names}}' | grep -q "^$DB_NAME$"; then
    echo -e "${RED}❌ Container không thể khởi động. Kiểm tra logs:${NC}"
    sudo docker logs $DB_NAME
    exit 1
fi

# Mở firewall nếu cần
if command -v ufw >/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}🌐 Mở port 1433 cho firewall...${NC}"
    sudo ufw allow 1433/tcp
fi

# Kiểm tra firewall cho iptables
if command -v iptables >/dev/null; then
    echo -e "${YELLOW}💡 Đảm bảo port 1433 không bị block bởi iptables${NC}"
fi

echo -e "${GREEN}✅ Hoàn tất cài đặt!${NC}"
echo "============================================"
echo -e "${GREEN}🔗 SQL Server đang chạy trên port 1433${NC}"
echo -e "${GREEN}👤 User: sa${NC}"
echo -e "${GREEN}🔑 Password: $SA_PASSWORD${NC}"
echo -e "${YELLOW}💡 Dùng công cụ như DBeaver, Azure Data Studio hoặc sqlcmd để kết nối.${NC}"
echo -e "${GREEN}📦 Container name: $DB_NAME${NC}"
echo "============================================"
echo -e "${YELLOW}📋 Lệnh hữu ích:${NC}"
echo "  - Xem logs: sudo docker logs $DB_NAME"
echo "  - Restart: sudo docker restart $DB_NAME"
echo "  - Stop: sudo docker stop $DB_NAME"
echo "  - Kết nối: docker exec -it $DB_NAME /opt/mssql-tools/bin/sqlcmd -S localhost -U sa"
echo "============================================"
