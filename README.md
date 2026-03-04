# Workspace Backup Scripts

A two-part Linux shell utility designed to backup local files to the cloud ([Google Drive](https://www.google.com/drive/)). 

[Restic](https://restic.net/) stores backups of local standard files in the cloud and syncs local file changes in the `restic-backerupper.sh` script. 
Utilizes the [AWS CLI](https://aws.amazon.com/cli/) to generate and/or retrieve the Restic key file from a specified [Amazon S3](https://aws.amazon.com/s3/) bucket. 

[Rclone](https://rclone.org/) stores backups of local compressed archive files in the cloud and syncs newly created local archives in the `archive-backerupper.sh` script. 

---

## Requirements

The following command-line tools must be installed and accessible on your system:
* **[Restic](https://restic.net/)**: Automates an encrypted deduplication backup and sync process of standard file types with a specified cloud storage provider.
* **[Rclone](https://rclone.org/)**: Automates a 1-to-1 file backup and sync process for large binary files with a specified cloud storage provider.
* **[AWS CLI](https://aws.amazon.com/cli/)**: Required for fetching and backing up the Restic key file to a specified AWS S3 bucket.
* **[OpenSSL](https://www.openssl.org/)**: Required for generating a secure 32-byte encryption key on the initial run.

#### Cloud Accounts
* **[Google Drive](https://www.google.com/drive/)**: Required for hosting the backup files.
* **[Amazon Web Services (AWS)](https://aws.amazon.com/)**: Required for hosting the Restic encryption key in an S3 bucket.
---

## Configuration

Before running the scripts, you must configure the global variables in the `backerupper-config.env` file. 

Store this file in the same directory as the scripts. It holds all global variables and cloud paths.

```bash
GDRIVE_DEST="gdrive:backups-folder" # Must match name of Google Drive destination folder (separate from BINARY_DEST)
AWS_BUCKET_DEST="s3://aws-bucket-name"
IGNORE_FILE_NAME=".backupignore"
RESTIC_PASSWORD_FILE_NAME=".restic-password"
AWS_CMD="/path/to/aws" # Example: /usr/local/bin/aws

# Located in the AWS Management Console under IAM Users Security Credentials
AWS_ACCESS_KEY=""
AWS_KEY_ID=""
AWS_DEFAULT_REGION="aws-region-0" # Example: us-east-1

BINARY_GDRIVE_DEST="gdrive:archive-backups" # Must match name of Google Drive destination folder (separate from GDRIVE_DEST)
BINARY_EXTENSIONS="*.{tar,zst,zip,deb,tgz,iso,gz,xz,bz2,lz4,7z,rar,rpm,vdi,vmdk,qcow2,img}"
```

### The Exclusion File (`.backupignore`)
Place this in the parent directory of the workspace you're backing up to dictate which files should be ignored during the backup process. 
To ignore specific archive folders, list them in `[BINARIES]` section of the `.backupignore` file and use double asterisks `**` for recursive ignoring.

**Example** `.backupignore` file:
```text
# Ignore specific folders/files
test_folder/*
System Volume Information/*
Downloads/isos.tar
aws-cli/*
python-bin/*
.Trash-1000/*
.git/*

# Ignore specific file types
*.tmp
*.tar
*.zst
*.zip
*.deb
*.tgz
*.iso
*.gz
*.xz
*.bz2
*.lz4
*.7z
*.rar
*.rpm
*.vdi
*.vmdk
*.qcow2
*.img

# Ignore specific files
test-file-1.txt
test-file-2.html
*~

# [BINARIES]
test_folder/**
System Volume Information/**
Downloads/isos.tar
aws-cli/**
python-bin/**
.Trash-1000/**
.git/**
# [END BINARIES]
```

## Usage & Options

### Backup Standard Files (`restic-backerupper.sh`)

#### How to Use
1. **Make it Executable**: 
```bash
chmod +x ./restic-backerupper.sh
```
2. **Run the Script**:
```bash
./restic-backerupper.sh
```

### Backup Compressed Archives (`archive-backerupper.sh`)

#### How to Use
1. **Make it Executable**: 
```bash
chmod +x ./archive-backerupper.sh
```
2. **Run the Script**:
```bash
./archive-backerupper.sh
```
