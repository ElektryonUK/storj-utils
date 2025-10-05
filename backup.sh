#!/bin/bash

# === Configuration ===
DEST="/data/disk4/"                            # Destination directory
SRC="/data/disk3/disk4/"                       # Source directory (Storj node data)
WORKDIR="/home/elektryon/tmp_backup"           # Temporary working directory
mkdir -p "$WORKDIR"

FILELIST="$WORKDIR/filelist_all.txt"           # Master list of all files to back up

# === Step 0: Auto-detect CPU cores and disk health ===
CPU_CORES=$(nproc)
DEVICE=$(df "$SRC" | tail -1 | awk '{print $1}')  # Identify device from mount

echo "🧮 Detected $CPU_CORES CPU cores."
echo "🔍 Checking drive health for $DEVICE ..."

if command -v smartctl >/dev/null 2>&1; then
    SMART_REPORT=$(smartctl -A "$DEVICE" 2>/dev/null)

    # Extract key SMART attributes
    REALLOCATED=$(echo "$SMART_REPORT" | awk '/Reallocated_Sector_Ct/{print $10}')
    PENDING=$(echo "$SMART_REPORT" | awk '/Current_Pending_Sector/{print $10}')
    UNCORR=$(echo "$SMART_REPORT" | awk '/Offline_Uncorrectable/{print $10}')
    REPORTED=$(echo "$SMART_REPORT" | awk '/Reported_Uncorrectable_Errors/{print $10}')

    # Default to 0 if missing
    REALLOCATED=${REALLOCATED:-0}
    PENDING=${PENDING:-0}
    UNCORR=${UNCORR:-0}
    REPORTED=${REPORTED:-0}

    # Determine failing status
    if (( REALLOCATED > 0 || PENDING > 0 || UNCORR > 0 || REPORTED > 0 )); then
        FAILING=true
        echo "⚠️  SMART shows bad sectors or reallocation events!"
    else
        FAILING=false
        echo "✅ SMART indicates healthy drive."
    fi
else
    echo "⚠️ smartctl not found — skipping automatic health check."
    FAILING=false
fi

# === Step 1: Determine parallel job count ===
if [ "$FAILING" = true ]; then
    JOBS=2
    RSYNC_EXTRA="--bwlimit=40M"
    echo "🧯 Failing drive detected — limiting rsync to 2 jobs and throttling bandwidth."
else
    JOBS=$(( CPU_CORES / 2 ))
    [[ $JOBS -lt 2 ]] && JOBS=2
    RSYNC_EXTRA=""
    echo "🚀 Using $JOBS parallel rsync jobs."
fi

# === Step 2: Build full file list with live progress ===
echo "🔍 Building full file list from $SRC..."
> "$FILELIST"

( find "$SRC" -type f > "$FILELIST" ) &
FIND_PID=$!

while kill -0 $FIND_PID 2>/dev/null; do
    FILES_FOUND=$(wc -l < "$FILELIST")
    FILELIST_SIZE=$(du -h "$FILELIST" | awk '{print $1}')
    echo -ne "📄 Files found: $FILES_FOUND | Current size: $FILELIST_SIZE\r"
    sleep 5
done

wait $FIND_PID
echo -e "\n✅ File list complete!"

# === Step 3: Split list into chunks ===
echo "✂️ Splitting file list into $JOBS chunks..."
split -n l/$JOBS "$FILELIST" "$WORKDIR/filelist_chunk_"

# === Step 4: Calculate total size ===
TOTAL_SIZE=$(du -sb "$SRC" | awk '{print $1}')
echo "💾 Total size to backup: $((TOTAL_SIZE/1024/1024)) MB"

# === Step 5: Start parallel rsync jobs ===
echo "🚀 Starting parallel rsync jobs..."
for chunk in "$WORKDIR"/filelist_chunk_*; do
    rsync -a --inplace --partial --quiet $RSYNC_EXTRA --files-from="$chunk" "$SRC" "$DEST" &
done

# === Step 6: Monitor progress ===
while pgrep -f "rsync.*$SRC" >/dev/null; do
    COPIED=$(du -sb "$DEST" | awk '{print $1}')
    PERCENT=$(( COPIED * 100 / TOTAL_SIZE ))
    echo -ne "Progress: $PERCENT% ($((COPIED/1024/1024)) MB of $((TOTAL_SIZE/1024/1024)) MB)\r"
    sleep 10
done

echo -e "\n✅ Parallel rsync backup complete!"
