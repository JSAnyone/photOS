#! /bin/sh

DAVFS_CONF=/etc/photoframe/davfs2.conf
MOUNTPOINT_DAV=/data/photoframe/images_webdav
MOUNTPOINT_USB=/data/photoframe/images_usb
FOLDER_IMAGES=/data/photoframe/images_local
WEBDAV_CONF=/data/photoframe/photoframe.conf

NO_IMAGES="/usr/share/photoframe/noimages.png"
BLACK_IMAGE="/usr/share/photoframe/blackimage.png"

ERROR_DIR="/tmp/photoframe"
mkdir -p $ERROR_DIR


function read_conf {
  read -r firstline< $WEBDAV_CONF
  array=($firstline)
  echo ${array[0]}
}


function sync_dav {
  error_settopic 10_Sync

  if [ -f "$WEBDAV_CONF" ]; then
    chmod 0600 ${WEBDAV_CONF}

    mkdir -p $FOLDER_IMAGES                                         
    mkdir -p $MOUNTPOINT_DAV                                        
                                                                  
    REMOTE_DAV=$(read_conf)

    ERROR=$(mount.davfs -o ro,conf=$DAVFS_CONF $REMOTE_DAV $MOUNTPOINT_DAV 2>&1 > /dev/null)
    if [ $? -ne 0 ]
    then
      error_write "Mounting $REMOTE_DAV failed: $ERROR"
    fi

    # Check if dav is mounted before starting rsync
    mount | grep $MOUNTPOINT_DAV > /dev/null
    if [ $? -eq 0 ]
    then
      ERROR=$(rsync -vtd --delete $MOUNTPOINT_DAV/ $FOLDER_IMAGES 2>&1 > /dev/null)
      [ $? -eq 0 ] || error_write "Syncing images from webdav to local folder failed: $ERROR"

      umount $MOUNTPOINT_DAV
    fi
  else

    error_write "No WebDAV server configured. Go to http://$(hostname)"

  fi
}


function sync_usb {

  error_settopic 10_Sync

  mkdir -p $FOLDER_IMAGES                                         
  mkdir -p $MOUNTPOINT_USB

  # Check if usb stick is mounted before starting rsync
  #mount | grep $MOUNTPOINT_USB > /dev/null
  #if [ $? -eq 0 ]; then
    case "$1" in                                                    
      pictures)                                                      
          ERROR=$(rsync -vtd --delete $FOLDER_IMAGES/ $MOUNTPOINT_USB/ 2>&1 > /dev/null)
          [ $? -eq 0 ] || error_write "Syncing images from local folder to usb stick failed: $ERROR"
          ;;                                                      
                                                                  
      black)                                                       
          ERROR=$(rm $MOUNTPOINT_USB/* 2>&1 > /dev/null)
          ERROR+=$(cp $BLACK_IMAGE $MOUNTPOINT_USB/blackimage.png 2>&1 > /dev/null)
          [ $? -eq 0 ] || error_write "Copying black image to usb stick failed: $ERROR"
          ;;                                                      
                                                                  
      *)
          echo "Usage: $0 {sync_usb black/pictures}"
          exit 1                                                
    esac
  #else
  #  error_write "No USB Stick mounted at specified mountpoint!"
  #fi
}


ERROR_TOPIC="";

function error_settopic {
  ERROR_TOPIC=$1.txt;
  > $ERROR_DIR/$ERROR_TOPIC
}


function error_write {
  echo $1 >> $ERROR_DIR/$ERROR_TOPIC
}


function display {
  case "$1" in                                                    
    on)                                                      
        sync_usb pictures                                                   
        ;;                                                      
                                                                
    off)                                                       
        sync_usb black                                                    
        ;;                                                      
                                                                
    *)                              
        echo "Usage: $0 display {on|off}"
        exit 1                                                   
esac
}


case "$1" in
    sync)         
        sync_dav
        if [ -f "$MOUNTPOINT_USB/blackimage.png" ]; then
          sync_usb black
        else
          sync_usb pictures
        fi
        ;;             
            
    display)                                                       
        display $2                                                   
        ;;                                           

    *)
        echo "Usage: $0 {sync|display on/off}"
        exit 1
esac