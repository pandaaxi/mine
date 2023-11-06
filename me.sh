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
    curl -fsSL https://raw.githubusercontent.com/vblyrpv074/mine/main/me.sh > me.sh
    echo "Script updated successfully."
}


# Main loop
while true; do
    echo "Select an option:"
    echo "1: Install Docker"
    echo "2: Marzban"
    echo "3: Update script"
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
                echo "4: Uninstall Marzban"
                echo "0: Back to main menu"
                
                read -p "Enter your choice: " sub_choice
                
                case $sub_choice in
                    1) install_marzban_panel ;;
                    2) install_marzban_node ;;
                    3) display_ssl_certificate ;;
                    4)
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
                        done
                        ;;
                    0) break ;;
                    *) echo "Invalid sub-option. Please choose a valid sub-option." ;;
                esac
            done
            ;;
        3) update_script ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a valid option." ;;
    esac
done
