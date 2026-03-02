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

# --- 环境变量初始化 ---
setup_env() {
    export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$GO_DIST_DIR/go/bin:$BIN_DIR
}
setup_env

# --- Go 环境检查与自动安装 ---
ensure_go() {
    if command -v go &> /dev/null; then
        echo -e "${GREEN}检测到 Go 已安装: $(go version)${PLAIN}"
        return 0
    fi

    echo -e "${YELLOW}未检测到 Go 环境，准备自动安装...${PLAIN}"
    
    # 检查本地是否有备份
    if [ -f "$GO_DIST_DIR/go/bin/go" ]; then
        echo -e "${YELLOW}发现本地备份，正在启用...${PLAIN}"
    else
        echo -e "${YELLOW}正在从官方下载 Go 1.22.1 (linux-amd64)...${PLAIN}"
        mkdir -p "$GO_DIST_DIR"
        curl -L https://go.dev/dl/go1.22.1.linux-amd64.tar.gz -o /tmp/go.tar.gz
        tar -C "$GO_DIST_DIR" -xzf /tmp/go.tar.gz
        rm -f /tmp/go.tar.gz
    fi

    # 写入环境变量
    if ! grep -q "$GO_DIST_DIR/go/bin" /root/.bashrc; then
        echo "export PATH=\$PATH:$GO_DIST_DIR/go/bin" >> /root/.bashrc
    fi
    setup_env
    
    if command -v go &> /dev/null; then
        echo -e "${GREEN}Go 安装成功: $(go version)${PLAIN}"
    else
        echo -e "${RED}Go 安装失败，请手动检查网络。${PLAIN}"
        exit 1
    fi
}

# --- 功能函数 ---

do_uninstall() {
    echo -e "${YELLOW}正在卸载 CLIProxyAPI...${PLAIN}"
    pkill cliproxy 2>/dev/null
    rm -rf "$WORKDIR"
    rm -f "$CLI_CMD"
    sed -i '/export PATH=\$PATH:\/root\/bin/d' /root/.bashrc
    echo -e "${GREEN}卸载完成！${PLAIN}"
    exit 0
}

do_update() {
    ensure_go
    if [ ! -d "$WORKDIR" ]; then
        echo -e "${RED}错误: 未检测到已安装的项目。${PLAIN}"
        exit 1
    fi
    echo -e "${YELLOW}正在更新 CLIProxyAPI...${PLAIN}"
    cd "$WORKDIR" || exit
    git pull && go build -o cliproxy ./cmd/server/main.go
    echo -e "${GREEN}更新成功！${PLAIN}"
    exit 0
}

do_install() {
    ensure_go

    echo -e "${BLUE}请输入配置信息 (直接回车使用默认值):${PLAIN}"
    
    echo -n "1. 监听端口 [默认 28391]: "
    read PORT < /dev/tty
    PORT=${PORT:-28391}

    echo -n "2. 管理密钥 [默认 admin123]: "
    read SECRET < /dev/tty
    SECRET=${SECRET:-admin123}

    echo -n "3. 凭据目录 [默认 $WORKDIR/auths]: "
    read AUTH_DIR < /dev/tty
    AUTH_DIR=${AUTH_DIR:-$WORKDIR/auths}

    echo -e "${YELLOW}开始克隆并编译...${PLAIN}"
    if [ -d "$WORKDIR" ]; then
        cd "$WORKDIR" && git pull
    else
        git clone https://github.com/router-for-me/CLIProxyAPI.git "$WORKDIR"
        cd "$WORKDIR"
    fi

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
    start) nohup ./cliproxy -config config.yaml > log.txt 2>&1 & echo "服务已启动" ;;
    stop) pkill cliproxy && echo "服务已停止" ;;
    status) ps aux | grep "./cliproxy -config config.yaml" | grep -v grep && echo -e "\033[0;32m运行中\033[0m" || echo -e "\033[0;31m未运行\033[0m" ;;
    log) tail -f log.txt ;;
    tui) ./cliproxy -tui ;;
    update) cd "\$WORKDIR" && git pull && go build -o cliproxy ./cmd/server/main.go && echo "更新成功" ;;
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
echo -e "${BLUE}    CLIProxyAPI 自动化管理脚本 (v1.3)     ${PLAIN}"
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
