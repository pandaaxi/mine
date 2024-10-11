#!/bin/bash

# Menu

main_menu() {
    while true; do
        clear
        echo "▶ Main Menu"
        echo "V0.0.5"
        echo "------------------------"
        echo "1. System Information Query"
        echo "2. System Update"
        echo "3. System Clean"
        echo "------------------------"
        echo "4. System Tools ▶"
        echo "5. Docker Management ▶"
        echo "6. WARP Management ▶"
        echo "7. WGCF Management ▶"
        echo "8. BBR Management ▶"
        echo "------------------------"
        echo "00. Script Update"
        echo "0. Quit"
        echo "------------------------"
        read -p "Enter your choice: " choice

        case $choice in
            1)
                system_info_query
                ;;
            2)
                system_update
                ;;
            3)
                system_clean
                ;;
            4)
                system_tools
                ;;
            5)
                docker_management
                ;;
            6)
                warp_management
                ;;
            7)
                wgcf
                ;;
            8)
                bbr_management
                ;;
            00)
                update_script
                ;;
            0)
                quit_script
                ;;
            *)
                echo "Invalid input! Please enter a valid option."
                ;;
        esac
        read -p "Press any key to continue..." key
    done
}

# Non Manual Function
output_status() {
    output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
        NR > 2 { rx_total += $2; tx_total += $10 }
        END {
            rx_units = "Bytes";
            tx_units = "Bytes";
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

            if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

            printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
        }' /proc/net/dev)

}

ip_address() {
ipv4_address=$(curl -s ipv4.ip.sb)
ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}

current_timezone() {
    if grep -q 'Alpine' /etc/issue; then
       date +"%Z %z"
    else
       timedatectl | grep "Time zone" | awk '{print $3}'
    fi

}

# Function Script

# Function to retrieve and display system information
system_info_query() {
    clear
    # Function: Get IPv4 and IPv6 addresses
    ip_address

    if [ "$(uname -m)" == "x86_64" ]; then
      cpu_info=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
    else
      cpu_info=$(lscpu | grep 'BIOS Model name' | awk -F': ' '{print $2}' | sed 's/^[ \t]*//')
    fi

    if [ -f /etc/alpine-release ]; then
        # Use the following command for Alpine Linux to get CPU usage
        cpu_usage_percent=$(top -bn1 | grep '^CPU' | awk '{print " "$4}' | cut -c 1-2)
    else
        # Use the following command for other systems to get CPU usage
        cpu_usage_percent=$(top -bn1 | grep "Cpu(s)" | awk '{print " "$2}')
    fi

    cpu_cores=$(nproc)

    mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

    disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')

    country=$(curl -s ipinfo.io/country)
    city=$(curl -s ipinfo.io/city)

    isp_info=$(curl -s ipinfo.io/org)

    cpu_arch=$(uname -m)

    hostname=$(hostname)

    kernel_version=$(uname -r)

    congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
    queue_algorithm=$(sysctl -n net.core.default_qdisc)

    # Attempt to use lsb_release to get system information
    os_info=$(lsb_release -ds 2>/dev/null)

    # If the lsb_release command fails, try other methods
    if [ -z "$os_info" ]; then
      # Check common release files
      if [ -f "/etc/os-release" ]; then
        os_info=$(source /etc/os-release && echo "$PRETTY_NAME")
      elif [ -f "/etc/debian_version" ]; then
        os_info="Debian $(cat /etc/debian_version)"
      elif [ -f "/etc/redhat-release" ]; then
        os_info=$(cat /etc/redhat-release)
      else
        os_info="Unknown"
      fi
    fi

    output_status

    current_time=$(date "+%Y-%m-%d %I:%M %p")

    swap_used=$(free -m | awk 'NR==3{print $3}')
    swap_total=$(free -m | awk 'NR==3{print $2}')

    if [ "$swap_total" -eq 0 ]; then
        swap_percentage=0
    else
        swap_percentage=$((swap_used * 100 / swap_total))
    fi

    swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

    runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d days ", run_days); if (run_hours > 0) printf("%d hrs ", run_hours); printf("%d mins\n", run_minutes)}')

    timezone=$(current_timezone)

    echo ""
    echo "System Information Query"
    echo "------------------------"
    echo "Hostname: $hostname"
    echo "ISP: $isp_info"
    echo "------------------------"
    echo "OS Version: $os_info"
    echo "Linux Version: $kernel_version"
    echo "------------------------"
    echo "CPU Architecture: $cpu_arch"
    echo "CPU Model: $cpu_info"
    echo "CPU Cores: $cpu_cores"
    echo "------------------------"
    echo "CPU Usage: $cpu_usage_percent%"
    echo "Physical Memory: $mem_info"
    echo "Swap Memory: $swap_info"
    echo "Disk Usage: $disk_info"
    echo "------------------------"
    echo "$output"
    echo "------------------------"
    echo "Network Congestion Algorithm: $congestion_algorithm $queue_algorithm"
    echo "------------------------"
    echo "Public IPv4 Address: $ipv4_address"
    echo "Public IPv6 Address: $ipv6_address"
    echo "------------------------"
    echo "Geographic Location: $country $city"
    echo "System Timezone: $timezone"
    echo "System Time: $current_time"
    echo "------------------------"
    echo "System Uptime: $runtime"
    echo
}

# Function to update the system
system_update() {

    # Update system on Debian-based systems
    if [ -f "/etc/debian_version" ]; then
        apt update -y && DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
    fi

    # Update system on Red Hat-based systems
    if [ -f "/etc/redhat-release" ]; then
        yum -y update
    fi

    # Update system on Alpine Linux
    if [ -f "/etc/alpine-release" ]; then
        apk update && apk upgrade
    fi

}

# Function to clean up the system
system_clean() {
    clean_debian() {
        apt autoremove --purge -y
        apt clean -y
        apt autoclean -y
        apt remove --purge $(dpkg -l | awk '/^rc/ {print $2}') -y
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=50M
        apt remove --purge $(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/{print $2}' | grep -v $(uname -r | sed 's/-.*//') | xargs) -y
    }

    clean_redhat() {
        yum autoremove -y
        yum clean all
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=50M
        yum remove $(rpm -q kernel | grep -v $(uname -r)) -y
    }

    clean_alpine() {
        apk del --purge $(apk info --installed | awk '{print $1}' | grep -v $(apk info --available | awk '{print $1}'))
        apk autoremove
        apk cache clean
        rm -rf /var/log/*
        rm -rf /var/cache/apk/*

    }

    # Main script
    if [ -f "/etc/debian_version" ]; then
        # Debian-based systems
        clean_debian
    elif [ -f "/etc/redhat-release" ]; then
        # Red Hat-based systems
        clean_redhat
    elif [ -f "/etc/alpine-release" ]; then
        # Alpine Linux
        clean_alpine
    fi

}

# Sub menu for System Tools
system_tools() {
while true; do
    clear
    echo "▶ System Tools"
    echo "------------------------"
    echo "1. Set DNS Address"
    echo "2. Set SSH Port"
    echo "3. Manage SSH Key Authentication"
    echo "4. Swap Memory Management"
    echo "5. Reboot Server"
    echo "------------------------"
    echo "0. Return to Main Menu"
    echo "------------------------"
    read -p "Enter your choice: " sub_choice

    case $sub_choice in
        1)
            set_dns
            ;;
        2)
            echo "Enter the new SSH port: "
            read new_port
            set_ssh_port $new_port
            ;;
        3)
            manage_ssh_key_auth
            ;;
        4)
            while true; do
                swap_used=$(free -m | awk 'NR==3{print $3}')
                swap_total=$(free -m | awk 'NR==3{print $2}')

                if [ "$swap_total" -eq 0 ]; then
                swap_percentage=0
                else
                swap_percentage=$((swap_used * 100 / swap_total))
                fi

                swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"
                clear
                echo "Current Swap Memory: $swap_info"
                echo ""
                echo "Swap Memory Management"
                echo "------------------------"
                echo "1. Add 1024MB Swap"
                echo "2. Add 2048MB Swap"
                echo "3. Manually Add Swap Memory"
                echo "4. Disable Swap"
                echo "------------------------"
                echo "0. Return to System Tools"
                echo "------------------------"
                read -p "Enter your choice: " swap_choice

                case $swap_choice in
                    1) add_swap 1024 ;;
                    2) add_swap 2048 ;;
                    3) 
                        echo "Enter the swap size in MB: "
                        read swap_size
                        add_swap $swap_size
                        ;;
                    4) disable_swap ;;
                    0) break ;;
                    *) echo "Invalid choice!" ;;
                esac
            done
            ;;
        5)
            reboot_server
            ;;
        0)
            break  # Exit the loop, return to the main menu
            ;;
        *)
            echo "Invalid input!"
            ;;
    esac
    break_end
done
}

set_dns() {
    # Check if the machine has an IPv6 address
    ipv6_available=0
    if [[ $(ip -6 addr | grep -c "inet6") -gt 0 ]]; then
        ipv6_available=1
    fi

    echo "nameserver $dns1_ipv4" > /etc/resolv.conf
    echo "nameserver $dns2_ipv4" >> /etc/resolv.conf

    if [[ $ipv6_available -eq 1 ]]; then
        echo "nameserver $dns1_ipv6" >> /etc/resolv.conf
        echo "nameserver $dns2_ipv6" >> /etc/resolv.conf
    fi

    echo "DNS addresses updated"
    echo "------------------------"
    cat /etc/resolv.conf
    echo "------------------------"
}

set_ssh_port() {
    new_port=$1

    # Backup the SSH configuration file
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # Ensure the Port line is uncommented and updated
    sed -i 's/^\s*#\?\s*Port/Port/' /etc/ssh/sshd_config

    # Replace the port number in the SSH configuration file
    sed -i "s/Port [0-9]\+/Port $new_port/g" /etc/ssh/sshd_config

    # Restart the SSH service
    restart_ssh
    echo "SSH port has been changed to: $new_port"

    clear
    iptables_open
    remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
}

manage_ssh_key_auth() {
    # Generate an SSH key pair
    ssh-keygen -t ed25519 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""

    # Add the public key to authorized_keys
    cat ~/.ssh/sshkey.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    ip_address
    echo -e "Private key information has been generated. Be sure to copy and save it as a file named ${huang}${ipv4_address}_ssh.key${bai} for future SSH logins."
    echo "--------------------------------"
    cat ~/.ssh/sshkey
    echo "--------------------------------"

    # Update SSH configuration for key-based authentication
    sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
           -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
           -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
           -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
    echo -e "${lv}ROOT key-based login has been enabled. Password login for ROOT is disabled. Changes will take effect on reconnection.${bai}"
}

add_swap() {
    swap_size=$1

    # Turn off any existing swap
    swapoff -a

    # Remove any existing swapfile
    rm -f /swapfile

    # Create a new swapfile of the specified size
    dd if=/dev/zero of=/swapfile bs=1M count=$swap_size
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    # Add the swapfile to /etc/fstab for persistence
    if ! grep -q '/swapfile swap swap defaults 0 0' /etc/fstab; then
        echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
    fi

    echo -e "Swap memory of size ${huang}${swap_size}${bai}MB has been added."
}

disable_swap() {
    # Disable swap memory
    swapoff /swapfile

    # Remove the swapfile entry from /etc/fstab
    sed -i '/\/swapfile swap swap defaults 0 0/d' /etc/fstab

    # Remove the swapfile
    rm -f /swapfile

    echo "Swap memory disabled."
}


reboot_server() {
    read -p "$(echo -e "${huang}Do you want to reboot the server now? (Y/N): ${bai}")" rboot
    case "$rboot" in
        [Yy])
            echo "Rebooting..."
            reboot
            ;;
        [Nn])
            echo "Reboot canceled."
            ;;
        *)
            echo "Invalid choice, please enter Y or N."
            ;;
    esac
}


# Docker Sub Menu
docker_management() {
    while true; do
        clear
        echo "▶ Docker Management"
        echo "------------------------"
        echo "1. Install/Update Docker Environment"
        echo "2. View Docker Global Status"
        echo "3. Clean Up Unused Docker Resources"
        echo "4. Uninstall Docker Environment"
        echo "------------------------"
        echo "0. Return to Main Menu"
        echo "------------------------"
        read -p "Enter your choice: " sub_choice

        case $sub_choice in
            1)
                clear
                install_docker
                ;;
            2)
                clear
                echo "Docker Version"
                docker -v
                docker-compose --version

                echo ""
                echo "Docker Image List"
                docker image ls
                echo ""
                echo "Docker Container List"
                docker ps -a
                echo ""
                echo "Docker Volume List"
                docker volume ls
                echo ""
                echo "Docker Network List"
                docker network ls
                echo ""
                ;;
            3)
                clear
                read -p "$(echo -e "Are you sure you want to clean up unused images, containers, networks, and volumes? (Y/N): ")" choice
                case "$choice" in
                    [Yy])
                        docker system prune -af --volumes
                        echo "Cleaned up unused Docker resources."
                        ;;
                    [Nn])
                        ;;
                    *)
                        echo "Invalid choice, please enter Y or N."
                        ;;
                esac
                ;;
            4)
                clear
                read -p "$(echo -e "Are you sure you want to uninstall the Docker environment? (Y/N): ")" choice
                case "$choice" in
                    [Yy])
                        docker rm $(docker ps -a -q)
                        docker rmi $(docker images -q)
                        docker network prune
                        remove_docker
                        echo "Docker environment uninstalled."
                        ;;
                    [Nn])
                        ;;
                    *)
                        echo "Invalid choice, please enter Y or N."
                        ;;
                esac
                ;;
            0)
                break  # Exit the loop, return to the main menu
                ;;
            *)
                echo "Invalid input!"
                ;;
        esac
    done
}

install_docker() {
    clear
    echo "Installing Docker..."
    DIR="/root/containers/"
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
        echo "Directory $DIR created."
    else
        cd "$DIR"
        echo "Changed directory to $DIR."
    fi

    # Install Docker using the convenience script
    curl -fsSL https://get.docker.com | sh
    
    # Start and enable the Docker service
    systemctl start docker
    systemctl enable docker
    
    # Download and install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    echo "Docker installation completed."
}

remove_docker() {
    echo "Uninstalling Docker..."
    # Stop Docker services
    systemctl stop docker

    # Remove Docker packages
    apt-get purge -y docker-ce docker-ce-cli containerd.io

    # Remove Docker Compose
    rm -f /usr/local/bin/docker-compose

    # Remove Docker data
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd

    # Clean up residual configuration files
    apt-get autoremove -y
    apt-get clean

    echo "Docker has been successfully uninstalled."
}


# WARP Management Submenu
warp_management() {
    while true; do
        clear
        echo "▶ WARP Management"
        echo "------------------------"
        echo "1. Install WARP Client"
        echo "2. Check WARP Status"
        echo "3. Enable WARP"
        echo "4. Disable WARP"
        echo "5. Uninstall WARP Client"
        echo "------------------------"
        echo "0. Return to Main Menu"
        echo "------------------------"
        read -p "Enter your choice: " sub_choice

        case $sub_choice in
            1)
                install_warp
                ;;
            2)
                check_warp_status
                ;;
            3)
                enable_warp
                ;;
            4)
                disable_warp
                ;;
            5)
                uninstall_warp
                ;;
            0)
                break  # Exit the loop, return to the main menu
                ;;
            *)
                echo "Invalid input!"
                ;;
        esac
    done
}

install_warp() {
    clear
    echo "Installing WARP Client..."
    
    # Add the Cloudflare WARP repository and GPG key
    apt update
    apt install -y curl gnupg
    curl -s https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
    echo "deb [arch=amd64] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list

    # Update package list and install WARP
    apt update
    apt install -y cloudflare-warp

    # Register and connect WARP client
    warp-cli register
    warp-cli connect

    echo "WARP Client installation completed."
}

check_warp_status() {
    clear
    echo "Checking WARP Status..."
    
    # Display WARP client status
    warp-cli status
    echo ""
}

enable_warp() {
    clear
    echo "Enabling WARP..."
    
    # Connect to WARP
    warp-cli connect
    echo "WARP has been enabled."
}

disable_warp() {
    clear
    echo "Disabling WARP..."
    
    # Disconnect from WARP
    warp-cli disconnect
    echo "WARP has been disabled."
}

uninstall_warp() {
    clear
    echo "Uninstalling WARP Client..."

    # Disconnect and remove the WARP client
    warp-cli disconnect
    apt remove -y cloudflare-warp
    apt autoremove -y
    rm -f /etc/apt/sources.list.d/cloudflare-client.list

    echo "WARP Client has been uninstalled."
}

# Sub-menu for wgcf
wgcf() {
    while true; do
        echo "Choose an option:"
        echo "1. Generate configuration"
        echo "2. Check status"
        echo "3. Trace"
        echo "4. Check reserved ID"
        echo "0. Back to main menu"

        read -p "Enter your choice: " choice

        case $choice in
            1)
                generate_wgcf_config
                ;;
            2)
                check_status
                ;;
            3)
                trace
                ;;
            4)
                check_reserved
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid choice. Please enter a valid option."
                ;;
        esac
    done
}

# Function to generate configuration
generate_wgcf_config() {
    apt install jq -y
    wgcf_file="/root/warpgen/wgcf"

    # Check if wgcf file already exists
    if [ ! -e "$wgcf_file" ]; then
        # Check the system's architecture
        mkdir -p /root/warpgen/
        arch=$(uname -m)

        if [ "$arch" == "x86_64" ]; then
            echo "Downloading for AMD..."
            wget -O "$wgcf_file" https://github.com/ViRb3/wgcf/releases/download/v2.2.19/wgcf_2.2.19_linux_amd64
        elif [ "$arch" == "aarch64" ]; then
            echo "Downloading for ARM..."
            wget -O "$wgcf_file" https://github.com/ViRb3/wgcf/releases/download/v2.2.19/wgcf_2.2.19_linux_arm64
        else
            echo "Unsupported architecture: $arch"
            exit 1
        fi

        chmod +x "$wgcf_file"  # Make the downloaded file executable
    else
        echo "wgcf file already exists. Skipping download."
    fi
    cd /root/warpgen/

    rm -fr wgcf-account.toml
    ./wgcf register
    sleep 2 # Adding a delay of 2 seconds
    cat wgcf-account.toml # Displaying the contents of wgcf-account.toml
    read -p "Enter the new WGCF license key: " new_key
    WGCF_LICENSE_KEY="$new_key" ./wgcf update
    sleep 2
    cat wgcf-account.toml # Displaying the contents of wgcf-account.toml
    # Fetching device_id and access_token from wgcf-account.toml
    device_id=$(grep -oP "device_id = '\K[^']+" wgcf-account.toml)
    access_token=$(grep -oP "access_token = '\K[^']+" wgcf-account.toml)

    # Fetching information using curl command
    response=$(curl --request GET "https://api.cloudflareclient.com/v0a2158/reg/$device_id" \
        --silent \
        --location \
        --header 'User-Agent: okhttp/3.12.1' \
        --header 'CF-Client-Version: a-6.10-2158' \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $access_token")

    # Extracting client_id from the response
    client_id=$(echo "$response" | jq -r '.config.client_id')

    # Converting client_id into array format [14, 116, 111]
    client_id_array=$(echo "$client_id" | base64 -d | xxd -p | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')

    ./wgcf generate

    sleep 2 # Adding a delay of 2 seconds

    # Fetching PrivateKey and Address from wgcf-profile.conf
    private_key=$(grep -oP "PrivateKey = \K[^ ]+" wgcf-profile.conf)
    addresses=$(grep -oP "Address = \K[^ ]+" wgcf-profile.conf)

    # Extracting individual IPv4 and IPv6 addresses
    ipv4=$(echo "$addresses" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+')
    ipv6=$(echo "$addresses" | grep -Eo '([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}/[0-9]+')
    # Creating wireguard.json file
    cat > wireguard.json <<EOF
{
    "tag": "xray-wg-warp",
    "protocol": "wireguard",
    "settings": {
        "secretKey": "$private_key",
        "address": [
            "$ipv4",
            "$ipv6"
        ],
        "peers": [
            {
                "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                "allowedIPs": [
                    "0.0.0.0/0",
                    "::/0"
                ],
                "endpoint": "162.159.193.10:2408"
            }
        ],
        "reserved": $client_id_array
    }
}
EOF
    sleep 2
    echo "wireguard.json file created successfully."
    cat wireguard.json
}

# Function to check status
check_status() {
    cd && cd /root/warpgen/
    ./wgcf status
}

# Function to trace
trace() {
    cd && cd /root/warpgen/
    ./wgcf trace
}

check_reserved() {
    apt install jq -y
    cd && cd /root/warpgen/
    cat wgcf-account.toml # Displaying the contents of wgcf-account.toml
    # Fetching device_id and access_token from wgcf-account.toml
    device_id=$(grep -oP "device_id = '\K[^']+" wgcf-account.toml)
    access_token=$(grep -oP "access_token = '\K[^']+" wgcf-account.toml)

    # Fetching information using curl command
    response=$(curl --request GET "https://api.cloudflareclient.com/v0a2158/reg/$device_id" \
        --silent \
        --location \
        --header 'User-Agent: okhttp/3.12.1' \
        --header 'CF-Client-Version: a-6.10-2158' \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $access_token")

    # Extracting client_id from the response
    client_id=$(echo "$response" | jq -r '.config.client_id')

    # Converting client_id into array format [14, 116, 111]
    client_id_array=$(echo "$client_id" | base64 -d | xxd -p | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')
    echo $client_id_array
}

update_script() {
    echo "Updating the script..."

    # Download the updated script
    updated_script_url="https://raw.githubusercontent.com/pandaaxi/mine/main/panda.sh"
    if curl -fsSL -o panda.sh "$updated_script_url"; then
        chmod +x panda.sh
        echo "Script updated successfully."
        exit 0  # Exit after updating to avoid any issues
    else
        echo "Failed to update the script. Please check the provided link."
    fi
}

# bbr management
bbr_management() {
    # Install necessary dependencies if needed
    if ! command -v wget &> /dev/null; then
        apt-get update && apt-get install -y wget
    fi

    # Download and execute tcpx.sh script
    wget --no-check-certificate -O tcpx.sh https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh
    chmod +x tcpx.sh
    ./tcpx.sh

    # Clean up after running the script
    rm -f tcpx.sh

    echo "BBR Management completed. Returning to Main Menu."
    read -p "Press any key to continue..." key
}

quit_script() {
    echo "Exiting..."
    exit 0
}

main_menu
