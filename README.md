# Storj Node Migration Script

## Overview

This script assists in migrating your Storj node's data, configuration, and optionally log files from one location to another. It supports both local transfers and remote migrations using rsync over SSH and scp. The script provides real-time progress updates (including data transfer speeds and estimated time remaining) to help you monitor the migration process.

## Features

- **Interactive Prompts:**  
  Gather all required paths and remote server details interactively.

- **Local & Remote Support:**  
  Choose between local file transfers or remote migrations by providing SSH credentials and target paths.

- **Progress Reporting:**  
  Uses `rsync` with `--info=progress2` to display progress information such as the current speed and estimated time remaining.

- **Pre-Migration Checks:**  
  Ensures that the Storj node service is stopped before starting the migration to prevent file conflicts.

- **Error Handling:**  
  Halts the process if any step fails, ensuring that you can address issues before proceeding further.

## Prerequisites

- **Bash Shell:**  
  The script is written in Bash and should be run in a Unix-like environment.

- **Required Tools:**  
  - `rsync`  
  - `ssh`  
  - `scp`  

  Make sure these tools are installed and available in your system's PATH.

- **Permissions:**  
  You must have sufficient permissions to read from the source directories and write to the destination directories (both locally and remotely).

- **Service Stopped:**  
  Ensure that your Storj node service is stopped before running the migration script.  
  *Example:* `sudo systemctl stop storagenode`

## Usage

1. **Stop the Storj Node Service:**  
   Before beginning the migration, stop your Storj node service to ensure no files are being modified:
   ```bash
   sudo systemctl stop storagenode
