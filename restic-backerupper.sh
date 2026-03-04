#!/bin/bash

# Loads global environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/backerupper-config.env"

# Defines dynamic paths
SRC_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
IGNORE_FILE="$SRC_DIR/$IGNORE_FILE_NAME"
export RESTIC_PASSWORD_FILE="$SCRIPT_DIR/$RESTIC_PASSWORD_FILE_NAME"
export RESTIC_REPOSITORY="rclone:${GDRIVE_DEST}"

# Generates global timestamp for file versioning
TIMESTAMP=$(date +"%b%d%Y-%H%M%S")

sync_aws_keys() {
    echo -e -n "\n> Fetching Restic key from AWS..."
    
    # Checks for executable AWS binary
    if [ ! -x "$AWS_CMD" ]; then
        echo "ERROR: Local AWS CLI not found at $AWS_CMD or is not executable"
        exit 1
    fi

    # Evaluates existing configuration status
    if ! "$AWS_CMD" configure get aws_access_key_id > /dev/null 2>&1; then
        
        # Injects predefined AWS credentials from configuration
        if [ -n "$AWS_ACCESS_KEY" ] && [ -n "$AWS_KEY_ID" ]; then
            echo -e "Existing AWS credentials found"
            "$AWS_CMD" configure set aws_access_key_id "$AWS_ACCESS_KEY"
            "$AWS_CMD" configure set aws_secret_access_key "$AWS_KEY_ID"
            "$AWS_CMD" configure set default.region "$AWS_DEFAULT_REGION"
        else
            echo "AWS credentials not found"
            # Loops credential options until valid input is received
            while true; do
                read -r -p "Update AWS global variables in config (u) or run interactive configuration (c) [v/c] (CTRL+C to cancel)? " user_choice
                
                if [ "$user_choice" == "u" ]; then
                    echo "Update AWS_ACCESS_KEY and AWS_KEY_ID in backerupper-config.env file"
                    
                    # Loops confirmation prompt for configuration update
                    while true; do
                        read -r -p "  Have you updated the configuration file [y/n] (CTRL+C to cancel)? " config_choice
                        
                        if [ "$config_choice" == "y" ]; then
                            # Restarts current script to load new environment variables
                            exec "$0" "$@"
                        elif [ "$config_choice" == "n" ]; then
                            echo "Operation canceled"
                            exit 1
                        else
                            echo "Invalid input - Please enter 'y' or 'n'"
                        fi
                    done
                elif [ "$user_choice" == "c" ]; then
                    # Initiates interactive AWS credential configuration
                    "$AWS_CMD" configure
                    break
                else
                    echo "Invalid input - Please enter 'u' or 'c'"
                fi
            done
        fi
    else
        echo -e -n " OK\n"
    fi

    echo -n "Checking $AWS_BUCKET_DEST for existing Restic key..."
    
    # Retrieves newest key from S3 bucket
    local LATEST_S3_KEY=$("$AWS_CMD" s3 ls "${AWS_BUCKET_DEST}/" 2>/dev/null | grep "restic_password" | sort | tail -n 1 | awk '{print $4}')

    if [ -n "$LATEST_S3_KEY" ]; then
        echo -e " OK\n (Key Found: $LATEST_S3_KEY)"
        
        # Evaluates local file conflicts
        if [ -f "$RESTIC_PASSWORD_FILE" ]; then
            # Loops conflict resolution prompt until valid input is received
            while true; do
                echo -e "**Local Restic key exists: $RESTIC_PASSWORD_FILE"
                read -r -p "- Overwrite (o) or rename and preserve existing file (p) [o/p] (CTRL+C to cancel)? " user_choice
                
                if [ "$user_choice" == "p" ]; then
                    mv "$RESTIC_PASSWORD_FILE" "${RESTIC_PASSWORD_FILE}-${TIMESTAMP}.bak"
                    echo "Existing local Restic key preserved and renamed"
                    break
                elif [ "$user_choice" == "o" ]; then
                    break
                else
                    echo "Invalid input - Please enter 'o' or 'p'"
                fi
            done
        fi

        echo "> Downloading Restic key to local directory..."
        "$AWS_CMD" s3 cp "${AWS_BUCKET_DEST}/${LATEST_S3_KEY}" "$RESTIC_PASSWORD_FILE"
        
        if [ $? -eq 0 ]; then
            chmod 600 "$RESTIC_PASSWORD_FILE"
        else
            echo "ERROR: Failed to download Restic key from S3 bucket $AWS_BUCKET_DEST"
            exit 1
        fi
    else
        echo "ERROR: No existing Restic key found in S3 bucket $AWS_BUCKET_DEST"
        
        # Handles missing remote key scenarios
        if [ -f "$RESTIC_PASSWORD_FILE" ]; then
            echo -e "Existing local Restic key found\n- Uploading to S3 bucket $AWS_BUCKET_DEST..."
            local S3_FILENAME="restic_password-${TIMESTAMP}.txt"
            "$AWS_CMD" s3 cp "$RESTIC_PASSWORD_FILE" "${AWS_BUCKET_DEST}/${S3_FILENAME}" --sse AES256
        else
            echo -e "ERROR: No existing Restic key found in local directory\n"
            echo -n "Generating a new Restic key..."
            openssl rand -base64 32 > "$RESTIC_PASSWORD_FILE"
            chmod 600 "$RESTIC_PASSWORD_FILE"
            echo -e -n " OK\nRestic key saved locally to $RESTIC_PASSWORD_FILE"
            
            local S3_FILENAME="restic_password-${TIMESTAMP}.txt"
            echo -n "Uploading new Restic key to AWS S3 bucket $AWS_BUCKET_DEST..."
            "$AWS_CMD" s3 cp "$RESTIC_PASSWORD_FILE" "${AWS_BUCKET_DEST}/${S3_FILENAME}" --sse AES256
            echo -e -n " OK\n"
        fi
    fi
}

setup_restic() {
    sync_aws_keys

    # Verifies Google Drive repository status
    if ! restic snapshots &>/dev/null; then
        echo -e "\n> Initializing encrypted Restic repository in Google Drive..."
        restic init
    fi
}

backup() {
    echo -e "\n> Initiating backup process..."
    setup_restic

    EXCLUDE_OPTS=()
    if [ -f "$IGNORE_FILE" ]; then
        echo -e -n "\n> Found backupignore file - Applying exclusion rules..."
        EXCLUDE_OPTS=(--exclude-file="$IGNORE_FILE")
        echo -e -n " OK\n"
    fi

    echo -e "\n> Starting Restic backup..."
    restic backup "$SRC_DIR" "${EXCLUDE_OPTS[@]}"

    if [ $? -eq 0 ]; then
        echo -e "\nBackup completed successfully - Files stored in $GDRIVE_DEST"
    else
        echo "ERROR: Network drop or permission issue"
    fi
}

# Executes backup routine
backup
