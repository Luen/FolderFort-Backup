#!/bin/bash

# Define variables
SOURCE_DIR="/path/to/your/drive"
API_URL="https://my.folderfort.com/api/v1"
USERNAME="your_username"
PASSWORD="your_password"
TOKEN_FILE="/path/to/token.txt"
LOG_FILE="/var/log/backup.log"
EMAIL="your_email@example.com"
DELETE_FOREVER=false  # Set to true to delete files permanently

# Function to send an email notification
send_email() {
    local subject="$1"
    local message="$2"
    echo "$message" | mail -s "$subject" "$EMAIL"
}

# Function to get a new token
get_token() {
    RESPONSE=$(curl -s -X POST "$API_URL/auth/login" -H "Content-Type: application/json" -d '{"email": "'$USERNAME'", "password": "'$PASSWORD'"}')
    TOKEN=$(echo "$RESPONSE" | jq -r '.user.access_token')
    if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
        send_email "Backup Failed: Unable to Get Token" "Failed to get a new token from Folder Fort. Response: $RESPONSE"
        exit 1
    fi
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

# Function to check if the service is operational
check_service() {
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL")
    if [ $STATUS -ne 200 ]; then
        send_email "Backup Failed: Service Down" "Folder Fort service is down or no longer operational."
        exit 1
    fi
}

# Function to upload a file
upload_file() {
    local file_path="$1"
    local file_name=$(basename "$file_path")

    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$API_URL/uploads" \
        -H "Authorization: Bearer $TOKEN" \
        -F "file=@$file_path" \
        -F "name=$file_name")
    if [ $RESPONSE -ne 201 ]; then
        send_email "Backup Failed: Upload Error" "Failed to upload file: $file_name. HTTP Response: $RESPONSE"
        return 1
    fi
    return 0
}

# Function to delete a file
delete_file() {
    local file_id="$1"

    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE "$API_URL/file-entries" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"entryIds": ["'$file_id'"], "deleteForever": '$DELETE_FOREVER'}')
    if [ $RESPONSE -ne 200 ]; then
        send_email "Backup Failed: Deletion Error" "Failed to delete file with ID: $file_id. HTTP Response: $RESPONSE"
        return 1
    fi
    return 0
}

# Function to get file ID
get_file_id() {
    local file_name="$1"

    curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/drive/file-entries" | jq -r ".[] | select(.name == \"$file_name\") | .id"
}

# Check if the service is operational
check_service

# Sync files
for file in $(find "$SOURCE_DIR" -type f); do
    file_name=$(basename "$file")
    file_id=$(get_file_id "$file_name")

    if [ -z "$file_id" ]; then
        echo "Uploading $file_name"
        if ! upload_file "$file"; then
            echo "Failed to upload $file_name" >> $LOG_FILE
        fi
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
        if ! delete_file "$file_id"; then
            echo "Failed to delete $remote_file" >> $LOG_FILE
        fi
    fi
done

echo "Backup completed on $(date)" >> $LOG_FILE
