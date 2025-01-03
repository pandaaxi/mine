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
    url="https://github.com/zhboner/realm/releases/latest/download/realm-$arch.tar.gz"
    wget -O realm.tar.gz "$url"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download realm for architecture $arch."
        exit 1
    fi
    mkdir -p /root/realm
    tar -xvf realm.tar.gz -C /root/realm && rm realm.tar.gz
    if [ ! -f "/root/realm/realm" ]; then
        echo "Error: realm binary not found after extraction."
        exit 1
    fi
    chmod +x /root/realm/realm
    # Move realm binary to /usr/local/bin for global access
    mv /root/realm/realm /usr/local/bin/
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
    echo "realm版本v2.6.3"
    echo "修改by：panda"
    echo "v0.0.1"
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
    show_all_conf
    echo "========================"
    echo -e "realm 状态：${realm_status_color}${realm_status}\033[0m"
    echo -n "realm 转发状态："
    check_realm_service_status
}

# Function to deploy realm
deploy_realm() {
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

# Function to add forwarding rule
add_forward() {
    while true; do
        echo "========================"
        show_all_conf
        echo "========================"
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

# Function to show all forwarding rules
show_all_conf() {
    echo "当前转发规则："
    local IFS=$'\n' # 设置IFS仅以换行符作为分隔符
    # 搜索所有包含 listen 的行，表示转发规则的起始行
    local lines=($(grep -n 'listen =' /root/realm/config.toml))
    
    if [ ${#lines[@]} -eq 0 ]; then
        echo "没有发现任何转发规则。"
        return
    fi

    local index=1
    for line in "${lines[@]}"; do
        local line_number=$(echo $line | cut -d ':' -f 1)
        local listen_info=$(sed -n "${line_number}p" /root/realm/config.toml | cut -d '"' -f 2)
        local remote_info=$(sed -n "$((line_number + 1))p" /root/realm/config.toml | cut -d '"' -f 2)
        local remark=$(sed -n "$((line_number-1))p" /root/realm/config.toml | grep "^# 备注:" | cut -d ':' -f 2)
        local listen_port=$(echo $listen_info | cut -d ':' -f 2)
        local remote_ip_port=$remote_info

        echo "${index}. 备注: ${remark}"
        echo "   listen: ${listen_port}, remote: ${remote_ip_port}"
        let index+=1
    done
}

# Function to delete forwarding rule
delete_forward() {
    echo "当前转发规则："
    local IFS=$'\n' # 设置IFS仅以换行符作为分隔符
    # 搜索所有包含 [[endpoints]] 的行，表示转发规则的起始行
    local lines=($(grep -n '^\[\[endpoints\]\]' /root/realm/config.toml))
    
    if [ ${#lines[@]} -eq 0 ]; then
        echo "没有发现任何转发规则。"
        return
    fi

    local index=1
    for line in "${lines[@]}"; do
        local line_number=$(echo $line | cut -d ':' -f 1)
        local remark_line=$((line_number + 1))
        local listen_line=$((line_number + 2))
        local remote_line=$((line_number + 3))

        local remark=$(sed -n "${remark_line}p" /root/realm/config.toml | grep "^# 备注:" | cut -d ':' -f 2)
        local listen_info=$(sed -n "${listen_line}p" /root/realm/config.toml | cut -d '"' -f 2)
        local remote_info=$(sed -n "${remote_line}p" /root/realm/config.toml | cut -d '"' -f 2)

        local listen_port=$(echo $listen_info | cut -d ':' -f 2)
        local remote_ip_port=$remote_info

        echo "${index}. 备注: ${remark}"
        echo "   listen: ${listen_port}, remote: ${remote_ip_port}"
        let index+=1
    done

    echo "请输入要删除的转发规则序号，直接按回车返回主菜单。"
    read -p "选择: " choice
    if [ -z "$choice" ]; then
        echo "返回主菜单。"
        return
    fi

    if ! [[ $choice =~ ^[0-9]+$ ]]; then
        echo "无效输入，请输入数字。"
        return
    fi

    if [ $choice -lt 1 ] || [ $choice -gt ${#lines[@]} ]; then
        echo "选择超出范围，请输入有效序号。"
        return
    fi

    local chosen_line=${lines[$((choice-1))]}
    local start_line=$(echo $chosen_line | cut -d ':' -f 1)

    # 找到下一个 [[endpoints]] 行，确定删除范围的结束行
    local next_endpoints_line=$(grep -n '^\[\[endpoints\]\]' /root/realm/config.toml | grep -A 1 "^$start_line:" | tail -n 1 | cut -d ':' -f 1)
    
    if [ -z "$next_endpoints_line" ] || [ "$next_endpoints_line" -le "$start_line" ]; then
        # 如果没有找到下一个 [[endpoints]]，则删除到文件末尾
        end_line=$(wc -l < /root/realm/config.toml)
    else
        # 如果找到了下一个 [[endpoints]]，则删除到它的前一行
        end_line=$((next_endpoints_line - 1))
    fi

    # 使用 sed 删除指定行范围的内容
    sed -i "${start_line},${end_line}d" /root/realm/config.toml

    # 检查并删除可能多余的空行
    sed -i '/^\s*$/d' /root/realm/config.toml

    echo "转发规则及其备注已删除。"
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

# Function to handle cron restart tasks
cron_restart() {
  echo -e "------------------------------------------------------------------"
  echo -e "realm定时重启任务: "
  echo -e "-----------------------------------"
  echo -e "[1] 配置realm定时重启任务"
  echo -e "[2] 删除realm定时重启任务"
  echo -e "-----------------------------------"
  read -p "请选择: " numcron
  if [ "$numcron" == "1" ]; then
    echo -e "------------------------------------------------------------------"
    echo -e "realm定时重启任务类型: "
    echo -e "-----------------------------------"
    echo -e "[1] 每？小时重启"
    echo -e "[2] 每日？点重启"
    echo -e "-----------------------------------"
    read -p "请选择: " numcrontype
    if [ "$numcrontype" == "1" ]; then
      echo -e "-----------------------------------"
      read -p "每？小时重启: " cronhr
      echo "0 */$cronhr * * * systemctl restart realm" >>/etc/crontab
      echo -e "定时重启设置成功！"
    elif [ "$numcrontype" == "2" ]; then
      echo -e "-----------------------------------"
      read -p "每日？点重启: " cronhr
      echo "0 $cronhr * * * systemctl restart realm" >>/etc/crontab
      echo -e "定时重启设置成功！"
    else
      echo "输入错误，请重试"
      exit
    fi
  elif [ "$numcron" == "2" ]; then
    sed -i "/realm/d" /etc/crontab
    echo -e "定时重启任务删除完成！"
  else
    echo "输入错误，请重试"
    exit
  fi
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
        3)
            show_all_conf
            ;;
        4)
            delete_forward
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
        8)
            cron_restart
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
