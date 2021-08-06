#!/bin/bash
# Automate the timeline processing for an input zip file
# Usage: triage_processor_l2t-ts.sh /path/to/triage.zip
# Inspired by https://github.com/ReconInfoSec/velociraptor-to-timesketch
PARENT_DATA_DIR="/cases/processor"

process_files () {
    ZIP=$1
    echo $(date +'%Y-%m-%d %H:%M:%S'): Received $ZIP | tee -a $PARENT_DATA_DIR/$ZIP.log
    md5sum $PARENT_DATA_DIR/$ZIP | tee -a $PARENT_DATA_DIR/$ZIP.log
    
    # Get system name
    SYSTEM=$(echo $ZIP|cut -d"." -f 1)
    
    # Unzip
    echo A | unzip -q $PARENT_DATA_DIR/$ZIP -d $PARENT_DATA_DIR/$SYSTEM
    echo $(date +'%Y-%m-%d %H:%M:%S'): Unzipped $ZIP | tee -a $PARENT_DATA_DIR/$ZIP.log
    
    # Remove from subdir
    #mv $PARENT_DATA_DIR/$SYSTEM/fs/clients/*/collections/*/uploads/* $PARENT_DATA_DIR/$SYSTEM/
    
    # Delete unnecessary collection data
    #rm -r $PARENT_DATA_DIR/$SYSTEM/fs $PARENT_DATA_DIR/$SYSTEM/UploadFlow.json $PARENT_DATA_DIR/$SYSTEM/UploadFlow 
    
    # Run log2timeline and generate Plaso file
    echo $(date +'%Y-%m-%d %H:%M:%S'): "Beginning Plaso creation..." | tee -a $PARENT_DATA_DIR/$ZIP.log
    log2timeline.py --status_view none --parsers 'win7_slow,!filestat' $PARENT_DATA_DIR/$SYSTEM.plaso $PARENT_DATA_DIR/$SYSTEM
    echo $(date +'%Y-%m-%d %H:%M:%S'): "Plaso creation complete" | tee -a $PARENT_DATA_DIR/$ZIP.log

    # Run timesketch_importer to send Plaso data to Timesketch
    #docker exec -it timesketch_timesketch-worker_1 /bin/bash -c 'timesketch_importer -u $username -p "$password" --host http://timesketch-web:5000 --timeline_name $SYSTEM --sketch_id 1 /usr/share/timesketch/upload/plaso/$SYSTEM.plaso'
    echo $(date +'%Y-%m-%d %H:%M:%S'): "Beginning Timesketch import..." | tee -a $PARENT_DATA_DIR/$ZIP.log
    timesketch_importer -u sansforensics -p forensics --host http://127.0.0.1 --index_name plaso-$SYSTEM --timeline_name $SYSTEM-triage $PARENT_DATA_DIR/$SYSTEM.plaso
    echo $(date +'%Y-%m-%d %H:%M:%S'): "Timesketch import complete" | tee -a $PARENT_DATA_DIR/$ZIP.log

    # Copy Plaso files to dir being watched to upload to S3
    #cp -ar /usr/share/timesketch/upload/plaso/$SYSTEM.plaso /usr/share/timesketch/upload/plaso_complete
    
    # Delete unzipped triage data directory
    rm -r $PARENT_DATA_DIR/$SYSTEM
    echo $(date +'%Y-%m-%d %H:%M:%S'): "Removed unzipped triage directory" | tee -a $PARENT_DATA_DIR/$ZIP.log
    
    # end with log and with message to Node-Red
    echo $(date +'%Y-%m-%d %H:%M:%S'): "Processing complete for $ZIP" | tee -a $PARENT_DATA_DIR/$ZIP.log
}

TRIAGEZIP=$1
EXTENSION="${TRIAGEZIP##*.}"

if [[ $EXTENSION == "zip" ]]; then
    process_files $TRIAGEZIP
fi
```