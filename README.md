THIS PROJECT IS DEPRECATED: REPLACED WITH [Luen/BeDrive-FolderFort-Sync](https://github.com/Luen/BeDrive-FolderFort-Sync)

# FolderFort Backup

Use Folder Forts API to backup drive.

## Prerequisites

Install jq for JSON parsing:

`sudo apt-get install jq`

Install mail (if not already installed):

`sudo apt-get install mailutils`

## Usage

### Make the Script Executable

`chmod +x /path/to/your/backup_to_folderfort.sh`

### Schedule the Script with Cron

Open the cron tab: `crontab -e`

### Add a cron job to run the script nightly at 2 AM:

`0 2 * * * /path/to/your/backup_to_folderfort.sh`

## Notes

If [rclone](https://forum.rclone.org/t/new-provider-folderfort/47006) adds official support for Folder Fort, consider switching to that for improved performance and simplicity.
