#!/bin/bash

# Function script
# Function to install Docker
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

    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

    echo "Docker is already installed."
}

# Function to uninstall Docker
uninstall_docker() {
    clear
    read -p "Are you sure want to delete Docker？(Y/N): " choice
    case "$choice" in
        [Yy])
            echo "Removing Docker containers and volumes..."
            docker stop $(docker ps -a -q) &>/dev/null
            docker rm -f $(docker ps -a -q) &>/dev/null
            docker rmi $(docker images -q) &>/dev/null
            docker network prune
            docker volume prune -f

            echo "Uninstalling Docker..."
            apt-get remove docker -y
            apt-get remove docker-ce -y
            apt-get purge docker-ce -y
            rm -rf /var/lib/docker

            echo "Docker has been uninstalled."
            ;;
        [Nn])
            ;;
        *)
            echo "Invalid answer, please input N or Y。"
            ;;
    esac
}

# Function to install Caddy
install_caddy() {
    echo "Installing Caddy..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        read -p "Docker is not available! Do you want to install? (y/n) " docker_choice
        if [ "$docker_choice" == "y" ]; then
            install_docker
        else
            echo "Docker is not installed. Please install Docker first."
            return
        fi
    fi

    mkdir -p /root/containers/caddy && touch /root/containers/caddy/Caddyfile
    cd /root/containers/caddy

    read -p "Enter the domain for caddy: " caddy_domain
    echo "Updating Caddyfile for $caddy_domain..."
    {
        echo "{"
        echo "  email mail@$caddy_domain"
        echo "}"
    } >> /root/containers/caddy/Caddyfile
    echo "Caddyfile updated."

        cat <<EOF > docker-compose.yml
version: '3.3'

networks:
  caddy:

services:
  caddy:
    image: caddy:latest
    restart: unless-stopped
    container_name: caddy
    ports:
      - 80:80
      - 443:443
    volumes:
      - /root/containers/caddy/Caddyfile:/etc/caddy/Caddyfile
      - /root/containers/caddy/site:/srv
      - /root/containers/caddy/caddy_data:/data
      - /root/containers/caddy/caddy_config:/config
    networks:
      - caddy

volumes:
  caddy_data:
    external: true
  caddy_config:
EOF
        echo "Created docker-compose.yml"
        docker compose up -d

}

# Function to install alist
install_alist() {
    echo "Installing alist..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        read -p "Docker is not available! Do you want to install? (y/n) " docker_choice
        if [ "$docker_choice" == "y" ]; then
            install_docker
        else
            echo "Docker is not installed. Please install Docker first."
            return
        fi
    fi

    # Check if the Caddy container is running
    if [ -z "$(docker ps -q -f name=caddy)" ]; then
        echo "Caddy container is not running."
        read -p "Do you want to install and run Caddy? (y/n) " caddy_choice
        if [ "$caddy_choice" == "y" ]; then
            install_caddy
        fi
    fi

    # Ask for the alist domain and update Caddyfile
    read -p "Enter the domain for alist: " alist_domain
    echo "Updating Caddyfile for $alist_domain..."
    {
        echo "$alist_domain {"
        echo "  reverse_proxy alist:5244"
        echo "}"
    } >> /root/containers/caddy/Caddyfile
    echo "Caddyfile updated."
    
    #continue install alist
    mkdir -p /root/containers/alist
    cd /root/containers/alist

        cat <<EOF > docker-compose.yml
version: '3.3'

networks:
  caddy:

services:
    alist:
        image: 'xhofe/alist:latest'
        container_name: alist
        restart: unless-stopped
        volumes:
            - /etc/alist:/opt/alist/data
        ports:
            - 5244:5244
        environment:
            - PUID=0
            - PGID=0
            - UMASK=022
        networks:
            - caddy
EOF
        echo "Created docker-compose.yml"
        docker compose up -d

        docker exec -it alist ./alist admin random
}

# Function to install Marzban-Node
install_marzban_node() {
    echo "Installing Marzban-Node..."
    if ! command -v docker &> /dev/null; then
        read -p "Docker is not available! Do you want to install? (y/n) " docker_choice
        if [ "$docker_choice" == "y" ]; then
            install_docker
        else
            echo "Docker is not installed. Please install Docker first."
        fi
    else

        #update package list
        cd /root/containers/
        apt-get update

        # Clone the Marzban-Node repository
        git clone https://github.com/Gozargah/Marzban-node
        cd /root/containers/Marzban-node

        # Remove existing docker-compose.yml
        rm "docker-compose.yml"

        # Create a new docker-compose.yml
        cat <<EOF > docker-compose.yml
services:
  marzban-node:
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host

    environment:
      SSL_CLIENT_CERT_FILE: "/var/lib/marzban-node/ssl_client_cert.pem"

    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node
EOF
        echo "Created new docker-compose.yml"

        # Start the Docker Compose service
        docker compose up -d

        # Ask for SSL certificate location
        echo "Please paste the SSL certificate content below (press Ctrl+D when finished):"
        ssl_cert_path=$(</dev/stdin)

        # Remove ssl_client_cert.pem
        rm "/var/lib/marzban-node/ssl_client_cert.pem"

        # Create a new ssl_client_cert.pem with provided path
        echo "$ssl_cert_path" > /var/lib/marzban-node/ssl_client_cert.pem

        echo "SSL certificate updated at /var/lib/marzban-node/ssl_client_cert.pem"

        # Restart Docker Compose
        docker compose down -v
        docker compose up -d
    fi
}


# Function to install haproxy to marzban
turn_on_haproxy_marzban() {
    read -p "Enter 'p' for panel or 'n' for node: " choice
    read -p "Please input your panel domain: " domain
    if [ "$choice" = "p" ]; then
        # Configure Marzban environment file
        sudo sed -i 's/UVICORN_HOST="0.0.0.0"/UVICORN_HOST="127.0.0.1"/g' /opt/marzban/.env
        sudo sed -i 's/UVICORN_PORT=443/UVICORN_PORT=10000/g' /opt/marzban/.env
        echo '      XRAY_FALLBACKS_INBOUND_TAG="TROJAN_FALLBACK_INBOUND"' >> /opt/marzban/.env

        # Restart Marzban
        marzban restart

    elif [ "$choice" = "n" ]; then
        echo "Skipping .env setup for Marzban."
    else
        echo "Invalid input. Enter 'p' for panel or 'n' for node."
    fi

    # Remove existing HAProxy
    sudo systemctl unmask haproxy
    sudo systemctl stop haproxy
    sudo systemctl disable haproxy
    sudo apt-get purge haproxy

    # Update and install HAProxy
    sudo apt update
    sudo apt install -y haproxy

    # Configure HAProxy using echo and tee
    echo 'listen front
        mode tcp
        bind *:443

        tcp-request inspect-delay 5s
        tcp-request content accept if { req_ssl_hello_type 1 }

        use_backend panel if { req.ssl_sni -m end '$domain' }

        use_backend reality if { req.ssl_sni -m end www.mysql.com }
        use_backend reality if { req.ssl_sni -m end www.eepurl.com }
        use_backend reality if { req.ssl_sni -m end a.teads.tv }
        use_backend reality if { req.ssl_sni -m end podcasts.apple.com }

        use_backend grpc if { req.ssl_sni -m end www.naruto-official.com }
        use_backend grpc if { req.ssl_sni -m end www.eventbrite.com }
        use_backend grpc if { req.ssl_sni -m end www.booking.com }
        use_backend grpc if { req.ssl_sni -m end www.trustpilot.com }

        default_backend fallback

    backend panel
        mode tcp
        server srv1 127.0.0.1:10000

    backend fallback
        mode tcp
        server srv1 127.0.0.1:11000

    backend grpc
        mode tcp
        server srv1 127.0.0.1:13000

    backend reality
        mode tcp
        server srv1 127.0.0.1:12000 send-proxy
    ' >> /etc/haproxy/haproxy.cfg

    # Restart HAProxy service
    sudo systemctl restart haproxy
}

# Function to install Marzban Panel
install_marzban_panel() {
    echo "Installing Marzban Panel..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        read -p "Docker is not available! Do you want to install? (y/n) " docker_choice
        if [ "$docker_choice" == "y" ]; then
            install_docker
        else
            echo "Docker is not installed. Please install Docker first."
            return
        fi
    fi

    allow_port_for_marzban
    apt update && apt upgrade -y && sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install

    # Replace the database
    cp /home/ubuntu/db.sqlite3 /var/lib/marzban/db.sqlite3
    sudo apt-get install socat


    # Install Xray for ARM
    if [ "$(arch)" == "aarch64" ]; then
        apt install unzip
        rm -r /var/lib/marzban/xray-core/
        mkdir -p /var/lib/marzban/xray-core/
        cd /var/lib/marzban/xray-core/
        wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip -4
        unzip Xray-linux-arm64-v8a.zip
        rm Xray-linux-arm64-v8a.zip
        cd
    fi

    # Install Xray for AMD
    if [ "$(arch)" == "x86_64" ]; then
        apt install unzip
        rm -r /var/lib/marzban/xray-core/
        mkdir -p /var/lib/marzban/xray-core/
        cd /var/lib/marzban/xray-core/
        wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -4
        unzip Xray-linux-64.zip
        rm Xray-linux-64.zip
        cd
    fi
    # Run script to register SSL for the domain (if provided)
    read -p "Enter the domain for Marzban SSL registration (leave blank to skip): " domain
    if [ -n "$domain" ]; then
        # Register SSL for the domain
        mkdir -p /var/lib/marzban/certs
        
        register_ssl "$domain" "/var/lib/marzban/certs"

        # Configure Marzban environment file
        echo 'UVICORN_HOST="0.0.0.0"
        UVICORN_PORT=443

        SUDO_USERNAME="1625b6aa-2815-40ec-a218-11e6c0262e52"
        SUDO_PASSWORD="4ae3db97-9ff0-4305-a68d-adbc6e0961ec"

        UVICORN_SSL_CERTFILE="/var/lib/marzban/certs/'$domain'.cert.crt"
        UVICORN_SSL_KEYFILE="/var/lib/marzban/certs/'$domain'.private.key"

        XRAY_JSON="/var/lib/marzban/xray_config.json"
        XRAY_SUBSCRIPTION_URL_PREFIX=https://'$domain'
        XRAY_EXECUTABLE_PATH="/var/lib/marzban/xray-core/xray"

        SQLALCHEMY_DATABASE_URL="sqlite:////var/lib/marzban/db.sqlite3"
        ' >> /opt/marzban/.env
    else
        # Configure Marzban environment file without SSL details
        echo 'UVICORN_HOST="0.0.0.0"
        UVICORN_PORT=443

        SUDO_USERNAME="1625b6aa-2815-40ec-a218-11e6c0262e52"
        SUDO_PASSWORD="4ae3db97-9ff0-4305-a68d-adbc6e0961ec"

        XRAY_JSON="/var/lib/marzban/xray_config.json"
        XRAY_EXECUTABLE_PATH="/var/lib/marzban/xray-core/xray"

        SQLALCHEMY_DATABASE_URL="sqlite:////var/lib/marzban/db.sqlite3"
        ' > /opt/marzban/.env
    fi

    marzban restart
}

# Function to uninstall Marzban Panel
uninstall_marzban_panel() {
    echo "Uninstalling Marzban Panel..."
    cd && marzban uninstall
}

# Function to uninstall Marzban Node
uninstall_marzban_node() {
    echo "Uninstalling Marzban Node..."
    cd && cd Marzban-node && docker compose down -v && cd && rm -rf Marzban-node && rm -r /var/lib/marzban-node
}

# Function to uninstall all Marzban components
uninstall_all_marzban() {
    echo "Uninstalling all Marzban components..."
    
    # Uninstall Marzban Panel
    cd && marzban uninstall
    
    # Uninstall Marzban Node
    cd && cd Marzban-node && docker compose down -v && cd && rm -rf Marzban-node && rm -r /var/lib/marzban-node
}

# Function to update the script from the provided link
update_script() {
    echo "Updating the script..."

    # Download the updated script
    updated_script_url="https://raw.githubusercontent.com/vblyrpv074/mine/main/me.sh"
    if curl -fsSL -o me.sh "$updated_script_url"; then
        chmod +x me.sh
        echo "Script updated successfully."
        exit 0  # Exit after updating to avoid any issues
    else
        echo "Failed to update the script. Please check the provided link."
    fi
}

# Function to register SSL certificates with embedded random string generation
register_ssl() {
  local domain=$1
  local certs_dir=$2

  # Generate a random string of specified length
  local length=5
  local characters="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  local random_string=""

  for ((i = 0; i < length; i++)); do
    rand_index=$((RANDOM % ${#characters}))
    random_string+=${characters:$rand_index:1}
  done

  local email_address="${random_string}@gmail.com"

  cd ~
  curl https://get.acme.sh | sh
  ~/.acme.sh/acme.sh --register-account -m "$email_address" --issue -d "$domain" --standalone --key-file "$certs_dir/${domain}.private.key" --fullchain-file "$certs_dir/${domain}.cert.crt" --force
}

# Function to display SSL certificate (Node)
display_ssl_certificate() {
    echo "Displaying SSL certificate (Node)..."
    cat /var/lib/marzban-node/ssl_cert.pem
}

# Function to update repositories
update_repositories() {
    apt update && apt upgrade -y && apt autoremove && apt autoclean
}

# Function to install Minecraft PE Server
install_minecraft_pe_server() {
    
    echo "Installing Minecraft PE Server..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        read -p "Docker is not available! Do you want to install? (y/n) " docker_choice
        if [ "$docker_choice" == "y" ]; then
            install_docker
        else
            echo "Docker is not installed. Please install Docker first."
            return
        fi
    fi

    # Ask if the user wants to modify server configuration
    read -p "Do you want to modify the server configuration? (y/n, default: n): " modify_config_choice

    if [ "$modify_config_choice" == "y" ]; then
        # Ask for the server name (container name)
        read -p "Enter the server name (container name, e.g., mc01, leave blank for default): " server_name
        server_name=${server_name:-"mc01"}

        # Ask for the server port
        read -p "Enter the server port (leave blank for default, default: 20001): " server_port
        server_port=${server_port:-20001}

        # Ask for the difficulty level
        read -p "Enter the difficulty level (easy/normal/hard, leave blank for default, default: normal): " difficulty
        difficulty=${difficulty:-"normal"}

        # Ask for the level seed
        read -p "Enter the level seed (leave blank for none): " level_seed
    else
        server_name="mc01"
        server_port="20001"
        difficulty="normal"
        level_seed=""
    fi

    # Create a directory for the Minecraft server
    mkdir -p "/containers/minecraft/$server_name"

    # Create a Docker Compose configuration for the Minecraft server
    cat <<EOF > "/containers/minecraft/$server_name/docker-compose.yml"
version: '3'
services:
  minecraft-bedrock-server:
    image: itzg/minecraft-bedrock-server
    container_name: $server_name
    environment:
      - EULA=TRUE
      - SERVER_PORT=$server_port
      - DIFFICULTY=$difficulty
    volumes:
      - $server_name:/data
volumes:
  $server_name: {}
EOF

    # Add the level seed if provided
    if [ -n "$level_seed" ]; then
        echo "      - LEVEL_SEED=$level_seed" >> "/containers/minecraft/$server_name/docker-compose.yml"
    fi

    # Add the rest of the configuration
    cat <<EOF >> "/containers/minecraft/$server_name/docker-compose.yml"
    ports:
      - "$server_port:$server_port/udp"
    volumes:
      - $server_name:/data

volumes:
  $server_name:
EOF

    # Start the Minecraft server
    cd "/containers/minecraft/$server_name"
    docker-compose up -d

    # Print server information
    echo "Minecraft PE Server '$server_name' has been installed."
    echo "Server Port: $server_port"
    echo "Difficulty: $difficulty"
    [ -n "$level_seed" ] && echo "Level Seed: $level_seed"

}

# Function to remove a Minecraft PE Server
remove_minecraft_pe_server() {

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker first."
        return
    fi

    # List the available Minecraft servers based on the image name
    server_list=$(docker ps --format "{{.Names}} {{.Image}}" | awk '$2 ~ /itzg\/minecraft-bedrock-server/ {print $1}')

    if [ -z "$server_list" ]; then
        echo "No Minecraft PE Servers are currently running."
        return
    fi

    echo "Running Minecraft PE Servers:"
    echo "$server_list"

    # Ask for the server name (container name) or provide an option to remove all
    read -p "Enter the server name to remove or 'all' to remove all servers (leave blank to cancel): " server_name

    if [ -z "$server_name" ]; then
        echo "No servers selected for removal."
        return
    fi

    if [ "$server_name" == "all" ]; then
        for server in $server_list; do
            # Prompt to back up game data before removal
            read -p "Do you want to back up game data for '$server'? (y/n): " backup_choice
            if [ "$backup_choice" == "y" ]; then
                # Create a backup of the game data
                mkdir -p "/home/mc_data/$server"
                docker run --rm -v "$server:/backup" -v "/home/mc_data/$server:/data" alpine tar -cf /backup/game_data.tar -C /backup .
            fi

            # Remove the server using Docker Compose
            cd "/containers/minecraft/$server"
            docker-compose down -v

            # Remove the Docker Compose configuration
            rm -f "/containers/minecraft/$server/docker-compose.yml"

            # Remove the server folder
            rm -rf "/containers/minecraft/$server"
        done

        # Remove all server data volumes
        docker volume rm $(docker volume ls -qf name=mc*)
        
        echo "All Minecraft PE Servers have been removed."
    else
        # Prompt to back up game data before removal
        read -p "Do you want to back up game data for '$server_name'? (y/n): " backup_choice
        if [ "$backup_choice" == "y" ]; then
            # Create a backup of the game data
            mkdir -p "/home/mc_data/$server_name"
            docker run --rm -v "$server_name:/backup" -v "/home/mc_data/$server_name:/data" alpine tar -cf /backup/game_data.tar -C /backup .
        fi

        # Remove the server using Docker Compose
        cd "/containers/minecraft/$server_name"
        docker-compose down

        # Remove the Docker Compose configuration
        rm -f "/containers/minecraft/$server_name/docker-compose.yml"

        # Remove the server folder
        rm -rf "/containers/minecraft/$server_name"

        # Remove the server data volume
        docker volume rm "$server_name"
        
        echo "Minecraft PE Server '$server_name' has been removed."
    fi
}


# Function to edit port and difficulty of the Minecraft PE Server
edit_minecraft_pe_server() {
    echo "Editing Minecraft PE Server Port and Difficulty..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        read -p "Docker is not available! Do you want to install? (y/n) " docker_choice
        if [ "$docker_choice" == "y" ]; then
            install_docker
        else
            echo "Docker is not installed. Please install Docker first."
            return
        fi
    fi

    # List the available Minecraft servers based on the image name
    server_list=$(docker ps --format "{{.Names}} {{.Image}}" | awk '$2 ~ /itzg\/minecraft-bedrock-server/ {print $1}')

    if [ -z "$server_list" ]; then
        echo "No Minecraft PE Servers are currently running."
        return
    fi

    # Prompt for server selection if there are multiple servers
    if [ $(echo "$server_list" | wc -l) -gt 1 ]; then
        echo "Select the server to edit port and difficulty:"
        select server_name in $server_list; do
            [ -n "$server_name" ] && break
        done
    else
        server_name="$server_list"
    fi

    # Get the current server directory
    server_directory="/containers/minecraft/$server_name"

    # Stop the Minecraft server using Docker Compose
    (cd "$server_directory" && docker-compose down)

    # Ask for a new server port
    read -p "Enter a new server port (leave blank to keep the current port): " new_server_port

    # Ask for a new difficulty level
    read -p "Enter a new difficulty level (easy/normal/hard, leave blank to keep the current difficulty): " new_difficulty

    # Get the current difficulty from the Docker Compose file
    difficulty=$(grep -oP "(?<=DIFFICULTY=)\w+" "$server_directory/docker-compose.yml")

    # Edit the Docker Compose file for the selected server
    sed -i -e "/container_name: $server_name/,/DIFFICULTY=/s/SERVER_PORT=[0-9]*/SERVER_PORT=${new_server_port:-$server_port}/" \
           -e "/container_name: $server_name/,/LEVEL_SEED=/s/DIFFICULTY=$difficulty/DIFFICULTY=${new_difficulty:-$difficulty}/" \
           "$server_directory/docker-compose.yml"

    # Restart the selected Minecraft server using Docker Compose
    (cd "$server_directory" && docker-compose up -d)

    echo "Minecraft PE Server configuration has been updated."
}



# Function to enable coordinates in a Minecraft PE Server
enable_coordinates() {
    echo "Enabling Coordinates in Minecraft PE Server..."

    # List the available Minecraft servers based on the image name
    server_list=$(docker ps --format "{{.Names}} {{.Image}}" | awk '$2 ~ /itzg\/minecraft-bedrock-server/ {print $1}')

    if [ -z "$server_list" ]; then
    echo "No Minecraft PE Servers are currently running."
    return
    fi

    # Prompt for server selection if there are multiple servers
    if [ $(echo "$server_list" | wc -l) -gt 1 ]; then
        echo "Select the server to enable coordinates:"
        select server_name in $server_list; do
            [ -n "$server_name" ] && break
        done
    else
        server_name="$server_list"
    fi

    # Enable coordinates in the selected server
    docker exec $server_name send-command gamerule showcoordinates true

    echo "Coordinates have been enabled in the selected Minecraft PE Server."
}


# Add this function at the end of your script
fail2bansshd() {
    # Check if Fail2Ban is installed, and install it if not
    if ! command -v fail2ban-server &> /dev/null; then
        echo "Installing Fail2Ban..."
        apt update -y
        apt install -y fail2ban
    fi

    # Start Fail2Ban and enable it on boot
    systemctl start fail2ban
    systemctl enable fail2ban

    # Copy the Fail2Ban configuration to a local file
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

    # Remove existing SSH-related configuration files
    rm -rf /etc/fail2ban/jail.d/*
    
    echo '[sshd]
    enabled = true
    mode   = normal
    backend = systemd' >> /etc/fail2ban/jail.d/sshd.local

    # Restart Fail2Ban to apply the configuration changes
    systemctl restart fail2ban

    # Display Fail2Ban status and SSHD status in Fail2Ban
    echo "Fail2Ban Status:"
    systemctl status fail2ban

    echo "Fail2Ban Status for SSHD:"
    fail2ban-client status sshd
}

fail2banstatus() {
    # Display Fail2Ban status and SSHD status in Fail2Ban
    echo "Fail2Ban Status:"
    systemctl status fail2ban

    echo "Fail2Ban Client Status:"
    fail2ban-client status

    echo "Fail2Ban Status for SSHD:"
    fail2ban-client status sshd
}

# Function to install UFW (Uncomplicated Firewall)
install_ufw() {
    echo "Installing UFW (Uncomplicated Firewall)..."
    apt-get update
    apt-get install ufw -y
    ufw default deny incoming
    ufw default allow outgoing
    echo "UFW has been installed and default policies set."
}

# Function to allow ports for Marzban
allow_port_for_marzban() {
    echo "Allowing ports for Marzban..."
    ufw enable
    ufw allow 22/tcp
    #Marzban Node Port
    ufw allow 62050/tcp
    ufw allow 62051/tcp
    #Https Port
    ufw allow 443/tcp
    ufw allow 2087/tcp
    ufw allow 2096/tcp
    ufw allow 8443/tcp
    #Http Port
    ufw allow 80/tcp
    ufw allow 8080/tcp
    ufw allow 20001,20002,20003,20004/tcp
    sudo ufw reload
    ufw status
    echo "Ports for Marzban have been allowed."
}

# Function to allow ports for Wordpress
allow_port_for_wordpress() {
    echo "Allowing ports for Wordpress..."
    ufw enable
    ufw allow 22/tcp
    ufw allow 443/tcp
    ufw allow 80/tcp
    sudo ufw reload
    ufw status
    echo "Ports for Wordpress have been allowed."
}

# Function to allow ports for OpenVPN
allow_port_for_openvpn() {
    echo "Allowing ports for OpenVPN..."
    ufw enable
    ufw allow 22/tcp
    ufw allow 443/tcp
    ufw allow 943/tcp
    ufw allow 1194/udp
    sudo ufw reload
    ufw status
    echo "Ports for OpenVPN have been allowed."
}

# Function to reset UFW to default settings
reset_ufw() {
    echo "Resetting UFW to default settings..."
    ufw reset
    ufw disable
    echo "UFW has been reset and disable"
}

# Function to install OpenVPN AS
install_openvpn_as() {
    echo "Installing OpenVPN Access Server..."

    # Check the architecture
    if [ "$(uname -m)" == "aarch64" ]; then
        ARCHITECTURE="arm64"
    else
        ARCHITECTURE="amd64"
    fi

    # Install dependencies
    apt install -y bridge-utils dmidecode iptables iproute2 libc6 libffi7 libgcc-s1 liblz4-1 liblzo2-2 libmariadb3 libpcap0.8 libssl3 libstdc++6 libsasl2-2 libsqlite3-0 net-tools python3-pkg-resources python3-migrate python3-sqlalchemy python3-mysqldb python3-ldap3 sqlite3 zlib1g python3-netaddr python3-arrow python3-lxml python3-constantly python3-hyperlink python3-automat python3-service-identity python3-cffi python3-defusedxml

    # Download and install OpenVPN AS
    wget https://gitlab.com/jtfu/JOWALL/-/raw/main/OVPN12.12.1/openvpn-as_2.12.1-bc070def-Ubuntu22_"$ARCHITECTURE".deb
    wget https://gitlab.com/jtfu/JOWALL/-/raw/main/OVPN12.12.1/openvpn-as-bundled-clients-latest.deb
    dpkg -i openvpn-as-bundled-clients-latest.deb openvpn-as_2.12.1-bc070def-Ubuntu22_"$ARCHITECTURE".deb

    # Download and install pyovpn
    wget https://gitlab.com/jtfu/JOWALL/-/raw/main/OVPN12.12.1/pyovpn-2.0-py3.10.egg
    cp pyovpn-2.0-py3.10.egg /usr/local/openvpn_as/lib/python/

    # Restart OpenVPN AS
    systemctl restart openvpnas

    echo "OpenVPN Access Server has been installed."
}

# Function to remove OpenVPN AS
remove_openvpn_as() {
    echo "Removing OpenVPN Access Server..."

    # Stop OpenVPN AS service
    sudo systemctl stop openvpnas.service

    # Remove OpenVPN AS
    sudo apt-get remove openvpn-as

    # Remove OpenVPN AS directory and user
    sudo rm -rf /usr/local/openvpn_as/
    sudo userdel openvpn
    sudo groupdel openvpn

    # Remove log and temporary directories
    sudo rm -rf /var/log/openvpnas/
    sudo rm -rf /tmp/openvpnas/

    echo "OpenVPN Access Server has been removed."
}

# Function to backup OpenVPN AS
backup_openvpn_as() {
    echo "Backing up OpenVPN Access Server..."

    # Install SQLite if not installed
    which apt > /dev/null 2>&1 && apt -y install sqlite3
    which yum > /dev/null 2>&1 && yum -y install sqlite

    # Backup OpenVPN AS databases and configuration
    cd /usr/local/openvpn_as/etc/db
    [ -e config.db ] && sqlite3 config.db .dump > ../../config.db.bak
    [ -e certs.db ] && sqlite3 certs.db .dump > ../../certs.db.bak
    [ -e userprop.db ] && sqlite3 userprop.db .dump > ../../userprop.db.bak
    [ -e log.db ] && sqlite3 log.db .dump > ../../log.db.bak
    [ -e config_local.db ] && sqlite3 config_local.db .dump > ../../config_local.db.bak
    [ -e cluster.db ] && sqlite3 cluster.db .dump > ../../cluster.db.bak
    [ -e clusterdb.db ] && sqlite3 clusterdb.db .dump > ../../clusterdb.db.bak
    [ -e notification.db ] && sqlite3 notification.db .dump > ../../notification.db.bak

    # Backup configuration file
    cp ../as.conf ../../as.conf.bak

    # Create a backup directory
    mkdir -p /home/ubuntu/dbbackup && cp /usr/local/openvpn_as/*.bak /home/ubuntu/db/

    echo "OpenVPN Access Server has been backed up."
}

# Function to restore OpenVPN AS backup
restore_openvpn_as_backup() {
    echo "Restoring OpenVPN Access Server backup..."

    # Copy backup files to OpenVPN AS directory
    cp /home/ubuntu/dbbackup/*.bak /usr/local/openvpn_as/

    # Stop OpenVPN AS service
    service openvpnas stop

    # Install SQLite if not installed
    which apt > /dev/null 2>&1 && apt -y install sqlite3
    which yum > /dev/null 2>&1 && yum -y install sqlite

    # Restore OpenVPN AS databases and configuration
    cd /usr/local/openvpn_as/etc/db
    [ -e ../../config.db.bak ] && rm config.db; sqlite3 <../../config.db.bak config.db
    [ -e ../../certs.db.bak ] && rm certs.db; sqlite3 <../../certs.db.bak certs.db
    [ -e ../../userprop.db.bak ] && rm userprop.db; sqlite3 <../../userprop.db.bak userprop.db
    [ -e ../../log.db.bak ] && rm log.db; sqlite3 <../../log.db.bak log.db
    [ -e ../../config_local.db.bak ] && rm config_local.db; sqlite3 <../../config_local.db.bak config_local.db
    [ -e ../../cluster.db.bak ] && rm cluster.db; sqlite3 <../../cluster.db.bak cluster.db
    [ -e ../../clusterdb.db.bak ] && rm clusterdb.db; sqlite3 <../../clusterdb.db.bak clusterdb.db
    [ -e ../../notification.db.bak ] && rm notification.db; sqlite3 <../../notification.db.bak notification.db

    # Restore configuration file
    [ -e ../../as.conf.bak ] && cp ../../as.conf.bak ../as.conf

    # Start OpenVPN AS service
    service openvpnas start

    echo "OpenVPN Access Server has been restored from backup."
}


# Function to generate configuration
generate() {
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
    cd /home/ubuntu/warpgen/
    ./wgcf status
}

# Function to trace
trace() {
    cd /home/ubuntu/warpgen/
    ./wgcf trace
}

# Function to change license key
#change_key() {
    #read -p "Enter the new WGCF license key: " new_key
    #WGCF_LICENSE_KEY="$new_key" ./wgcf update
#}

# Main menu
main_menu() {
    while true; do
        clear
        echo "Select an option:"
        echo "1: Docker"
        echo "2: Marzban"
        echo "3: SSL Cert Management"
        echo "4: Update Repositories"
        echo "5: Minecraft PE Server"
        echo "6: Fail2Ban for SSHD"
        echo "7: Fail2Ban status"
        echo "8: Config UFW"
        echo "9: OpenVPN AS"
        echo "10: wgcf"
        echo "0: Quit"
        echo "00: Update"

        read -p "Enter your choice: " choice

        case $choice in
            1) docker_submenu ;;
            2) marzban_submenu ;;
            3) ssl_cert_management ;;
            4) update_repositories ;;
            5) minecraft_pe_server_submenu ;;
            6) fail2bansshd ;;
            7) fail2banstatus ;;
            8) configure_ufw_security ;;
            9) openvpn_as_submenu ;;
            10) wgcf ;;
            0) quit_script ;;
            00) update_script ;;
            *) echo "Invalid option. Please choose a valid option." ;;
        esac

        read -p "Press any key to return to the menu or 'q' to quit." -n 1 -s input
        if [ "$input" == "q" ]; then
            echo "Exiting..."
            exit 0
        fi
    done
}


# Sub Menu
# SUb menu for SSL certificate management (Menu)
ssl_cert_management() {
  local choice

  # Consume any remaining input in the buffer
  read -r -t 0.1 -n 10000

  # Main menu
  echo "SSL Certificate Management Menu"
  echo "1: Register SSL for marzban (using /var/lib/marzban/certs)"
  echo "2: Register SSL for x-ui (using /root/certs)"
  echo "3: Show SSL Certificate Summary"
  read -p "Select an option (1-3): " choice

  case $choice in
    1)
      read -p "Enter the domain for Marzban SSL registration: " domain
      mkdir -p /var/lib/marzban/certs
      register_ssl "$domain" "/var/lib/marzban/certs"
      ;;
    2)
      read -p "Enter the domain for x-ui SSL registration: " domain
      mkdir -p /root/certs
      register_ssl "$domain" "/root/certs"
      ;;
    3)
      echo "SSL Certificates Summary:"
      echo "Marzban: $(ls /var/lib/marzban/certs/ | grep -c '.cert.crt') certificates registered"
      echo "x-ui: $(ls /root/certs/ | grep -c '.cert.crt') certificates registered"
      ;;
    *)
      echo "Invalid choice. Please select a valid option."
      ;;
  esac
}

# Sub-menu for Docker options
docker_submenu() {
    while true; do
        clear
        echo "Docker Sub-Options:"
        echo "1: Install Docker"
        echo "2: Uninstall Docker"
        echo "3: Install Caddy"
        echo "4: Install Alist"
        echo "0: Back to main menu"

        docker ps -a

        read -p "Enter your choice: " docker_choice

        case "$docker_choice" in
            1) install_docker ;;
            2) uninstall_docker ;;
            3) install_caddy ;;
            4) install_alist ;;
            0) break ;;
            *)
                echo "Invalid option. Please choose a valid option."
                ;;
        esac
    done
}

# Sub-menu for wgcf
wgcf() {
    while true; do
        echo "Choose an option:"
        echo "1. Generate configuration"
        echo "2. Check status"
        echo "3. Trace"
        echo "0. Back to main menu"

        read -p "Enter your choice: " choice

        case $choice in
            1)
                generate
                ;;
            2)
                check_status
                ;;
            3)
                trace
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

# Sub-menu configure UFW (Uncomplicated Firewall) security
configure_ufw_security() {
    echo "Configuring UFW (Uncomplicated Firewall) security..."

    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        read -p "UFW is not available! Do you want to install? (y/n) " ufw_choice
        if [ "$ufw_choice" == "y" ]; then
            install_ufw
        else
            echo "UFW is not installed. Please install UFW first."
            return
        fi
    fi

    while true; do
        echo "UFW Security Sub-Options:"
        echo "1: Allow port for Marzban"
        echo "2: Allow port for Wordpress"
        echo "3: Allow port for OpenVPN"
        echo "0: Back to main menu"
        echo "00: Reset UFW"

        read -p "Enter your choice: " sub_choice

        case $sub_choice in
            1) allow_port_for_marzban ;;
            2) allow_port_for_wordpress ;;
            3) allow_port_for_openvpn ;;
            0) break ;;
            00) reset_ufw ;;
            *) echo "Invalid sub-option. Please choose a valid sub-option." ;;
        esac
    done
}

# Sub-menu for Marzban options
marzban_submenu() {
    while true; do
        clear  
        echo "Marzban Sub-Options:"
        echo "1: Install Marzban Panel"
        echo "2: Install Marzban Node"
        echo "3: Display SSL certificate (Node)"
        echo "4: Uninstall Marzban"
        echo "5: Turn on Haproxy"
        echo "0: Back to main menu"

        read -p "Enter your choice: " sub_choice

        case $sub_choice in
            1) install_marzban_panel ;;
            2) install_marzban_node ;;
            3) display_ssl_certificate ;;
            4) uninstall_marzban_submenu ;;
            5) turn_on_haproxy_marzban ;;
            0) break ;;
            *) echo "Invalid sub-option. Please choose a valid sub-option." ;;
        esac

        read -p "Press any key to return to the menu or 'q' to quit." -n 1 -s input
        if [ "$input" == "q" ]; then
            echo "Exiting..."
            exit 0
        fi
    done
}

# Sub-menu for Marzban uninstall options
uninstall_marzban_submenu() {
    while true; do
        clear  
        echo "Uninstall Marzban Sub-Options:"
        echo "1: Uninstall Marzban Panel"
        echo "2: Uninstall Marzban Node"
        echo "3: Uninstall all Marzban components"
        echo "0: Back to Marzban menu"
        echo "00: Back to main menu"

        read -p "Enter your choice: " uninstall_choice

        case $uninstall_choice in
            1) uninstall_marzban_panel ;;
            2) uninstall_marzban_node ;;
            3) uninstall_all_marzban ;;
            0) break ;;
            00) break 2 ;;
            *) echo "Invalid sub-option. Please choose a valid sub-option." ;;
        esac

        read -p "Press any key to return to the menu or 'q' to quit." -n 1 -s input
        if [ "$input" == "q" ]; then
            echo "Exiting..."
            exit 0
        fi
    done
}

# Sub-menu for Minecraft PE Server
minecraft_pe_server_submenu() {
    while true; do
        clear  
        echo "Minecraft PE Server Sub-Options:"
        echo "1: Install Minecraft Server"
        echo "2: Edit Port and Difficulty"
        echo "3: Enable Coordinates"
        echo "4: Remove Minecraft Server"
        echo "0: Back to main menu"

        read -p "Enter your choice: " sub_choice

        case $sub_choice in
            1) install_minecraft_pe_server ;;
            2) edit_minecraft_pe_server ;;
            3) enable_coordinates ;;
            4) remove_minecraft_pe_server ;;
            0) break ;;
            *) echo "Invalid sub-option. Please choose a valid sub-option." ;;
        esac
        read -p "Press any key to return to the menu or 'q' to quit." -n 1 -s input
        if [ "$input" == "q" ]; then
            echo "Exiting..."
            exit 0
        fi
    done
}

# Function to manage OpenVPN AS
openvpn_as_submenu() {
    while true; do
        clear
        echo "OpenVPN AS Menu:"
        echo "1: Install OpenVPN AS"
        echo "2: Uninstall OpenVPN AS"
        echo "3: Backup OpenVPN AS"
        echo "4: Restore OpenVPN AS"
        echo "0: Back"

        read -p "Enter your choice: " choice

        case $choice in
            1) install_openvpn_as ;;
            2) remove_openvpn_as ;;
            3) backup_openvpn_as ;;
            4) restore_openvpn_as_backup ;;
            0) break ;;
            *) echo "Invalid option. Please choose a valid option." ;;
        esac

        read -p "Press any key to return to the OpenVPN AS menu or 'q' to go back to the main menu." -n 1 -s input
        if [ "$input" == "q" ]; then
            break
        fi
    done
}


# Function to quit the script
quit_script() {
    echo "Exiting..."
    exit 0
}


# Start the main menu
echo "v1.0.1"
main_menu
