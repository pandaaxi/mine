#!/bin/bash

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    if ! command -v docker &> /dev/null; then
        # Update and upgrade the system
        apt update && apt upgrade -y && apt autoclean -y

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
    apt update && apt upgrade -y && sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
}

# Main loop
while true; do
    echo "Select an option:"
    echo "1: Install Docker"
    echo "2: Marzban"
    echo "0: Quit"
    
    read -p "Enter your choice: " choice

    case $choice in
        1) install_docker ;;
        2)
            while true; do
                echo "Marzban Sub-Options:"
                echo "1: Install Marzban Panel"
                echo "2: Install Marzban Node"
                echo "3: Display SSL certificate (Node)"
                echo "0: Back to main menu"
                
                read -p "Enter your choice: " sub_choice
                
                case $sub_choice in
                    1) install_marzban_panel ;;
                    2) install_marzban_node ;;
                    3) display_ssl_certificate ;;
                    0) break ;; # Return to the main menu
                    *) echo "Invalid sub-option. Please choose a valid sub-option (1, 2, 3, or 0)." ;;
                esac
            done
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a valid option (1, 2, or 0)."
            ;;
    esac
done
