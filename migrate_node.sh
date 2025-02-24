#!/bin/bash
# Storj Node Migration Script with Remote Support, Two-Pass Sync, and Auto-Detection of Config File
#
# This script assists in migrating your Storj node’s DATA, configuration,
# and (optionally) LOG files. It supports both local and remote migrations.
#
# The script performs:
#   - An initial sync pass without the --delete flag.
#   - A second sync pass (if the Storj node is running) with the --delete flag.
#
# It also attempts to auto-detect the configuration file in the data directory.
#
# Check for required tools
for tool in rsync ssh scp pgrep find; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Error: $tool is not installed. Please install it and try again."
    exit 1
  fi
done

echo "Storj Node Migration Script with Remote Support, Two-Pass Sync, and Config Auto-Detection"
echo "==========================================================================================="
echo "Note: The first sync pass will run regardless of whether the Storj node"
echo "      is running. A second sync pass with the --delete flag will be run"
echo "      if the Storj node process is detected, ensuring an exact mirror."
echo ""

##############################
# SOURCE DETAILS
##############################
echo "SOURCE DETAILS"
echo "--------------"
read -p "Enter the full path of the current Storj node DATA directory: " OLD_DATA_DIR

# Attempt to locate the configuration file in the data directory
echo "Searching for configuration file in ${OLD_DATA_DIR}..."
CONFIG_CANDIDATE=$(find "$OLD_DATA_DIR" -maxdepth 1 -type f -iname "config.*" | head -n 1)
if [[ -n "$CONFIG_CANDIDATE" ]]; then
  read -p "Found configuration file: ${CONFIG_CANDIDATE}. Press Enter to use this or enter an alternative path: " USER_CONFIG
  if [[ -n "$USER_CONFIG" ]]; then
    OLD_CONFIG_FILE="$USER_CONFIG"
  else
    OLD_CONFIG_FILE="$CONFIG_CANDIDATE"
  fi
else
  read -p "Configuration file not found in the data directory. Please enter the full path of the configuration file: " OLD_CONFIG_FILE
fi

read -p "Do you want to migrate the Storj node LOG directory? (Y/n): " MIGRATE_LOGS
if [[ "$MIGRATE_LOGS" =~ ^[Yy]$ ]]; then
  read -p "Enter the full path of the current Storj node LOG directory: " OLD_LOG_DIR
fi

##############################
# DESTINATION DETAILS FOR DATA
##############################
echo ""
echo "DESTINATION DETAILS for DATA"
echo "----------------------------"
read -p "Is the destination (new) DATA directory on a remote server? (Y/n): " REMOTE_DATA
if [[ "$REMOTE_DATA" =~ ^[Yy]$ ]]; then
  read -p "Enter the remote username for the DATA directory: " REMOTE_USER_DATA
  read -p "Enter the remote host (IP or hostname) for the DATA directory: " REMOTE_HOST_DATA
  read -p "Enter the full path of the NEW DATA directory on the remote server: " NEW_DATA_DIR
else
  read -p "Enter the full path of the NEW DATA directory (local): " NEW_DATA_DIR
fi

##############################
# DESTINATION DETAILS FOR CONFIGURATION
##############################
echo ""
echo "DESTINATION DETAILS for CONFIGURATION file"
echo "------------------------------------------"
read -p "Is the destination for the configuration file on a remote server? (Y/n): " REMOTE_CONFIG
if [[ "$REMOTE_CONFIG" =~ ^[Yy]$ ]]; then
  read -p "Enter the remote username for the configuration file: " REMOTE_USER_CONFIG
  read -p "Enter the remote host (IP or hostname) for the configuration file: " REMOTE_HOST_CONFIG
  read -p "Enter the full path of the NEW directory for the configuration file on the remote server: " NEW_CONFIG_DIR
else
  read -p "Enter the full path of the NEW directory for the configuration file (local): " NEW_CONFIG_DIR
fi

##############################
# DESTINATION DETAILS FOR LOGS (if migrating)
##############################
if [[ "$MIGRATE_LOGS" =~ ^[Yy]$ ]]; then
  echo ""
  echo "DESTINATION DETAILS for LOGS"
  echo "----------------------------"
  read -p "Is the destination (new) LOG directory on a remote server? (Y/n): " REMOTE_LOGS
  if [[ "$REMOTE_LOGS" =~ ^[Yy]$ ]]; then
    read -p "Enter the remote username for the LOG directory: " REMOTE_USER_LOG
    read -p "Enter the remote host (IP or hostname) for the LOG directory: " REMOTE_HOST_LOG
    read -p "Enter the full path of the NEW LOG directory on the remote server: " NEW_LOG_DIR
  else
    read -p "Enter the full path of the NEW LOG directory (local): " NEW_LOG_DIR
  fi
fi

##############################
# CREATE DESTINATION DIRECTORIES
##############################
echo ""
echo "Creating destination directories..."

# DATA directory
if [[ "$REMOTE_DATA" =~ ^[Yy]$ ]]; then
  echo "Creating remote DATA directory on ${REMOTE_HOST_DATA}..."
  ssh "${REMOTE_USER_DATA}@${REMOTE_HOST_DATA}" "mkdir -p \"$NEW_DATA_DIR\""
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create remote DATA directory."
    exit 1
  fi
else
  mkdir -p "$NEW_DATA_DIR"
fi

# CONFIGURATION directory
if [[ "$REMOTE_CONFIG" =~ ^[Yy]$ ]]; then
  echo "Creating remote CONFIG directory on ${REMOTE_HOST_CONFIG}..."
  ssh "${REMOTE_USER_CONFIG}@${REMOTE_HOST_CONFIG}" "mkdir -p \"$NEW_CONFIG_DIR\""
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create remote CONFIG directory."
    exit 1
  fi
else
  mkdir -p "$NEW_CONFIG_DIR"
fi

# LOG directory (if applicable)
if [[ "$MIGRATE_LOGS" =~ ^[Yy]$ ]]; then
  if [[ "$REMOTE_LOGS" =~ ^[Yy]$ ]]; then
    echo "Creating remote LOG directory on ${REMOTE_HOST_LOG}..."
    ssh "${REMOTE_USER_LOG}@${REMOTE_HOST_LOG}" "mkdir -p \"$NEW_LOG_DIR\""
    if [ $? -ne 0 ]; then
      echo "Error: Failed to create remote LOG directory."
      exit 1
    fi
  else
    mkdir -p "$NEW_LOG_DIR"
  fi
fi

##############################
# FIRST PASS: Initial Sync (without --delete)
##############################
echo ""
echo "Starting first pass of migration (initial sync without --delete flag)..."

# DATA sync
echo "Migrating DATA directory..."
if [[ "$REMOTE_DATA" =~ ^[Yy]$ ]]; then
  rsync -ah --info=progress2 -e ssh "$OLD_DATA_DIR"/ "${REMOTE_USER_DATA}@${REMOTE_HOST_DATA}:$NEW_DATA_DIR"/
else
  rsync -ah --info=progress2 "$OLD_DATA_DIR"/ "$NEW_DATA_DIR"/
fi
if [ $? -ne 0 ]; then
  echo "Error: Data migration (first pass) failed."
  exit 1
fi
echo "First pass for DATA migration completed successfully."

# CONFIGURATION file copy (single pass)
echo ""
echo "Migrating CONFIGURATION file..."
if [[ "$REMOTE_CONFIG" =~ ^[Yy]$ ]]; then
  scp "$OLD_CONFIG_FILE" "${REMOTE_USER_CONFIG}@${REMOTE_HOST_CONFIG}:$NEW_CONFIG_DIR"/
else
  cp "$OLD_CONFIG_FILE" "$NEW_CONFIG_DIR"/
fi
if [ $? -ne 0 ]; then
  echo "Error: Configuration file migration failed."
  exit 1
fi
echo "Configuration file migrated successfully."

# LOG sync (if applicable)
if [[ "$MIGRATE_LOGS" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Migrating LOG directory (first pass)..."
  if [[ "$REMOTE_LOGS" =~ ^[Yy]$ ]]; then
    rsync -ah --info=progress2 -e ssh "$OLD_LOG_DIR"/ "${REMOTE_USER_LOG}@${REMOTE_HOST_LOG}:$NEW_LOG_DIR"/
  else
    rsync -ah --info=progress2 "$OLD_LOG_DIR"/ "$NEW_LOG_DIR"/
  fi
  if [ $? -ne 0 ]; then
    echo "Error: Log migration (first pass) failed."
    exit 1
  fi
  echo "First pass for LOG migration completed successfully."
fi

##############################
# SECOND PASS: Final Sync with --delete Flag
##############################
echo ""
echo "Checking if Storj node is running for the final sync pass..."
if pgrep -f storagenode >/dev/null; then
  echo "Storj node process detected. Starting second pass (final sync with --delete flag)..."
  
  # DATA second pass with --delete
  echo "Running second pass for DATA directory..."
  if [[ "$REMOTE_DATA" =~ ^[Yy]$ ]]; then
    rsync -ah --info=progress2 --delete -e ssh "$OLD_DATA_DIR"/ "${REMOTE_USER_DATA}@${REMOTE_HOST_DATA}:$NEW_DATA_DIR"/
  else
    rsync -ah --info=progress2 --delete "$OLD_DATA_DIR"/ "$NEW_DATA_DIR"/
  fi
  if [ $? -ne 0 ]; then
    echo "Error: Data migration (second pass) failed."
    exit 1
  fi
  echo "Second pass for DATA migration completed successfully."

  # LOG second pass with --delete (if applicable)
  if [[ "$MIGRATE_LOGS" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Running second pass for LOG directory..."
    if [[ "$REMOTE_LOGS" =~ ^[Yy]$ ]]; then
      rsync -ah --info=progress2 --delete -e ssh "$OLD_LOG_DIR"/ "${REMOTE_USER_LOG}@${REMOTE_HOST_LOG}:$NEW_LOG_DIR"/
    else
      rsync -ah --info=progress2 --delete "$OLD_LOG_DIR"/ "$NEW_LOG_DIR"/
    fi
    if [ $? -ne 0 ]; then
      echo "Error: Log migration (second pass) failed."
      exit 1
    fi
    echo "Second pass for LOG migration completed successfully."
  fi
else
  echo "Storj node is not running. Skipping second sync pass with --delete flag."
fi

##############################
# FINAL INSTRUCTIONS
##############################
echo ""
echo "Migration process completed."
echo "Review the migrated files and adjust configurations as needed."
echo "When ready, restart your Storj node service."
