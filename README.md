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
     exactly mirrors the source (removing any files that have been deleted in the source).

## Features

- **Interactive Prompts:**  
  Gather source and destination paths along with remote server details.
  
- **Local & Remote Support:**  
  Transfer files locally or to a remote server using SSH-based commands.

- **Two-Pass Sync Process:**  
  - **First Pass:** Initial sync without deletion, to cover the bulk data transfer.
  - **Second Pass:** Final sync (triggered if the Storj node is running) with the `--delete` flag for an exact mirror.
  
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

- **Permissions:**  
  Ensure you have the necessary permissions to read from the source directories and write to the destination.

## Usage

1. **Run the Script:**  
   Execute the script and follow the interactive prompts:
   ```bash
   ./migrate_node.sh
