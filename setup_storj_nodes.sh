#!/bin/bash
# setup_storj_nodes.sh
#
# This script automates the creation of multiple Storj nodes.
# All commands are run via sudo.
#
# It prompts for:
#   - Number of nodes.
#   - Email address.
#   - Wallet address.
#   - First node name (e.g., "node041"). The numeric part will be incremented for subsequent nodes.
#   - Server code (e.g., "012") which remains the same for every node.
#   - Country code (e.g., "uk").
#   - Starting node port.
#   - Starting dashboard port.
#   - Storage capacity (e.g., "1TB").
#
# The script then:
#   1. Runs apt update/upgrade and installs Docker (and related packages).
#   2. Creates directories in the non-root user's home (/home/USER/<node_name>) and /data/disk1...diskN.
#   3. Generates a file named nodes.conf that contains two groups of docker run commands:
#      - First, all the "setup" commands (one per line).
#      - Then all the "run" commands (one per line).
#
# IMPORTANT: Run this script with sudo.
#
# Example usage:
#   sudo ./setup_storj_nodes.sh

# Ensure the script is run with sudo and get the original user.
if [ -z "$SUDO_USER" ]; then
  echo "This script must be run with sudo."
  exit 1
fi
USER_HOME="/home/$SUDO_USER"

# Prompt for input parameters.
read -p "How many storj nodes do you want to create? " num_nodes
read -p "Enter your email: " email
read -p "Enter your wallet address: " wallet
read -p "Enter the first node name (e.g., node041): " first_node_name
read -p "Enter the server code (e.g., 012): " srv_code
read -p "Enter the country code (e.g., uk): " country_code
read -p "Enter the starting node port: " start_node_port
read -p "Enter the starting dashboard port: " start_dashboard_port
read -p "Enter the storage capacity for each node (e.g., 1TB): " storage_capacity

echo ""
echo "Running apt update and upgrade..."
sudo apt update && sudo apt upgrade -y

# Docker installation steps:
echo ""
echo "Installing Docker and required packages..."
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin nginx php-fpm unzip -y

# Extract non-numeric prefix and numeric part from first_node_name.
prefix="${first_node_name%%[0-9]*}"
number_part="${first_node_name#$prefix}"
width=${#number_part}
start_number=$(printf "%d" "$number_part")

# Create node directories under the user's home.
echo ""
echo "Creating node directories under ${USER_HOME}..."
for (( i=0; i<num_nodes; i++ )); do
    new_number=$(( start_number + i ))
    formatted_number=$(printf "%0${width}d" "$new_number")
    node_name="${prefix}${formatted_number}"
    sudo mkdir -p "$USER_HOME/${node_name}"
done

# Create /data and disk directories.
echo "Creating /data and disk directories..."
sudo mkdir -p /data
for (( i=1; i<=num_nodes; i++ )); do
    sudo mkdir -p "/data/disk$i"
done

# Display configuration for each node.
echo ""
echo "Configuration for Storj nodes:"
for (( i=0; i<num_nodes; i++ )); do
    new_number=$(( start_number + i ))
    formatted_number=$(printf "%0${width}d" "$new_number")
    node_name="${prefix}${formatted_number}"
    node_address="${node_name}.${srv_code}.${country_code}.storj.cloud"
    node_port=$(( start_node_port + i ))
    dashboard_port=$(( start_dashboard_port + i ))
    echo "----------------------------------------"
    echo "Node: ${node_name}"
    echo "  Address: ${node_address}"
    echo "  Email: ${email}"
    echo "  Wallet: ${wallet}"
    echo "  Node Port: ${node_port}"
    echo "  Dashboard Port: ${dashboard_port}"
    echo "  Node Directory: ${USER_HOME}/${node_name}"
    echo "  Data Disk Directory: /data/disk$((i+1))"
done

# Generate nodes.conf with grouped docker commands.
nodes_conf_file="nodes.conf"
sudo rm -f "$nodes_conf_file"

# Write the setup commands first.
for (( i=0; i<num_nodes; i++ )); do
    new_number=$(( start_number + i ))
    formatted_number=$(printf "%0${width}d" "$new_number")
    node_name="${prefix}${formatted_number}"
    node_address="${node_name}.${srv_code}.${country_code}.storj.cloud"
    node_port=$(( start_node_port + i ))
    dashboard_port=$(( start_dashboard_port + i ))
    container_name="storagenode${formatted_number}"
    echo "sudo docker run --rm -e SETUP=\"true\" --mount type=bind,source=\"/home/${SUDO_USER}/${node_name}/storagenode\",destination=/app/identity --mount type=bind,source=\"/home/${SUDO_USER}/${node_name}/storj\",destination=/app/config --name ${container_name} storjlabs/storagenode:latest" | sudo tee -a "$nodes_conf_file" > /dev/null
done

# Then write the run commands.
for (( i=0; i<num_nodes; i++ )); do
    new_number=$(( start_number + i ))
    formatted_number=$(printf "%0${width}d" "$new_number")
    node_name="${prefix}${formatted_number}"
    node_address="${node_name}.${srv_code}.${country_code}.storj.cloud"
    node_port=$(( start_node_port + i ))
    dashboard_port=$(( start_dashboard_port + i ))
    container_name="storagenode${formatted_number}"
    echo "sudo docker run -d --restart unless-stopped --stop-timeout 300 -p ${node_port}:28967/tcp -p ${node_port}:28967/udp -p 127.0.0.1:${dashboard_port}:14002 -e WALLET=\"${wallet}\" -e EMAIL=\"${email}\" -e ADDRESS=\"${node_address}:${node_port}\" -e STORAGE=\"${storage_capacity}\" --mount type=bind,source=\"/home/${SUDO_USER}/${node_name}/storagenode\",destination=/app/identity --mount type=bind,source=\"/data/disk$((i+1))\",destination=/app/config --name ${container_name} --log-opt max-size=1g --log-opt max-file=5 storjlabs/storagenode:latest" | sudo tee -a "$nodes_conf_file" > /dev/null
done

echo ""
echo "nodes.conf file generated. Each docker command is on its own line."
echo "Setup complete."
