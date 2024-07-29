#!/bin/bash

# Define variables
SOURCE_DIR="/path/to/your/4tb_ssd"
API_URL="https://my.folderfort.com/api/v1"
USERNAME="your_username"
PASSWORD="your_password"
TOKEN_FILE="/path/to/token.txt"

# Function to get a new token
get_token() {
    TOKEN=$(curl -s -X POST "$API_URL/auth/login" -H "Content-Type: application/json" -d '{"email": "'$USERNAME'", "password": "'$PASSWORD'"}' | jq -r '.token')
    echo $TOKEN > $TOKEN_FILE
}

# Load token
if [ -f "$TOKEN_FILE" ]; then
    TOKEN=$(cat $TOKEN_FILE)
else
    get_token
fi

# Check if token is valid
VALID=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$API_URL/drive/file-entries")
if [ $VALID -ne 200 ]; then
    get_token
fi

# Function to upload a file
upload_file() {
    local file_path="$1"
    local file_name=$(basename "$file_path")

    curl -X POST "$API_URL/uploads" \
        -H "Authorization: Bearer $TOKEN" \
        -F "file=@$file_path" \
        -F "name=$file_name"
}

# Function to delete a file
delete_file() {
    local file_id="$1"

    curl -X DELETE "$API_URL/file-entries/$file_id" \
        -H "Authorization: Bearer $TOKEN"
}

# Function to get file ID
get_file_id() {
    local file_name="$1"

    curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/drive/file-entries" | jq -r ".data[] | select(.name == \"$file_name\") | .id"
}

# Sync files
for file in $(find "$SOURCE_DIR" -type f); do
    file_name=$(basename "$file")
    file_id=$(get_file_id "$file_name")

    if [ -z "$file_id" ]; then
        echo "Uploading $file_name"
        upload_file "$file"
    else
        echo "File $file_name already exists, skipping"
    fi
done

# Delete files that no longer exist locally
remote_files=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/drive/file-entries" | jq -r ".data[].name")
for remote_file in $remote_files; do
    if [ ! -f "$SOURCE_DIR/$remote_file" ]; then
        file_id=$(get_file_id "$remote_file")
        echo "Deleting $remote_file"
        delete_file "$file_id"
    fi
done

echo "FolderFort: Backup completed on $(date)" >> /var/log/backup.log
