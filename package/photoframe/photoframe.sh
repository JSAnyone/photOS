#! /bin/sh

DAVFS_CONF=/etc/photoframe/davfs2.conf
MOUNTPOINT_DAV=/data/photoframe/images_webdav
MOUNTPOINT_USB=/data/photoframe/images_usb
FOLDER_IMAGES=/data/photoframe/images_local
WEBDAV_CONF=/data/photoframe/photoframe.conf

PARAMS_FBV="--noclear --smartfit 30 --delay 1"

NO_IMAGES="/usr/share/photoframe/noimages.png"
BLACK_IMAGE="/usr/share/photoframe/blackimage.png"

ERROR_DIR="/tmp/photoframe"
mkdir -p $ERROR_DIR

DELAY=3

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
      images)                                                      
          ERROR=$(rsync -vtd --delete $FOLDER_IMAGES/ $MOUNTPOINT_USB/ 2>&1 > /dev/null)
          [ $? -eq 0 ] || error_write "Syncing images from local folder to usb stick failed: $ERROR"
          ;;                                                      
                                                                  
      black)                                                       
          ERROR=$(rm $MOUNTPOINT_USB/* 2>&1 > /dev/null)
          [ $? -eq 0 ] || error_write "Copying black image to usb stick failed at removing existing images: $ERROR"
          ERROR=$(cp $BLACK_IMAGE $MOUNTPOINT_USB/blackimage.png 2>&1 > /dev/null)
          [ $? -eq 0 ] || error_write "Copying black image to usb stick failed at copying black image: $ERROR"
          ;;                                                      
                                                                  
      *)
          echo "Usage: $0 {sync_usb black/images}"
          exit 1                                                
    esac
  #else
  #  error_write "No USB Stick mounted at specified mountpoint!"
  #fi
}


ERROR_TOPIC="";


function error_display {
  TTY=/dev/tty0
  echo -en "\e[H" > $TTY # Move tty cursor to beginning (1,1)
  for f in $ERROR_DIR/*.txt; do                                 
    [[ -f $f ]] || continue                                     
    cat $f > $TTY                             
  done
}

function error_settopic {
  ERROR_TOPIC=$1.txt;
  > $ERROR_DIR/$ERROR_TOPIC
}


function error_write {
  echo $1 >> $ERROR_DIR/$ERROR_TOPIC
}


num_files=0;

function get_image {
  local rnd_num
  rnd_num=-1
  local counter
  counter=0

  if [ $num_files -gt 0 ]
  then
    rnd_num=$(( $RANDOM % $num_files ))
  fi

  local IMAGE
  IMAGE=""
  for f in $FOLDER_IMAGES/*; do
    [[ -f $f ]] || continue
    if [[ $f =~ .*\.(jpg|JPG|png) ]]
    then
      if [ $counter -eq $rnd_num ]
      then
        IMAGE=$f;
      fi
      counter=$((counter+1)); 
    fi
  done

  num_files=$counter;

  if [ -z "$IMAGE" ]                                     
  then 
    if [ $num_files -eq 0 ]
    then
      IMAGE=$NO_IMAGES
    else
      IMAGE=$(get_image)
    fi
  fi                                                        

  echo $IMAGE
}



function start {

  while true; do
    IMAGE=$(get_image)
    echo $IMAGE

    fbv $PARAMS_FBV "$IMAGE"
    error_display
    sleep $DELAY
  done
}


function display_hdmi {
  case "$1" in                                                    
    on)                                                      
        vcgencmd display_power 1                                                   
        ;;                                                      
                                                                
    off)                                                       
        vcgencmd display_power 0                                                    
        ;;                                                      
                                                                
    *)                              
        echo "Usage: $0 display {on|off}"
        exit 1                                                   
  esac
}


function display_usb {
  case "$1" in                                                    
    on)                                                      
        sync_usb images                                                   
        ;;                                                      
                                                                
    off)                                                       
        sync_usb black                                                    
        ;;                                                      
                                                                
    *)                              
        echo "Usage: $0 display {on|off}"
        exit 1                                                   
  esac
}


function mode {
  case "$1" in                                                    
    hdmi)                                                                                               
        #remount partitions read/write
        mount -o remount, rw /
        mount -o remount, rw /boot                                                 
        #remove unnecessary and error producing lines 
        sed -i "/dwc2/d" /etc/modules
        sed -i "/dtoverlay=dwc2/d" /boot/config.txt
        sed -i "/\/data\/photoframe\/piusb.bin     \/data\/photoframe\/images_usb   vfat     users,umask=000,noauto   0      2/d" /etc/fstab.extra
        #disable not needed init scripts
        touch /data/etc/no_S77firstboot
        touch /data/etc/no_S78usb_share
        #Reboot, Filesystem will be mounted read-only automatically 
        reboot
        ;;                                                      
                                                                
    usb)      
        #remount partitions read/write
        mount -o remount, rw /
        mount -o remount, rw /boot                                                 
        #add necessary lines 
        grep -qxF "dwc2" /etc/modules || echo "dwc2" >> /etc/modules
        grep -qxF "dtoverlay=dwc2" /boot/config.txt || echo "dtoverlay=dwc2" >> /boot/config.txt    
        grep -qxF "/data/photoframe/piusb.bin     /data/photoframe/images_usb   vfat     users,umask=000,noauto   0      2" /etc/fstab.extra || echo "/data/photoframe/piusb.bin     /data/photoframe/images_usb   vfat     users,umask=000,noauto   0      2" >> /etc/fstab.extra    
        #enable needed init scripts
        rm -f /data/etc/no_S77firstboot
        rm -f /data/etc/no_S78usb_share                                             
        #Reboot, Filesystem will be mounted read-only automatically 
        reboot
        ;;                                                      
                                                                
    *)                              
        echo "Usage: $0 mode {hdmi|usb}"
        exit 1                                                   
esac
}


case "$1" in
    start)
        #check if hdmi mode is enabled
        if grep -qxF "dtoverlay=dwc2" /boot/config.txt; then
          echo "HDMI-mode is required for this operation!"
          exit 1
        else
          start
        fi
        ;;

    stop)
        #check if hdmi mode is enabled
        if grep -qxF "dtoverlay=dwc2" /boot/config.txt; then
          echo "HDMI-mode is required for this operation!"
          exit 1
        else
          stop
        fi
        ;;

    restart)
        #check if hdmi mode is enabled
        if grep -qxF "dtoverlay=dwc2" /boot/config.txt; then
          echo "HDMI-mode is required for this operation!"
          exit 1
        else
          stop
          start
        fi
        ;;

    sync)         
        #always sync webdav
        sync_dav
        #sync usb only if usb-mode is enabled
        if grep -qxF "dtoverlay=dwc2" /boot/config.txt; then
          if [ -f "$MOUNTPOINT_USB/blackimage.png" ]; then
            sync_usb black
          else
            sync_usb images
          fi
        fi
        ;;             
            
    display) 
        #depends on wether usb-mode or hdmi-mode is enabled
        if grep -qxF "dtoverlay=dwc2" /boot/config.txt; then
          display_usb $2
        else
          display_hdmi $2
        fi                                                      
        ;;    

    mode)                                                       
        mode $2                                                   
        ;;   

    test)
        #check if hdmi mode is enabled
        if grep -qxF "dtoverlay=dwc2" /boot/config.txt; then
          echo "HDMI-mode is required for this operation!"
          exit 1
        else
          get_image
        fi
        ;;                                       

    *)
      echo "Usage: $0 {start|stop|restart|sync|display on/off|mode hdmi/usb}"
      exit 1
esac

