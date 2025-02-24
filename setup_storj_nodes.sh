#!/bin/bash
# setup_storj_nodes.sh
#
# This script sets up multiple Storj node directories and generates a nodes.conf file
# containing docker run commands for each node. Every command is run via sudo.
#
# It performs the following:
#   1. Prompts for:
#       - Number of storj nodes to create.
#       - Email address.
#       - Wallet address.
#       - First node name.
#       - Server name.
#       - Country code (to build the node address, e.g. "uk" for United Kingdom).
#       - Starting node port.
#       - Starting dashboard port.
#       - Storage capacity (in TB) for each node.
#   2. Runs a full apt update/upgrade and installs Docker (plus related packages).
#   3. Creates directories under the non-root user's home (/home/USER/node1 ... nodeN)
#      and directories under /data (/data/disk1 ... diskN).
#   4. Generates a file (nodes.conf) with two docker run commands per node:
#         a. A command to run the container in "setup" mode.
#         b. A command to run the container detached (with auto‑incremented ports, etc.).
#
# IMPORTANT: All commands use sudo. This script must be run as root (or via sudo).
#
# Example usage:
#   sudo ./setup_storj_nodes.sh

# Ensure the script is run with sudo and determine the original non-root user.
if [ -z "$SUDO_USER" ]; then
  echo "This script must be run with sudo."
  exit 1
fi
USER_HOME="/home/$SUDO_USER"

# Prompt for input parameters.
read -p "How many storj nodes do you want to create? " num_nodes
read -p "Enter your email: " email
read -p "Enter your wallet address: " wallet
read -p "Enter the first node name: " first_node_name
read -p "Enter the server name: " server_name
read -p "Enter the country code (e.g., uk for United Kingdom): " country_code
read -p "Enter the starting node port: " start_node_port
read -p "Enter the starting dashboard port: " start_dashboard_port
read -p "Enter the storage capacity (in TB) for each node: " storage_capacity

echo ""
echo "Running apt update and apt upgrade..."
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

# Create node directories in the non-root user's home.
echo ""
echo "Creating node directories under ${USER_HOME}..."
for (( i=1; i<=num_nodes; i++ )); do
  sudo mkdir -p "$USER_HOME/node$i"
done

# Create /data and disk directories.
echo "Creating /data and disk directories..."
sudo mkdir -p /data
for (( i=1; i<=num_nodes; i++ )); do
  sudo mkdir -p "/data/disk$i"
done

# Output the configuration for each node.
echo ""
echo "Configuration for Storj nodes:"
for (( i=1; i<=num_nodes; i++ )); do
  # Format node and server index values.
  node_index=$(printf "%03d" "$i")
  srv_index=$(printf "%02d" "$i")
  node_address="node${node_index}.srv${srv_index}.${country_code}.storjnode"
  node_port=$(( start_node_port + i - 1 ))
  dashboard_port=$(( start_dashboard_port + i - 1 ))
  
  echo "----------------------------------------"
  if [ "$i" -eq 1 ]; then
    echo "Node $i:"
    echo "  Node Name: ${first_node_name}"
  else
    echo "Node $i:"
    echo "  Node Name: ${first_node_name}_$i"
  fi
  echo "  Node Address: $node_address"
  echo "  Email: $email"
  echo "  Wallet: $wallet"
  echo "  Node Port: $node_port"
  echo "  Dashboard Port: $dashboard_port"
  echo "  Node Directory: ${USER_HOME}/node$i"
  echo "  Data Disk Directory: /data/disk$i"
done

# Generate nodes.conf with docker run commands for each node.
nodes_conf_file="nodes.conf"
sudo rm -f "$nodes_conf_file"
echo ""
echo "Generating ${nodes_conf_file} with docker commands for each node..."
for (( i=1; i<=num_nodes; i++ )); do
    node_index=$(printf "%03d" "$i")
    srv_index=$(printf "%02d" "$i")
    node_address="node${node_index}.srv${srv_index}.${country_code}.storjnode"
    node_port=$(( start_node_port + i - 1 ))
    dashboard_port=$(( start_dashboard_port + i - 1 ))
    container_name=$(printf "storagenode0%02d" "$i")
    
    # First docker run command (setup).
    echo "sudo docker run --rm -e SETUP=\"true\" --mount type=bind,source=\"/home/${SUDO_USER}/node${i}/storagenode\",destination=/app/identity --mount type=bind,source=\"/home/${SUDO_USER}/node${i}/storj\",destination=/app/config --name ${container_name} storjlabs/storagenode:latest" | sudo tee -a "$nodes_conf_file" > /dev/null

    # Second docker run command (detached).
    echo "sudo docker run -d --restart unless-stopped --stop-timeout 300 -p ${node_port}:28967/tcp -p ${node_port}:28967/udp -p 127.0.0.1:${dashboard_port}:14002 -e WALLET=\"${wallet}\" -e EMAIL=\"${email}\" -e ADDRESS=\"${node_address}:${node_port}\" -e STORAGE=\"${storage_capacity}\" --mount type=bind,source=\"/home/${SUDO_USER}/node${i}/storagenode\",destination=/app/identity --mount type=bind,source=\"/data/disk${i}\",destination=/app/config --name ${container_name} --log-opt max-size=1g --log-opt max-file=5 storjlabs/storagenode:latest" | sudo tee -a "$nodes_conf_file" > /dev/null
done

echo ""
echo "nodes.conf file generated."
echo "Setup complete."
