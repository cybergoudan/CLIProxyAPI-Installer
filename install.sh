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
GO_DIST_DIR="/root/go_dist"
MIRROR_URL="https://ghfast.top/https://github.com/router-for-me/CLIProxyAPI.git"
ORIGIN_URL="https://github.com/router-for-me/CLIProxyAPI.git"

# --- 环境变量初始化 ---
setup_env() {
    export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$GO_DIST_DIR/go/bin:$BIN_DIR
}
setup_env

# --- 系统依赖检查与安装 ---
ensure_deps() {
    DEPS=("git" "curl" "tar" "ca-certificates")
    MISSING_DEPS=()
    for dep in "${DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then MISSING_DEPS+=("$dep"); fi
    done
    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then return 0; fi
    echo -e "${YELLOW}正在安装依赖: ${MISSING_DEPS[*]}...${PLAIN}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y "${MISSING_DEPS[@]}"
    elif command -v dnf &> /dev/null; then
        dnf install -y "${MISSING_DEPS[@]}"
    elif command -v yum &> /dev/null; then
        yum install -y "${MISSING_DEPS[@]}"
    fi
}

# --- Go 环境检查与自动安装 ---
ensure_go() {
    if command -v go &> /dev/null; then return 0; fi
    echo -e "${YELLOW}正在安装 Go 1.22.1...${PLAIN}"
    mkdir -p "$GO_DIST_DIR"
    curl -L https://go.dev/dl/go1.22.1.linux-amd64.tar.gz -o /tmp/go.tar.gz
    tar -C "$GO_DIST_DIR" -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    setup_env
}

# --- 功能函数 ---

do_uninstall() {
    echo -e "${YELLOW}正在卸载...${PLAIN}"
    pkill cliproxy 2>/dev/null
    rm -rf "$WORKDIR"
    rm -f "$CLI_CMD"
    echo -e "${GREEN}卸载完成！${PLAIN}"
    exit 0
}

do_update() {
    ensure_deps
    ensure_go
    if [ ! -d "$WORKDIR" ]; then echo -e "${RED}错误: 未安装${PLAIN}"; exit 1; fi
    cd "$WORKDIR" || exit
    git pull && go build -o cliproxy ./cmd/server/main.go
    echo -e "${GREEN}更新成功！${PLAIN}"
    exit 0
}

do_install() {
    ensure_deps
    ensure_go

    echo -e "${BLUE}请输入配置信息:${PLAIN}"
    echo -n "1. 监听端口 [默认 28391]: "
    read PORT < /dev/tty
    PORT=${PORT:-28391}

    echo -n "2. 管理密钥 [默认 admin123]: "
    read SECRET < /dev/tty
    SECRET=${SECRET:-admin123}

    echo -n "3. 凭据目录 [默认 $WORKDIR/auths]: "
    read AUTH_DIR < /dev/tty
    AUTH_DIR=${AUTH_DIR:-$WORKDIR/auths}

    echo -e "${YELLOW}正在克隆代码...${PLAIN}"
    if [ -d "$WORKDIR" ]; then
        cd "$WORKDIR" && git pull
    else
        # 尝试原始链接
        echo -e "${YELLOW}尝试从 GitHub 克隆...${PLAIN}"
        if git clone --depth 1 "$ORIGIN_URL" "$WORKDIR"; then
            echo -e "${GREEN}克隆成功 (GitHub)${PLAIN}"
        else
            echo -e "${YELLOW}GitHub 连接失败，正在尝试镜像加速 (ghfast.top)...${PLAIN}"
            if git clone --depth 1 "$MIRROR_URL" "$WORKDIR"; then
                echo -e "${GREEN}克隆成功 (镜像加速)${PLAIN}"
            else
                echo -e "${RED}克隆失败。请检查您的网络连接。${PLAIN}"
                exit 1
            fi
        fi
        cd "$WORKDIR" || exit
    fi

    echo -e "${YELLOW}正在编译...${PLAIN}"
    go build -o cliproxy ./cmd/server/main.go
    if [ $? -ne 0 ]; then echo -e "${RED}编译失败${PLAIN}"; exit 1; fi

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
    mkdir -p "$BIN_DIR"

    # 生成 cli 命令
    cat <<EOF > "$CLI_CMD"
#!/bin/bash
export PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$GO_DIST_DIR/go/bin
WORKDIR="$WORKDIR"
cd "\$WORKDIR"
case "\$1" in
    start) nohup ./cliproxy -config config.yaml > log.txt 2>&1 & echo "已启动" ;;
    stop) pkill cliproxy && echo "已停止" ;;
    status) ps aux | grep "./cliproxy -config config.yaml" | grep -v grep && echo -e "\033[0;32m运行中\033[0m" || echo -e "\033[0;31m未运行\033[0m" ;;
    log) tail -f log.txt ;;
    tui) ./cliproxy -tui ;;
    update) cd "\$WORKDIR" && git pull && go build -o cliproxy ./cmd/server/main.go && echo "已更新" ;;
    uninstall) pkill cliproxy; rm -rf "\$WORKDIR"; rm -f "\$0"; echo "已卸载" ;;
    *) echo "用法: cli [start|stop|status|log|tui|update|uninstall]" ;;
esac
EOF
    chmod +x "$CLI_CMD"

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "export PATH=\$PATH:$BIN_DIR" >> /root/.bashrc
    fi

    echo -e "${GREEN}安装成功！使用 'cli start' 启动。${PLAIN}"
}

# --- 主程序 ---
clear
echo -e "${BLUE}==========================================${PLAIN}"
echo -e "${BLUE}    CLIProxyAPI 自动化管理脚本 (v1.6)     ${PLAIN}"
echo -e "${BLUE}==========================================${PLAIN}"
echo "1) 安装 (Install)"
echo "2) 更新 (Update)"
echo "3) 卸载 (Uninstall)"
echo "0) 退出"
echo -n "请选择操作 [0-3]: "
read choice < /dev/tty

case $choice in
    1) do_install ;;
    2) do_update ;;
    3) do_uninstall ;;
    *) exit 0 ;;
esac
