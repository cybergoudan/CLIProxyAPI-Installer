#!/bin/bash

# --- 颜色设置 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

WORKDIR="/root/CLIProxyAPI"
BIN_DIR="/root/bin"
CLI_CMD="$BIN_DIR/cli"

echo -e "${BLUE}==========================================${PLAIN}"
echo -e "${BLUE}    CLIProxyAPI 自动化管理脚本 (v1.1)     ${PLAIN}"
echo -e "${BLUE}==========================================${PLAIN}"

# --- 环境检查 ---
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/go_dist/go/bin

# --- 功能函数 ---

# 卸载功能
do_uninstall() {
    echo -e "${YELLOW}正在卸载 CLIProxyAPI...${PLAIN}"
    pkill cliproxy 2>/dev/null
    rm -rf "$WORKDIR"
    rm -f "$CLI_CMD"
    sed -i '/export PATH=\$PATH:\/root\/bin/d' /root/.bashrc
    echo -e "${GREEN}卸载完成！项目文件及环境变量已清理。${PLAIN}"
    exit 0
}

# 更新功能
do_update() {
    if [ ! -d "$WORKDIR" ]; then
        echo -e "${RED}错误: 未检测到已安装的项目，请先选择安装。${PLAIN}"
        exit 1
    fi
    echo -e "${YELLOW}正在检查并更新 CLIProxyAPI...${PLAIN}"
    cd "$WORKDIR" || exit
    git pull
    go build -o cliproxy ./cmd/server/main.go
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}更新并编译成功！请运行 'cli start' 重启服务。${PLAIN}"
    else
        echo -e "${RED}更新失败，请检查网络或 Go 环境。${PLAIN}"
    fi
    exit 0
}

# 安装功能
do_install() {
    if ! command -v go &> /dev/null; then
        echo -e "${RED}错误: 未检测到 Go 环境，请先安装 Go 1.21+${PLAIN}"
        exit 1
    fi

    # 交互式参数
    read -p "请输入服务监听端口 [默认: 28391]: " PORT < /dev/tty
    PORT=${PORT:-28391}

    read -p "请输入 Web 管理密钥 (Secret Key) [默认: admin123]: " SECRET < /dev/tty
    SECRET=${SECRET:-admin123}

    read -p "请输入凭据存放目录 (Auth Dir) [默认: $WORKDIR/auths]: " AUTH_DIR < /dev/tty
    AUTH_DIR=${AUTH_DIR:-$WORKDIR/auths}

    echo -e "${YELLOW}正在克隆仓库并编译...${PLAIN}"
    if [ -d "$WORKDIR" ]; then
        echo -e "${YELLOW}目录已存在，正在更新...${PLAIN}"
        cd "$WORKDIR" && git pull
    else
        git clone https://github.com/router-for-me/CLIProxyAPI.git "$WORKDIR"
        cd "$WORKDIR"
    fi

    go build -o cliproxy ./cmd/server/main.go
    if [ $? -ne 0 ]; then
        echo -e "${RED}编译失败！${PLAIN}"
        exit 1
    fi

    # 生成配置 (若已存在则备份)
    if [ -f "config.yaml" ]; then
        cp config.yaml config.yaml.bak
        echo -e "${YELLOW}检测到旧配置，已备份为 config.yaml.bak${PLAIN}"
    fi

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

    # 设置管理脚本
    mkdir -p "$BIN_DIR"
    cat <<EOF > "$CLI_CMD"
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
    update) 
        echo "正在更新..."
        git pull && go build -o cliproxy ./cmd/server/main.go && echo "更新成功" || echo "更新失败"
        ;;
    uninstall)
        pkill cliproxy
        rm -rf "\$WORKDIR"
        rm -f "\$0"
        echo "已卸载"
        ;;
    *) echo "用法: cli [start|stop|status|log|tui|update|uninstall]" ;;
esac
EOF
    chmod +x "$CLI_CMD"

    # 添加到 PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "export PATH=\$PATH:$BIN_DIR" >> /root/.bashrc
        export PATH=$PATH:$BIN_DIR
    fi

    echo -e "${GREEN}安装完成！${PLAIN}"
    echo -e "1. 启动服务: ${YELLOW}cli start${PLAIN}"
    echo -e "2. 管理菜单: ${YELLOW}cli${PLAIN}"
    echo -e "3. WebUI 地址: ${BLUE}http://[您的IP]:$PORT/v0/management/panel/${PLAIN}"
    echo -e "4. 管理密钥: ${YELLOW}$SECRET${PLAIN}"
}

# --- 主逻辑 ---
echo "请选择操作："
echo "1) 安装 (Install)"
echo "2) 更新 (Update)"
echo "3) 卸载 (Uninstall)"
echo "0) 退出"
read -p "请输入数字 [1-3]: " choice < /dev/tty

case $choice in
    1) do_install ;;
    2) do_update ;;
    3) do_uninstall ;;
    0) exit 0 ;;
    *) echo -e "${RED}无效输入。${PLAIN}"; exit 1 ;;
esac
