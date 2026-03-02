#!/bin/bash

# --- 颜色设置 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

echo -e "${BLUE}==========================================${PLAIN}"
echo -e "${BLUE}    CLIProxyAPI 自动化安装脚本 (Interactive) ${PLAIN}"
echo -e "${BLUE}==========================================${PLAIN}"

# --- 环境检查 ---
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/go_dist/go/bin

if ! command -v go &> /dev/null; then
    echo -e "${RED}错误: 未检测到 Go 环境，请先安装 Go 1.21+${PLAIN}"
    exit 1
fi

# --- 交互式参数获取 ---
read -p "请输入服务监听端口 [默认: 28391]: " PORT
PORT=${PORT:-28391}

read -p "请输入 Web 管理密钥 (Secret Key) [默认: admin123]: " SECRET
SECRET=${SECRET:-admin123}

read -p "请输入凭据存放目录 (Auth Dir) [默认: /root/CLIProxyAPI/auths]: " AUTH_DIR
AUTH_DIR=${AUTH_DIR:-/root/CLIProxyAPI/auths}

# --- 开始安装 ---
WORKDIR="/root/CLIProxyAPI"
echo -e "${YELLOW}正在克隆仓库并编译...${PLAIN}"

if [ -d "$WORKDIR" ]; then
    echo -e "${YELLOW}目录已存在，正在更新...${PLAIN}"
    cd "$WORKDIR" && git pull
else
    git clone https://github.com/router-for-me/CLIProxyAPI.git "$WORKDIR"
    cd "$WORKDIR"
fi

# 编译
go build -o cliproxy ./cmd/server/main.go
if [ $? -ne 0 ]; then
    echo -e "${RED}编译失败！${PLAIN}"
    exit 1
fi

# 生成配置
cat <<EOF > config.yaml
host: ""
port: $PORT
auth-dir: "$AUTH_DIR"

remote-management:
  allow-remote: true
  secret-key: "$SECRET"
  disable-control-panel: false
EOF

mkdir -p "$AUTH_DIR"

# --- 设置管理脚本 ---
echo -e "${YELLOW}正在配置 'cli' 管理命令...${PLAIN}"
mkdir -p /root/bin
cat <<EOF > /root/bin/cli
#!/bin/bash
export PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/go_dist/go/bin
WORKDIR="$WORKDIR"
cd "\$WORKDIR"
case "\$1" in
    start) nohup ./cliproxy -config config.yaml > log.txt 2>&1 & echo "服务已在后台启动" ;;
    stop) pkill cliproxy && echo "服务已停止" ;;
    status) ps aux | grep "./cliproxy -config config.yaml" | grep -v grep && echo -e "\033[0;32m运行中\033[0m" || echo -e "\033[0;31m未运行\033[0m" ;;
    log) tail -f log.txt ;;
    tui) ./cliproxy -tui ;;
    *) echo "用法: cli [start|stop|status|log|tui]" ;;
esac
EOF
chmod +x /root/bin/cli

# 添加到 PATH
if [[ ":$PATH:" != *":/root/bin:"* ]]; then
    echo 'export PATH=$PATH:/root/bin' >> /root/.bashrc
    export PATH=$PATH:/root/bin
fi

# --- 完成 ---
echo -e "${GREEN}==========================================${PLAIN}"
echo -e "${GREEN}    安装完成！${PLAIN}"
echo -e "1. 启动服务: ${YELLOW}cli start${PLAIN}"
echo -e "2. 管理菜单: ${YELLOW}cli${PLAIN}"
echo -e "3. WebUI 地址: ${BLUE}http://[您的IP]:$PORT/v0/management/panel/${PLAIN}"
echo -e "4. 管理密钥: ${YELLOW}$SECRET${PLAIN}"
echo -e "${GREEN}==========================================${PLAIN}"
