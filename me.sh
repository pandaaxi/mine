#!/bin/bash

# Function script
# Function to install Docker
install_docker() {
    clear
    echo "Installing Docker..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker is already installed."
    fi
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
        # Update package list
        apt-get update

        # Clone the Marzban-Node repository
        cd ~
        git clone https://github.com/Gozargah/Marzban-node
        cd Marzban-node

        # Start the Docker Compose service
        docker compose up -d

        #SSL
        cat /var/lib/marzban-node/ssl_cert.pem
    fi
}

# Function to display SSL certificate (Node)
display_ssl_certificate() {
    echo "Displaying SSL certificate (Node)..."
    cat /var/lib/marzban-node/ssl_cert.pem
}

# Function to install Marzban Panel
install_marzban_panel() {
    echo "Installing Marzban Panel..."
    apt update && apt upgrade -y and sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
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


# Function for SSL Cert Management
ssl_cert_management() {
    echo "Running SSL Cert Management script..."
    bash <(curl -L -s https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
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
    mkdir -p "/root/minecraft/$server_name"

    # Create a Docker Compose configuration for the Minecraft server
    cat <<EOF > "/root/minecraft/$server_name/docker-compose.yml"
version: '3'
services:
  minecraft-bedrock-server:
    image: itzg/minecraft-bedrock-server
    container_name: $server_name
    environment:
      - EULA=TRUE
      - SERVER_PORT=$server_port
      - DIFFICULTY=$difficulty
EOF

    # Add the level seed if provided
    if [ -n "$level_seed" ]; then
        echo "      - LEVEL_SEED=$level_seed" >> "/root/minecraft/$server_name/docker-compose.yml"
    fi

    # Add the rest of the configuration
    cat <<EOF >> "/root/minecraft/$server_name/docker-compose.yml"
    ports:
      - "$server_port:$server_port/udp"
    volumes:
      - $server_name:/data

volumes:
  $server_name:
EOF

    # Start the Minecraft server
    cd "/root/minecraft/$server_name"
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
            cd "/root/minecraft/$server"
            docker-compose down

            # Remove the Docker Compose configuration
            rm -f "/root/minecraft/$server/docker-compose.yml"

            # Remove the server folder
            rm -rf "/root/minecraft/$server"
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
        cd "/root/minecraft/$server_name"
        docker-compose down

        # Remove the Docker Compose configuration
        rm -f "/root/minecraft/$server_name/docker-compose.yml"

        # Remove the server folder
        rm -rf "/root/minecraft/$server_name"

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
    server_directory="/root/minecraft/$server_name"

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

    # Create a new configuration file for SSH (sshd)
    cat <<EOF > /etc/fail2ban/jail.d/sshd.local
    [sshd]
    enabled = true
    mode   = normal
    backend = systemd
EOF

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

# Function to setup WordPress with Docker
setup_wordpress_with_docker() {
    # Ask for the domain name
    read -p "Enter your domain name: " DOMAIN

    # Update and install required packages
    apt update -y
    apt install wget curl nano software-properties-common dirmngr apt-transport-https gnupg gnupg2 ca-certificates lsb-release ubuntu-keyring unzip -y

    # Check if Docker is installed and install if not
    install_docker

    # Allow UFW for WordPress
    allow_port_for_wordpress

    # Create the Docker directory
    mkdir -p /opt/wordpress
    cd /opt/wordpress

    mkdir config
    mkdir -p nginx/vhost

    # Create the Docker Compose file with the provided domain
    cat <<EOF > "/opt/wordpress/docker-compose.yml"
version: '3.9'

services:
  wp:
    image: wordpress:latest
    container_name: wordpress-app
    restart: unless-stopped
    expose:
      - 8080
    volumes:
      - ./config/php.conf.ini:/usr/local/etc/php/conf.d/conf.ini
      - ./wp-app:/var/www/html
      #- ./plugin-name/trunk/:/var/www/html/wp-content/plugins/plugin-name # Plugin development
      #- ./theme-name/trunk/:/var/www/html/wp-content/themes/theme-name # Theme development
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: "${DB_NAME}"
      WORDPRESS_DB_USER: "${DB_USER_NAME}"
      WORDPRESS_DB_PASSWORD: "${DB_USER_PASSWORD}"
      VIRTUAL_HOST: "${DOMAIN}",www."${DOMAIN}"
      LETSENCRYPT_HOST: "${DOMAIN}",www."${DOMAIN}"
    depends_on:
      - db
    links:
      - db

  db:
    image: mysql:latest
    container_name: wordpressdb
    restart: unless-stopped
    command: [
        '--default_authentication_plugin=mysql_native_password',
        '--character-set-server=utf8mb4',
        '--collation-server=utf8mb4_unicode_ci'
    ]
    volumes:
      - ./wp-data:/docker-entrypoint-initdb.d
      - db_data:/var/lib/mysql
    environment:
      MYSQL_DATABASE: "${DB_NAME}"
      MYSQL_ROOT_PASSWORD: "${DB_ROOT_PASSWORD}"
      MYSQL_USER: "${DB_USER_NAME}"
      MYSQL_PASSWORD: "${DB_USER_PASSWORD}"
	
  nginx:
    container_name: nginx
    image: nginxproxy/nginx-proxy
    restart: unless-stopped
    ports:
        - 80:80
        - 443:443
    volumes:
        - /var/run/docker.sock:/tmp/docker.sock:ro
        - ./nginx/html:/usr/share/nginx/html
        - ./nginx/certs:/etc/nginx/certs
        - ./nginx/vhost:/etc/nginx/vhost.d
    logging:
        options:
            max-size: "10m"
            max-file: "3"
		
  acme-companion:
    container_name: acme-companion
    image: nginxproxy/acme-companion
    restart: unless-stopped
    volumes_from:
        - nginx
    volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        - ./nginx/acme:/etc/acme.sh
    environment:
        DEFAULT_EMAIL: certbot@"${DOMAIN}"
		
volumes:
  db_data:
EOF

    # Create the .env file with the provided domain and generate passwords
    DB_USER_PASSWORD=$(uuidgen)
    DB_ROOT_PASSWORD=$(uuidgen)
    cat <<EOF > "/opt/wordpress/.env"
DOMAIN=\${DOMAIN}
DB_NAME=\${DOMAIN}
DB_USER_NAME=\${DOMAIN}
DB_USER_PASSWORD=\${DB_USER_PASSWORD}
DB_ROOT_PASSWORD=\${DB_ROOT_PASSWORD}
EOF


    # Start the WordPress setup with Docker Compose
    docker-compose up -d

    # Print the generated passwords
    echo "Visit wordpress website: https://\${DOMAIN}"
    echo "Generated DB_USER_PASSWORD: \${DB_USER_PASSWORD}"
    echo "Generated DB_ROOT_PASSWORD: \${DB_ROOT_PASSWORD}"
}



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
            7) fail2banstatus;;
            8) configure_ufw_security;;
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
# Sub-menu for Docker options
docker_submenu() {
    while true; do
        clear
        echo "Docker Sub-Options:"
        echo "1: Install Docker"
        echo "2: Uninstall Docker"
        echo "3: Install Wordpress"
        echo "0: Back to main menu"

        docker ps -a

        read -p "Enter your choice: " docker_choice

        case "$docker_choice" in
            1) install_docker ;;
            2) uninstall_docker ;;
            3) setup_wordpress_with_docker ;;
            0) break ;;
            *)
                echo "Invalid option. Please choose a valid option."
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
        echo "0: Back to main menu"

        read -p "Enter your choice: " sub_choice

        case $sub_choice in
            1) install_marzban_panel ;;
            2) install_marzban_node ;;
            3) display_ssl_certificate ;;
            4) uninstall_marzban_submenu ;;
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


# Function to quit the script
quit_script() {
    echo "Exiting..."
    exit 0
}

# Start the main menu
main_menu
