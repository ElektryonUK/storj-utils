#!/bin/bash

# === Prompt for source and destination ===
read -rp "Enter the source directory (Storj node data): " SRC
read -rp "Enter the destination directory for backup: " DEST

# === Configuration ===
WORKDIR="$HOME/tmp_backup"           # Temporary working directory
mkdir -p "$WORKDIR"

FILELIST="$WORKDIR/filelist_all.txt"  # Master list of all files to back up

# === Step 0: Auto-detect CPU cores and disk health ===
CPU_CORES=$(nproc)
DEVICE=$(df "$SRC" | tail -1 | awk '{print $1}')  # Identify device from mount

echo "🧮 Detected $CPU_CORES CPU cores."
echo "🔍 Checking drive health for $DEVICE ..."

FAILING=false
if command -v smartctl >/dev/null 2>&1; then
    SMART_REPORT=$(smartctl -A "$DEVICE" 2>/dev/null)
    REALLOCATED=$(echo "$SMART_REPORT" | awk '/Reallocated_Sector_Ct/{print $10}')
    PENDING=$(echo "$SMART_REPORT" | awk '/Current_Pending_Sector/{print $10}')
    UNCORR=$(echo "$SMART_REPORT" | awk '/Offline_Uncorrectable/{print $10}')
    REPORTED=$(echo "$SMART_REPORT" | awk '/Reported_Uncorrectable_Errors/{print $10}')

    REALLOCATED=${REALLOCATED:-0}
    PENDING=${PENDING:-0}
    UNCORR=${UNCORR:-0}
    REPORTED=${REPORTED:-0}

    if (( REALLOCATED > 0 || PENDING > 0 || UNCORR > 0 || REPORTED > 0 )); then
        FAILING=true
        echo "⚠️  SMART shows bad sectors or reallocation events!"
    else
        echo "✅ SMART indicates healthy drive."
    fi
else
    echo "⚠️ smartctl not found — skipping automatic health check."
fi

# === Step 1: Determine parallel job count ===
if [ "$FAILING" = true ]; then
    JOBS=2
    RSYNC_EXTRA="--bwlimit=40M"
    echo "🧯 Failing drive detected — limiting rsync to 2 jobs and throttling bandwidth."
else
    JOBS=4
    RSYNC_EXTRA=""
    echo "🚀 Using $JOBS parallel rsync jobs."
fi

# === Step 2: Generate file list using rsync ===
if [ -s "$FILELIST" ]; then
    echo "📄 Using existing file list ($FILELIST)..."
else
    echo "🔍 Generating full file list with rsync..."
    rsync -a --list-only "$SRC" | awk '{print $5}' > "$FILELIST"
    echo "✅ File list created: $(wc -l < "$FILELIST") files"
fi

# === Step 3: Split into chunks of 1 million files ===
if ls "${CHUNK_PREFIX}"* 1> /dev/null 2>&1; then
    echo "✂️ Using existing chunk files..."
else
    echo "✂️ Splitting file list into chunks of $CHUNK_SIZE files..."
    split -l $CHUNK_SIZE "$FILELIST" "$CHUNK_PREFIX"
    echo "✅ File list successfully split into $(ls ${CHUNK_PREFIX}* | wc -l) chunks."
fi

# === Step 4: Calculate total size ===
TOTAL_SIZE=$(du -sb "$SRC" | awk '{print $1}')
echo "💾 Total size to backup: $((TOTAL_SIZE/1024/1024)) MB"

# === Step 5: Start parallel rsync jobs ===
echo "🚀 Starting parallel rsync jobs..."
CHUNKS=("${CHUNK_PREFIX}"*)

for ((i=0; i<${#CHUNKS[@]}; i+=JOBS)); do
    for j in $(seq 0 $((JOBS-1))); do
        idx=$((i+j))
        [ $idx -ge ${#CHUNKS[@]} ] && break
        rsync -a --inplace --partial --ignore-errors $RSYNC_EXTRA \
            --files-from="${CHUNKS[$idx]}" / "$DEST" &
    done
    wait
done

# === Step 6: Monitor progress ===
while pgrep -f "rsync.*$SRC" >/dev/null; do
    COPIED=$(du -sb "$DEST" | awk '{print $1}')
    PERCENT=$(( COPIED * 100 / TOTAL_SIZE ))
    echo -ne "Progress: $PERCENT% ($((COPIED/1024/1024)) MB of $((TOTAL_SIZE/1024/1024)) MB)\r"
    sleep 10
done

echo -e "\n✅ Parallel rsync backup complete!"
