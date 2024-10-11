#!/bin/bash

# Function to determine the CPU architecture
get_architecture() {
    arch=$(uname -m)
    case $arch in
        x86_64)
            echo "x86_64-unknown-linux-gnu"
            ;;
        aarch64)
            echo "aarch64-unknown-linux-gnu"
            ;;
        armv7l)
            echo "armv7-unknown-linux-gnueabihf"
            ;;
        arm)
            echo "arm-unknown-linux-gnueabi"
            ;;
        *)
            echo "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Function to download the appropriate realm file based on architecture
download_realm() {
    arch=$(get_architecture)
    url="https://github.com/zhboner/realm/releases/download/v2.6.2/realm-$arch.tar.gz"
    wget -O realm.tar.gz "$url"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download realm for architecture $arch."
        exit 1
    fi
    tar -xvf realm.tar.gz
    chmod +x realm
    # Move realm binary to /usr/local/bin for global access
    mv realm /usr/local/bin/
}

# Check if realm is installed
if [ -f "/usr/local/bin/realm" ]; then
    echo "检测到realm已安装。"
    realm_status="已安装"
    realm_status_color="\033[0;32m" # 绿色
else
    echo "realm未安装。"
    realm_status="未安装"
    realm_status_color="\033[0;31m" # 红色
fi

# Function to check realm service status
check_realm_service_status() {
    if systemctl is-active --quiet realm; then
        echo -e "\033[0;32m启用\033[0m" # 绿色
    else
        echo -e "\033[0;31m未启用\033[0m" # 红色
    fi
}

# Function to display the menu
show_menu() {
    clear
    echo "欢迎使用realm一键转发脚本"
    echo "realm版本v2.6.2"
    echo "修改by：Azimi"
    echo "========================"
    echo "1. 安装realm"
    echo "2. 添加realm转发"
    echo "3. 查看realm转发"
    echo "4. 删除realm转发"
    echo "5. 启动realm服务"
    echo "6. 停止realm服务"
    echo "7. 卸载realm"
    echo "8. 定时重启任务"
    echo "9. 退出脚本"
    echo "========================"
    echo -e "realm 状态：${realm_status_color}${realm_status}\033[0m"
    echo -n "realm 转发状态："
    check_realm_service_status
}

# Function to deploy realm
deploy_realm() {
    mkdir -p /root/realm
    cd /root/realm
    download_realm
    # Create service file
    echo "[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
WorkingDirectory=/root/realm
ExecStart=/usr/local/bin/realm -c /root/realm/config.toml

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/realm.service
    systemctl daemon-reload

    # Create config.toml if it doesn't exist
    if [ ! -f /root/realm/config.toml ]; then
        touch /root/realm/config.toml
    fi

    # Add [network] configuration if not present
    if ! grep -q "\[network\]" /root/realm/config.toml; then
        echo "[network]
no_tcp = false
use_udp = true
" | cat - /root/realm/config.toml > temp && mv temp /root/realm/config.toml
        echo "[network] 配置已添加到 config.toml 文件。"
    else
        echo "[network] 配置已存在，跳过添加。"
    fi

    # Update realm status
    realm_status="已安装"
    realm_status_color="\033[0;32m" # 绿色
    echo "部署完成。"
}

# Function to uninstall realm
uninstall_realm() {
    systemctl stop realm
    systemctl disable realm
    rm -rf /etc/systemd/system/realm.service
    systemctl daemon-reload
    rm -rf /root/realm
    rm -f /usr/local/bin/realm
    sed -i '/realm/d' /etc/crontab
    echo "realm已被卸载。"
    # Update realm status
    realm_status="未安装"
    realm_status_color="\033[0;31m" # 红色
}

# Function to add forwarding rule
add_forward() {
    while true; do
        read -p "请输入本地监听端口: " local_port
        read -p "请输入需要转发的IP: " ip
        read -p "请输入需要转发端口: " port
        read -p "请输入备注(非中文): " remark
        # Append to config.toml
        echo "[[endpoints]]
# 备注: $remark
listen = \"0.0.0.0:$local_port\"
remote = \"$ip:$port\"" >> /root/realm/config.toml
        read -p "是否继续添加(Y/N)? " answer
        if [[ $answer != "Y" && $answer != "y" ]]; then
            break
        fi
    done
}

# Function to start realm service
start_service() {
    sudo systemctl unmask realm.service
    sudo systemctl daemon-reload
    sudo systemctl restart realm.service
    sudo systemctl enable realm.service
    echo "realm服务已启动并设置为开机自启。"
}

# Function to stop realm service
stop_service() {
    systemctl stop realm
    echo "realm服务已停止。"
}

# Main loop
while true; do
    show_menu
    read -p "请选择一个选项: " choice
    choice=$(echo $choice | tr -d '[:space:]')
    if ! [[ "$choice" =~ ^[1-9]$ ]]; then
        echo "无效选项: $choice"
        continue
    fi
    case $choice in
        1)
            deploy_realm
            ;;
        2)
            add_forward
            ;;
        5)
            start_service
            ;;
        6)
            stop_service
            ;;
        7)
            uninstall_realm
            ;;
        9)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项: $choice"
            ;;
    esac
    read -p "按任意键继续..." key
done
