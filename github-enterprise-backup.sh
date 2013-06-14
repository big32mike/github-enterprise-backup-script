#!/bin/sh
#
# Backup Script for GitHub Enterprise Server
#
# To use:
#   - ensure the server running this script has authorized ssh access
#   - update the custom variables below to fit your needs
#   - create cron job to run on a schedule
#
#
# Note: 
#   To use the Amazon S3 option you will need to install and configure
#   the s3cmd utility.  For Ubuntu 12.04 the following is useful:
#
# - import signing key
#   $ wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | sudo apt-key add -
#
# - add repo to sources
#   $ sudo wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
# 
# - refresh cache and install
#   $ sudo apt-get update && sudo apt-get install s3cmd
#
# - configure s3cmd
#   $ s3cmd --configure
#
# - Be sure to have your S3 bucket, access key, secret key, and encryption password ready!
# - Use the Amazon portal to adjust the 'Lifecycle' rules as needed.
#
# ref: 
#   https://support.enterprise.github.com/entries/21160081-Backing-up-your-installation
#   http://s3tools.org/s3cmd
#
#
# created: 2013.05.17 by jamujr
# updated: 2013.05.20


# Custom variables
#
SERVER="server.domain.com"                         # This is the name or ip of our server.
GZNAME="github-enterprise-backup"                  # This is the name appended to the date for our zipped file.
FL2KEP=50                                          # This is the number of files to keep in the BAKUPS folder.
DIROUT="/backups/current/";                        # This is the directory where we output our backup files.
BAKUPS="/backups/archive";                         # This is the directory where we package the outputted files.

KEY="/path/to/key"

# Amazon S3 variables
#
USES3B=false;                                      # To enable Amazon S3 upload set to true. (must have s3cmd; see notes above)
S3FLDR="s3://your-s3-bucket-name";                 # This is the Amazon S3 Bucket location for uploads.
S3RSYC=false;                                      # To re-sync your entire 'BAKUPS' folder to S3 set to true.


# Create our backup files
#
echo "1) Exporting GitHub Enterprise backup"
ssh -i $KEY "admin@"$SERVER "ghe-export-authorized-keys" > $DIROUT"authorized-keys.json"
ssh -i $KEY "admin@"$SERVER "ghe-export-es-indices" > $DIROUT"es-indices.tar"
ssh -i $KEY "admin@"$SERVER "ghe-export-mysql" | gzip > $DIROUT"enterprise-mysql-backup.sql.gz"
ssh -i $KEY "admin@"$SERVER "ghe-export-redis" > $DIROUT"backup-redis.rdb"
ssh -i $KEY "admin@"$SERVER "ghe-export-repositories" > $DIROUT"enterprise-repositories-backup.tar"
ssh -i $KEY "admin@"$SERVER "ghe-export-settings" > $DIROUT"settings.json"
ssh -i $KEY "admin@"$SERVER "ghe-export-ssh-host-keys" > $DIROUT"host-keys.tar"


# Package our files by the date
#
echo "2) Packaging the files"
CURRENT_DATE="$(date +%Y.%m.%d-%H%M)"; # Finds the current date, added timestamp for more frequent backups
mkdir -p $BAKUPS                       # Create backup folder if not already there for backup storage
FILENAME=$GZNAME"-"$CURRENT_DATE.tgz   # Generate our filename
tar -c $DIROUT | gzip > $FILENAME      # Compress our directory
mv $FILENAME $BAKUPS/                  # Moves our compressed file into the final backup folder


# Keeps the last 'FL2KEP' of files
#
echo "3) Location clean up"
cd $BAKUPS
for i in `ls -t * | tail -n+2`; do
ls -t * | tail -n+$(($FL2KEP + 1)) | xargs rm -f
done


# Backup to Amazon S3
#
if $USES3B ; then
   echo "4) Uploading to S3 Bucket"
   case $BAKUPS in */) BAKUPS="$BAKUPS";; *) BAKUPS="$BAKUPS/";; esac   # ensure our path end with /
   case $S3FLDR in */) S3FLDR="$S3FLDR";; *) S3FLDR="$S3FLDR/";; esac   # ensure our path end with /
   if $S3RSYC ; then
     s3cmd put --encrypt --recursive $BAKUPS $S3FLDR
   else
     s3cmd put --encrypt $BAKUPS$FILENAME $S3FLDR
   fi
fi


# Exit our script
#
echo "--done--"
exit 0 
