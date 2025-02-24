# Storj Node Migration Script

## Overview

This script assists in migrating your Storj node's data, configuration, and (optionally) log files
from one location to another. It supports both local transfers and remote migrations via SSH.

The script employs a **two-pass rsync process**:
1. **First Pass:**  
   - Syncs files without using the `--delete` flag.
   - Can run while the Storj node is online to copy the bulk of the data.
2. **Second Pass:**  
   - Checks if the Storj node process is running.
   - If running, performs a final sync using the `--delete` flag to ensure the destination 
     exactly mirrors the source.

Additional features include:

- **Auto-Detection of Config File:**  
  The script searches the data directory for a configuration file (e.g., `config.yaml`).
  If found, you may accept it or provide an alternative path; if not found, you will be prompted
  to specify its location.

- **Docker Container Shutdown Option (Optional):**  
  Before the second sync pass, the script lists running Docker containers and allows you
  to select which containers should be shut down. This helps prevent container-based file changes
  from interfering with the final sync.

- **Root Privilege Requirement:**  
  Most commands in this script require root privileges. The script checks if it is run as root
  and exits if not.

- **Progress Reporting:**  
  Uses `rsync` with `--info=progress2` to display real-time progress, transfer speed, and ETA.

- **Error Handling:**  
  Checks for errors at each step, ensuring data integrity throughout the migration.

## Prerequisites

- **Bash Shell:**  
  Designed for Unix-like environments.

- **Required Tools:**  
  - `rsync`
  - `ssh`
  - `scp`
  - `pgrep`
  - `find`
  - `docker` (for the Docker container shutdown step)

- **Permissions:**  
  This script must be run as root. Use `sudo` or run as the root user.

## Usage

1. **Run the Script as Root:**  
   Ensure you run the script with root privileges:
   ```bash
   sudo ./migrate_node.sh




# Storj Node Setup Script

## Overview

This script automates the setup of multiple Storj nodes by:
- Running all system commands with sudo.
- Prompting for key parameters such as the number of nodes, email, wallet address, node names,
  server name, country code, starting ports, and storage capacity.
- Running system updates and installing Docker along with additional required packages.
- Creating node directories under the non-root user's home directory (e.g., /home/USER/node1, node2, …)
  and data directories under /data (e.g., /data/disk1, disk2, …).
- Generating a file called `nodes.conf` that contains, for each node, two docker run commands:
  - A command to run the container in setup mode.
  - A command to run the container detached with auto-incremented ports and proper environment variables.

## Prerequisites

- The script must be run with sudo (or as root).
- The non-root user's home directory (from which the script is run via sudo) will be used for node directories.
- Ubuntu/Debian-based system with access to apt.
- Required tools: apt, docker, curl, etc.

## Usage

1. **Run the Script as Root:**
   ```bash
   sudo ./setup_storj_nodes.sh
