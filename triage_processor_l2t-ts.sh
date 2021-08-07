#!/bin/bash
# Automate timeline processing for an input triage zip file
# Inspired by https://github.com/ReconInfoSec/velociraptor-to-timesketch

# Usage: triage_processor_l2t-ts.sh /path/to/triage.zip

# Set the $PARENT_DATA_DIR as the location where zips will be processed and plaso files saved
PARENT_DATA_DIR="/cases/processor"

# Get $TRIAGEZIP to process from positional argument 1. Add $EXTENSION check that it's a .zip file.
TRIAGEZIP=$1
EXTENSION="${TRIAGEZIP##*.}"

process_files () {
    ZIP=$1
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] Received $ZIP | tee -a $PARENT_DATA_DIR/$ZIP.log
    md5sum $PARENT_DATA_DIR/$ZIP | tee -a $PARENT_DATA_DIR/$ZIP.log
    
    # Get system name, or close approximation, based on CyLR and Velociraptor default naming conventions 
    SYSTEM=$(echo $ZIP|cut -d"." -f 1)
    # Create a unique "timestamped" name to avoid conflicts if identically-named zips are (re)processed
    TIMESTAMPED_NAME=$SYSTEM-$(date --utc +'%Y%m%dT%H%M%S')Z
    
    # Unzip triage data (fuse-zip is a nice alternative, but unzip is more universally installed)
    echo A | unzip -q $PARENT_DATA_DIR/$ZIP -d $PARENT_DATA_DIR/$TIMESTAMPED_NAME
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] Unzipped $ZIP | tee -a $PARENT_DATA_DIR/$ZIP.log
    
    # Run log2timeline and generate Plaso file
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Beginning Plaso creation..." | tee -a $PARENT_DATA_DIR/$ZIP.log
    log2timeline.py --status_view none --parsers 'win7_slow,!filestat' $PARENT_DATA_DIR/$TIMESTAMPED_NAME.plaso $PARENT_DATA_DIR/$TIMESTAMPED_NAME
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Plaso creation complete" | tee -a $PARENT_DATA_DIR/$ZIP.log

    # Run timesketch_importer to send Plaso data to Timesketch
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Beginning Timesketch import..." | tee -a $PARENT_DATA_DIR/$ZIP.log
    timesketch_importer -u sansforensics -p forensics --host http://127.0.0.1 --index_name plaso-$TIMESTAMPED_NAME --timeline_name $TIMESTAMPED_NAME-triage --sketch_name $TIMESTAMPED_NAME-sketch $PARENT_DATA_DIR/$TIMESTAMPED_NAME.plaso
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Timesketch import finished" | tee -a $PARENT_DATA_DIR/$ZIP.log
    
    # Delete unzipped triage data directory
    rm -r $PARENT_DATA_DIR/$TIMESTAMPED_NAME
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Removed unzipped triage directory" | tee -a $PARENT_DATA_DIR/$ZIP.log
    
    # Procecessing finished
    echo [$(date --utc +'%Y-%m-%d %H:%M:%S') UTC] "Processing job finished for $ZIP" | tee -a $PARENT_DATA_DIR/$ZIP.log
}

if [[ $EXTENSION == "zip" ]]; then
    process_files $TRIAGEZIP
fi