#!/bin/bash
# Automate timeline processing for an input triage zip file. See comments below for the step-by-step process.
# Version: 2022h01
# Usage: triage_processor_l2t-ts.sh /path/to/triage.zip
# Note: requires unzip, log2timeline in Docker (version 20210412), and timesketch_importer to be installed
#
# Created by Mike Pilkington for use in SANS FOR608
# Inspired by https://github.com/ReconInfoSec/velociraptor-to-timesketch
# Since creating this basic script, Janantha Marasinghe created a more robust version at:
# https://github.com/blueteam0ps/AllthingsTimesketch/blob/master/l2t_ts_watcher.sh

# Set the $PROCESSING_DIR as the location where zips will be processed and plaso files saved. 
# Make sure this path is correct and exists.
PROCESSING_DIR="/cases/processor"

# Set lot2timeline parsers. Default is optomized for a Windows triage data set with MFT parsing.
L2T_PARSERS="win7_slow,!filestat"

# Get $TRIAGEZIP to process from positional argument 1. Add $EXTENSION check that it's a .zip file.
TRIAGEZIP=$1
EXTENSION="${TRIAGEZIP##*.}"

process_files () {
    # Store full input parameter from user as $ZIPFULL
    ZIPFULL=$1
    # Extract the filename from user input and store as $ZIP
    ZIP=$(basename $ZIPFULL)
    # Get system name, or close approximation, based on CyLR and Velociraptor default naming conventions 
    SYSTEM=$(echo $ZIP|cut -d"." -f 1)
    # Create a unique lowercase timestamped name to avoid conflicts if identically-named zips are (re)processed
    # (lowercase because Elasticsearch indexes do not support uppercase letters)
    TIMESTAMPED_NAME=${SYSTEM,,}-$(date --utc +'%Y%m%dt%H%M%S')z
    
    # Log and hash new triage zip file for processing
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] Received $ZIPFULL | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] MD5 hash: $(md5sum $ZIPFULL) | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
    
    # Unzip triage data (fuse-zip is a time- & space-saving alternative, but unzip is more universally installed)
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] Unzipping $ZIPFULL to $PROCESSING_DIR/$TIMESTAMPED_NAME | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
    unzip -q $ZIPFULL -d $PROCESSING_DIR/$TIMESTAMPED_NAME
    
    # Run log2timeline and generate Plaso file
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Beginning Plaso creation of $PROCESSING_DIR/$TIMESTAMPED_NAME.plaso (this typically takes 20 minutes or more)..." | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
    docker run --rm -v $PROCESSING_DIR:$PROCESSING_DIR log2timeline/plaso:20210412 log2timeline --status_view none --parsers $L2T_PARSERS $PROCESSING_DIR/$TIMESTAMPED_NAME.plaso $PROCESSING_DIR/$TIMESTAMPED_NAME
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Plaso file creation finished" | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log

    # Run timesketch_importer to send Plaso data to Timesketch
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Beginning Timesketch import of $TIMESTAMPED_NAME-triage timeline (this typically takes an hour or more)..." | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
    shred -u ~/.timesketch*
    timesketch_importer -u sansforensics -p forensics --host http://127.0.0.1 --index_name l2t-$TIMESTAMPED_NAME --timeline_name $TIMESTAMPED_NAME-triage --sketch_name $TIMESTAMPED_NAME-sketch $PROCESSING_DIR/$TIMESTAMPED_NAME.plaso
    shred -u ~/.timesketch*
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Timesketch import finished" | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
    
    # Delete unzipped triage data directory, but leave the new plaso file in place (consider zipping it another step)
    rm -r $PROCESSING_DIR/$TIMESTAMPED_NAME
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Removed unzipped triage directory $PROCESSING_DIR/$TIMESTAMPED_NAME" | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
    
    # Procecessing finished
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Processing job finished for $ZIPFULL" | tee -a $PROCESSING_DIR/$TIMESTAMPED_NAME.log
}

if [ -f "$TRIAGEZIP" ]; then
    if [ -w "$PROCESSING_DIR" ]; then
        if [[ $EXTENSION == "zip" ]]; then
            process_files $TRIAGEZIP
        else
            echo "ERROR: '$TRIAGEZIP' does not appear to be a zip file."
        fi
    else
        echo "ERROR: Processing directory ($PROCESSING_DIR) does not exist or is not writable. Validate the 'PROCESSING_DIR' variable path in the script."
    fi
else
    echo "ERROR: The file '$TRIAGEZIP' does not exist."
fi