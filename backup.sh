#!/bin/bash

# === Configuration ===
DEST="/data/disk4/"                            # Destination directory
SRC="/data/disk3/disk4/"                       # Source directory (Storj node data)
WORKDIR="/home/elektryon/tmp_backup"           # Temporary working directory
mkdir -p "$WORKDIR"

# === Step 0: Determine optimal job count ===
CPU_CORES=$(nproc)
echo "🧮 Detected $CPU_CORES CPU cores."

# Ask user if this is a failing HDD
read -p "💿 Is this a failing or degraded HDD? (y/n): " FAILING
if [[ "$FAILING" =~ ^[Yy]$ ]]; then
    JOBS=2
    echo "⚠️  Failing drive detected — limiting parallel rsync to 2 jobs for safety."
else
    JOBS=$(( CPU_CORES / 2 ))
    [[ $JOBS -lt 2 ]] && JOBS=2
    echo "🚀 Using $JOBS parallel rsync jobs."
fi

FILELIST="$WORKDIR/filelist_all.txt"           # Master list of all files to back up

# === Step 1: Build full file list with progress ===
echo "🔍 Building full file list from $SRC..."
> "$FILELIST"

# Run 'find' in the background and monitor its progress
( find "$SRC" -type f > "$FILELIST" ) &
FIND_PID=$!

# Progress loop while filelist is being built
while kill -0 $FIND_PID 2>/dev/null; do
    FILES_FOUND=$(wc -l < "$FILELIST")
    FILELIST_SIZE=$(du -h "$FILELIST" | awk '{print $1}')
    echo -ne "📄 Files found: $FILES_FOUND | Current size: $FILELIST_SIZE\r"
    sleep 5
done

wait $FIND_PID
echo -e "\n✅ File list complete!"

# === Step 2: Split file list into chunks for parallel rsync ===
echo "✂️ Splitting file list into $JOBS chunks..."
split -n l/$JOBS "$FILELIST" "$WORKDIR/filelist_chunk_"

# === Step 3: Calculate total size ===
TOTAL_SIZE=$(du -sb "$SRC" | awk '{print $1}')
echo "💾 Total size to backup: $((TOTAL_SIZE/1024/1024)) MB"

# === Step 4: Start parallel rsync jobs ===
echo "🚀 Starting parallel rsync jobs..."
for chunk in "$WORKDIR"/filelist_chunk_*; do
    rsync -a --inplace --partial --quiet --files-from="$chunk" "$SRC" "$DEST" &
done

# === Step 5: Monitor progress ===
while pgrep -f "rsync.*$SRC" >/dev/null; do
    COPIED=$(du -sb "$DEST" | awk '{print $1}')
    PERCENT=$(( COPIED * 100 / TOTAL_SIZE ))
    echo -ne "Progress: $PERCENT% ($((COPIED/1024/1024)) MB of $((TOTAL_SIZE/1024/1024)) MB)\r"
    sleep 10
done

echo -e "\n✅ Parallel rsync backup complete!"
