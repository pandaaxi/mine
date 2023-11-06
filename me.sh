#!/bin/bash

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    if ! command -v docker &> /dev/null; then
        # Update and upgrade the system
        apt update && apt upgrade -y and apt autoclean -y

        # Install Docker using the official script
        curl -fsSL https://get.docker.com | sh

        # Add the current user to the docker group (to run Docker without sudo)
        usermod -aG docker $USER

        # Start the Docker service
        systemctl start docker

        # Enable Docker to start on boot
        systemctl enable docker
    else
        echo "Docker is already installed."
    fi
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
    if curl -fsSL -o updated_me.sh "$updated_script_url"; then
        mv -f updated_me.sh me.sh
        chmod +x me.sh
        echo "Script updated successfully."
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

    # Create a directory for the Minecraft PE server
    minecraft_dir="/root/minecraft"
    mkdir -p $minecraft_dir

    # Ask for a custom container name or use default
    read -p "Enter a container name (default: mc01): " container_name
    container_name=${container_name:-"mc01"}

    # Ask for server port
    read -p "Enter server port (default: 20001): " server_port
    server_port=${server_port:-"20001"}

    # Ask for difficulty level
    read -p "Enter difficulty level (easy/normal/hard): " difficulty
    difficulty=${difficulty:-"normal"}

    # Ask for level seed (leave blank for default)
    read -p "Enter level seed (leave blank for default): " level_seed

    # Create a Docker Compose file
    cat <<EOF > $minecraft_dir/docker-compose.yml
version: '3'
services:
  minecraft-bedrock-server:
    image: itzg/minecraft-bedrock-server
    container_name: $container_name
    environment:
      - EULA=TRUE
      - SERVER_PORT=$server_port
      - DIFFICULTY=$difficulty
EOF

    if [ -n "$level_seed" ]; then
        echo "      - LEVEL_SEED=$level_seed" >> $minecraft_dir/docker-compose.yml
    fi

    # Append the rest of the Docker Compose file
    cat <<EOF >> $minecraft_dir/docker-compose.yml
    ports:
      - "$server_port:$server_port/udp"
    volumes:
      - $container_name:/data

volumes:
  $container_name:
EOF

    # Start the Minecraft PE server
    cd $minecraft_dir
    docker-compose up -d

    echo "Minecraft PE Server has been installed and started."
    echo "Server Port: $server_port"
    echo "Difficulty: $difficulty"
    echo "Container Name: $container_name"
}


# Main menu
main_menu() {
    while true; do
        echo "Select an option:"
        echo "1: Install Docker"
        echo "2: Marzban"
        echo "3: SSL Cert Management"
        echo "4: Update Repositories"
        echo "5: Minecraft PE Server"
        echo "0: Quit"
        echo "00: Upd"

        read -p "Enter your choice: " choice

        case $choice in
            1) install_docker ;;
            2) marzban_submenu ;;
            3) ssl_cert_management ;;
            4) update_repositories ;;
            5) minecraft_pe_server_submenu ;;
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

# Sub-menu for Marzban options
marzban_submenu() {
    while true; do
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
        echo "Minecraft PE Server Sub-Options:"
        echo "1: Install Minecraft PE Server"
        echo "0: Back to main menu"

        read -p "Enter your choice: " minecraft_pe_choice

        case $minecraft_pe_choice in
            1) install_minecraft_pe_server ;;
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
