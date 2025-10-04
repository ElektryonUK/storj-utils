#!/bin/bash
# ---------------------------------------------
# Parallel rsync backup script
# Copies files from SRC to DEST using multiple jobs
# and displays progress during the transfer.
# ---------------------------------------------

# Destination directory for the backup
SRC="/data/disk4/"

# Source directory to back up
DEST="/data/disk1/disk4/"

# Temporary working directory for intermediate files
WORKDIR="/home/elektryon/tmp_backup"

# Create the working directory if it doesn’t exist
mkdir -p "$WORKDIR"

# Number of parallel rsync jobs to run
JOBS=4

# Step 1: Build a list of all files that need to be backed up
echo "🔍 Building full file list..."
rsync -a --ignore-existing --dry-run --out-format="%n" "$SRC" "$DEST" > "$WORKDIR/filelist_all.txt"

# Step 2: Split the file list into N equal chunks for parallel rsync
echo "✂️ Splitting file list into $JOBS chunks..."
split -n l/$JOBS "$WORKDIR/filelist_all.txt" "$WORKDIR/filelist_chunk_"

# Step 3: Calculate the total size of the source directory (in bytes)
TOTAL_SIZE=$(du -sb "$SRC" | awk '{print $1}')
echo "Total size to backup: $((TOTAL_SIZE/1024/1024)) MB"

# Step 4: Start multiple rsync processes in parallel
echo "🚀 Starting parallel rsync jobs..."
for chunk in "$WORKDIR"/filelist_chunk_*; do
    # Each chunk file contains a subset of files to sync
    # --inplace allows updating files directly at the destination
    # --partial keeps partially transferred files for resuming
    # --quiet reduces console noise
    rsync -a --inplace --partial --quiet --files-from="$chunk" "$SRC" "$DEST" &
done

# Step 5: Monitor progress every 10 seconds while rsync jobs run
while pgrep -f "rsync.*$SRC" >/dev/null; do
    # Get current copied size at destination
    COPIED=$(du -sb "$DEST" | awk '{print $1}')
    # Calculate progress percentage
    PERCENT=$(( COPIED * 100 / TOTAL_SIZE ))
    # Print dynamic progress line
    echo -ne "Progress: $PERCENT% ($((COPIED/1024/1024)) MB of $((TOTAL_SIZE/1024/1024)) MB)\r"
    sleep 10
done

# Step 6: Print completion message when done
echo -e "\n✅ Parallel rsync backup complete!"
