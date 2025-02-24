#!/bin/bash
# Storj Node Migration Script with Remote Support
#
# This script assists you in migrating your Storj node’s DATA, configuration,
# and (optionally) LOG files. It can migrate files locally or to a remote server.
#
# IMPORTANT: Stop your Storj node service before running this script.
# Example: sudo systemctl stop storagenode

# Check required tools
for tool in rsync ssh scp; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Error: $tool is not installed. Please install it and try again."
    exit 1
  fi
done

echo "Storj Node Migration Script with Remote Support"
echo "==============================================="
echo "Please ensure your Storj node service is stopped before proceeding."
read -p "Have you stopped the Storj node service? (Y/n): " nodeStopped
if [[ ! "$nodeStopped" =~ ^[Yy]$ ]]; then
  echo "Please stop the Storj node service and then run this script again."
  exit 1
fi

##############################
# SOURCE INFORMATION
##############################
echo ""
echo "SOURCE DETAILS"
echo "--------------"
read -p "Enter the full path of the current Storj node DATA directory: " OLD_DATA_DIR
read -p "Enter the full path of the current Storj node CONFIGURATION file (e.g., config.yaml): " OLD_CONFIG_FILE

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
# DESTINATION DETAILS FOR CONFIG
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

# CONFIG directory
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
# MIGRATE DATA DIRECTORY
##############################
echo ""
echo "Migrating DATA directory..."
if [[ "$REMOTE_DATA" =~ ^[Yy]$ ]]; then
  rsync -ah --info=progress2 -e ssh "$OLD_DATA_DIR"/ "${REMOTE_USER_DATA}@${REMOTE_HOST_DATA}:$NEW_DATA_DIR"/
else
  rsync -ah --info=progress2 "$OLD_DATA_DIR"/ "$NEW_DATA_DIR"/
fi

if [ $? -ne 0 ]; then
  echo "Error: Data migration failed. Please check your paths and try again."
  exit 1
fi
echo "Data migration completed successfully."

##############################
# MIGRATE CONFIGURATION FILE
##############################
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

##############################
# MIGRATE LOG DIRECTORY (if chosen)
##############################
if [[ "$MIGRATE_LOGS" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Migrating LOG directory..."
  if [[ "$REMOTE_LOGS" =~ ^[Yy]$ ]]; then
    rsync -ah --info=progress2 -e ssh "$OLD_LOG_DIR"/ "${REMOTE_USER_LOG}@${REMOTE_HOST_LOG}:$NEW_LOG_DIR"/
  else
    rsync -ah --info=progress2 "$OLD_LOG_DIR"/ "$NEW_LOG_DIR"/
  fi

  if [ $? -ne 0 ]; then
    echo "Error: Log migration failed."
    exit 1
  fi
  echo "Log migration completed successfully."
fi

##############################
# FINAL INSTRUCTIONS
##############################
echo ""
echo "Migration process completed."
echo "Please review your new configuration files as needed."
echo "When ready, restart your Storj node service."
