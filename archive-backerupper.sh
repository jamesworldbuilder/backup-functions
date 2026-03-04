#!/bin/bash

# Loads global environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/backerupper-config.env"
source "$CONFIG_FILE"

# Defines dynamic paths
SRC_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
IGNORE_FILE="$SRC_DIR/$IGNORE_FILE_NAME"

# Verifies critical environment variables are loaded prior to execution
if [ -z "$BINARY_EXTENSIONS" ]; then
    echo "ERROR: BINARY_EXTENSIONS variable in $CONFIG_FILE not set"
    echo "  Add compressed archive file types to be backed up to Google Drive"
    echo "  Example: \"*.{tar,zst,zip,deb,tgz,iso,gz,xz,bz2,lz4,7z,rar,rpm,vdi,vmdk,qcow2,img}\""
    exit 1
fi

evaluate_synced_archives() {
    # Evaluates if archives Google Drive destination folder global variable is set
    if [ -z "$BINARY_GDRIVE_DEST" ]; then
        echo -e "\nERROR: BINARY_GDRIVE_DEST variable is not set\n"
        echo "Update $CONFIG_FILE to include the Google Drive destination folder..."
        echo "  Example: \"gdrive:compressed-files-backup\""
        read -r -p "  Have you updated the configuration file [y/n] (CTRL+C to cancel)? " user_choice
        
        if [ "$user_choice" == "y" ]; then
            # Restarts current script with all original arguments
            exec "$0" "$@"
        else
            echo "Operation canceled"
            exit 1
        fi
    fi

    echo -e "\n> Scanning $BINARY_GDRIVE_DEST for archive backup sync...\n"
    
    # Simulates transfer to detect missing files without writing data
    local DRY_RUN_OUTPUT
    DRY_RUN_OUTPUT=$(rclone copy "$BINARY_GDRIVE_DEST" "$SRC_DIR" --ignore-existing --dry-run 2>&1)
    
    # Catches fatal Rclone errors during simulation
    if echo "$DRY_RUN_OUTPUT" | grep -q -i "error"; then
        echo "ERROR: Rclone dry run failed"
        echo "$DRY_RUN_OUTPUT"
        return 1
    fi
    
    # Evaluates output for planned file transfers
    if echo "$DRY_RUN_OUTPUT" | grep -q "Not copying as"; then
        :
    elif echo "$DRY_RUN_OUTPUT" | grep -i -E "transferred:|copied:"; then
        echo -e "\n**Unsynced local archive files detected"
        read -r -p "  Sync and backup local compressed archive files [y/n] (CTRL+C to cancel)? " user_choice
        echo ""
        
        if [ "$user_choice" == "y" ]; then
            # Downloads files from remote destination to local source directory
            # Ignores files that already exist locally
            rclone copy "$BINARY_GDRIVE_DEST" "$SRC_DIR" --ignore-existing -P --transfers 4
            
            if [ $? -eq 0 ]; then
                echo -e "\nExisting archive backups synced successfully\n- Backup location: $BINARY_GDRIVE_DEST"
            else
                echo "ERROR: Rclone encountered a network issue during restore"
            fi
        else
            echo "No existing archive backup files found in $BINARY_GDRIVE_DEST - Skipping sync"
        fi
        return 0
    fi
    
    echo -e "\nLocal compressed archives are fully synced\n- Backup location: $BINARY_GDRIVE_DEST\n"
}

backup_archives() {
    echo -e -n "\n> Starting archive backup process...\n"
    
    local TEMP_FILTER="/tmp/rclone-archive-filter.txt"
    
    # Initializes empty temporary filter file
    > "$TEMP_FILTER"
    
    # Extracts specific archive rules from master ignore file
    if [ -f "$IGNORE_FILE" ]; then
        echo -e -n "\n> Applying exclusion rules from $IGNORE_FILE_NAME..."
        
        # Parses lines between specific brackets removes comments and 
        #  prepends minus sign for Rclone filter syntax
        sed -n '/^# \[BINARIES\]/,/^# \[END BINARIES\]/p' "$IGNORE_FILE" | grep -v '^#' | sed 's/^/- /' >> "$TEMP_FILTER"
    fi
    
    echo -e -n " OK\n\n"

    # Appends global inclusion extensions to filter file
    echo "+ $archive_EXTENSIONS" >> "$TEMP_FILTER"
    
    # Appends global exclusion to ignore all other files
    echo "- *" >> "$TEMP_FILTER" 
    
    # Streams files matching filter rules directly to remote destination
    rclone copy "$SRC_DIR" "$BINARY_GDRIVE_DEST" \
        --filter-from "$TEMP_FILTER" \
        -P --drive-chunk-size 64M --transfers 1
        
    if [ $? -eq 0 ]; then
        echo -e "\nArchive backup process completed successfully\n- Backup location: $BINARY_GDRIVE_DEST\n"
    else
        echo "ERROR: Rclone encountered a network issue"
    fi
    
    # Cleans up temporary parsing file
    rm -f "$TEMP_FILTER"
}

# Executes the sync cycle
evaluate_synced_archives
backup_archives
