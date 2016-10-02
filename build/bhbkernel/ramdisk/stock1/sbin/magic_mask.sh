#!/system/bin/sh

LOGFILE=/cache/magisk.log
IMG=magisk.img

COREDIR=/magisk/.core

DUMMDIR=$COREDIR/dummy
MIRRDIR=$COREDIR/mirror

TMPDIR=/cache/tmp

# Use the included busybox to do everything in all scripts for maximum compatibility
# We also do so because we rely on the option "-c" for cp (reserve contexts)
export PATH="/data/busybox:$PATH"
# Version info
setprop magisk.version 6

log_print() {
  echo $1
  echo $1 >> $LOGFILE
  log -p i -t Magisk "$1"
}

mktouch() {
  mkdir -p ${1%/*} 2>/dev/null
  if [ -z "$2" ]; then
    touch $1 2>/dev/null
  else
    echo $2 > $1 2>/dev/null
  fi
}

unblock() {
  mktouch /cache/unblock/$1
  exit
}

run_scripts() {
  BASE=/magisk
  if [ "$1" = "post-fs" ]; then
    BASE=/cache/magisk
  fi

  for MOD in $BASE/* ; do
    if [ ! -f "$MOD/disable" ]; then
      if [ -f "$MOD/$1.sh" ]; then
        chmod 755 $MOD/$1.sh
        chcon 'u:object_r:system_file:s0' $MOD/$1.sh
        log_print "$1: $MOD/$1.sh"
        $MOD/$1.sh
      fi
    fi
  done
}

loopsetup() {
  LOOPDEVICE=
  for DEV in $(ls /dev/block/loop*); do
    if [ `losetup $DEV $1 >/dev/null 2>&1; echo $?` -eq 0 ]; then
      LOOPDEVICE=$DEV
      break
    fi
  done
}

target_size_check() {
  e2fsck -p -f $1
  curBlocks=`e2fsck -n $1 2>/dev/null | cut -d, -f3 | cut -d\  -f2`;
  curUsedM=$((`echo "$curBlocks" | cut -d/ -f1` * 4 / 1024));
  curSizeM=$((`echo "$curBlocks" | cut -d/ -f2` * 4 / 1024));
  curFreeM=$((curSizeM - curUsedM));
}

travel() {
  cd $1/$2
  if [ -f ".replace" ]; then
    rm -rf $TMPDIR/$2
    mktouch $TMPDIR/$2 $1
  else
    for ITEM in * ; do
      if [ ! -e "/$2/$ITEM" ]; then
        # New item found
        if [ $2 = "system" ]; then
          # We cannot add new items to /system root, delete it
          rm -rf $ITEM
        else
          if [ -d "$TMPDIR/dummy/$2" ]; then
            # We are in a higher level, delete the lower levels
            rm -rf $TMPDIR/dummy/$2
          fi
          # Mount the dummy parent
          mktouch $TMPDIR/dummy/$2

          mkdir -p $DUMMDIR/$2 2>/dev/null
          if [ -d "$ITEM" ]; then
            # Create new dummy directory
            mkdir -p $DUMMDIR/$2/$ITEM
          elif [ -L "$ITEM" ]; then
            # Symlinks are small, copy them
            cp -afc $ITEM $DUMMDIR/$2/$ITEM
          else
            # Create new dummy file
            mktouch $DUMMDIR/$2/$ITEM
          fi

          # Clone the original /system structure (depth 1)
          if [ -e "/$2" ]; then
            for DUMMY in /$2/* ; do
              if [ -d "$DUMMY" ]; then
                # Create dummy directory
                mkdir -p $DUMMDIR$DUMMY
              elif [ -L "$DUMMY" ]; then
                # Symlinks are small, copy them
                cp -afc $DUMMY $DUMMDIR$DUMMY
              else
                # Create dummy file
                mktouch $DUMMDIR$DUMMY
              fi
            done
          fi
        fi
      fi

      if [ -d "$ITEM" ]; then
        # It's an directory, travel deeper
        (travel $1 $2/$ITEM)
      elif [ ! -L "$ITEM" ]; then
        # Mount this file
        mktouch $TMPDIR/$2/$ITEM $1
      fi
    done
  fi
}

bind_mount() {
  if [ -e "$1" -a -e "$2" ]; then
    mount -o bind $1 $2
    if [ "$?" -eq "0" ]; then log_print "Mount: $1";
    else log_print "Mount Fail: $1"; fi 
  fi
}

case $1 in
  post-fs )
    # Temporary switch to permissive for maximum compatibility before sepolicy live patch
    # Will not always work (e.g. Samsung stock boot images)
    echo 0 > /sys/fs/selinux/enforce
    mv $LOGFILE /cache/last_magisk.log
    touch $LOGFILE
    chmod 644 $LOGFILE
    log_print "Magisk post-fs mode running..."

    for MOD in /cache/magisk/* ; do
      if [ -f "$MOD/remove" ]; then
        log_print "Remove module: $MOD"
        rm -rf $MOD
      elif [ -f "$MOD/auto_mount" -a ! -f "$MOD/disable" ]; then
        find $MOD/system -type f 2>/dev/null | while read ITEM ; do
          TARGET=${ITEM#$MOD}
          bind_mount $ITEM $TARGET
        done
      fi
    done

    run_scripts post-fs
    unblock post-fs
    ;;

  post-fs-data )
    if [ `mount | grep " /data " >/dev/null 2>&1; echo $?` -ne 0 ]; then
      # /data not mounted yet, we will be called again later
      unblock post-fs-data
    fi

    if [ `mount | grep " /data " | grep "tmpfs" >/dev/null 2>&1; echo $?` -eq 0 ]; then
      # /data not mounted yet, we will be called again later
      unblock post-fs-data
    fi

    log_print "Magisk post-fs-data mode running..."

    if [ -f "/cache/busybox" ]; then
      rm -rf /data/busybox
      mkdir -p /data/busybox
      mv /cache/busybox /data/busybox/busybox
      chmod 755 /data/busybox/busybox
      /data/busybox/busybox --install -s /data/busybox
      # Prevent issues
      rm -f /data/busybox/su
    fi

    mv /cache/stock_boot.img /data/ 2>/dev/null

    POLICYPATCH=true

    # Handle /cache image
    if [ -f "/cache/$IMG" ]; then
      log_print "/cache/$IMG found"
      if [ -f "/data/$IMG" ]; then
        log_print "/data/$IMG found, attempt to merge"

        # Handle large images from cache
        target_size_check /cache/$IMG
        CACHEUSED=$curUsedM
        target_size_check /data/$IMG
        if [ "$CACHEUSED" -gt "$curFreeM" ]; then
          NEWDATASIZE=$((((CACHEUSED + curUsedM) / 32 + 2) * 32))
          log_print "Expanding $IMG to ${NEWDATASIZE}M..."
          resize2fs /data/$IMG ${NEWDATASIZE}M
        fi

        # Start merging
        mkdir /cache/data_img
        mkdir /cache/cache_img

        # setup loop devices
        loopsetup /data/$IMG
        LOOPDATA=$LOOPDEVICE
        log_print "$LOOPDATA /data/$IMG"

        loopsetup /cache/$IMG
        LOOPCACHE=$LOOPDEVICE
        log_print "$LOOPCACHE /cache/$IMG"

        if [ ! -z "$LOOPDATA" ]; then
          if [ ! -z "$LOOPCACHE" ]; then
            # if loop devices have been setup, mount images
            OK=true

            if [ `mount -t ext4 -o rw,noatime $LOOPDATA /cache/data_img >/dev/null 2>&1; echo $?` -ne 0 ]; then
              OK=false
            fi

            if [ `mount -t ext4 -o rw,noatime $LOOPCACHE /cache/cache_img >/dev/null 2>&1; echo $?` -ne 0 ]; then
              OK=false
            fi

            if ($OK); then
              # Live patch sepolicy
              if ($POLICYPATCH); then
                LD_LIBRARY_PATH=/cache/cache_img/core/bin /cache/cache_img/.core/bin/supolicy --live
                if [ "$?" -eq "0" ]; then POLICYPATCH=false; fi;
              fi
              if ($POLICYPATCH); then
                LD_LIBRARY_PATH=/cache/data_img/core/bin /cache/data_img/.core/bin/supolicy --live
                if [ "$?" -eq "0" ]; then POLICYPATCH=false; fi;
              fi

              # Merge (will reserve selinux contexts)
              if [ `cp -afc /cache/cache_img/. /cache/data_img >/dev/null 2>&1; echo $?` -eq 0 ]; then
                log_print "Merge complete"
              fi
            fi

            umount /cache/data_img
            umount /cache/cache_img
          fi
        fi

        losetup -d $LOOPDATA
        losetup -d $LOOPCACHE

        rmdir /cache/data_img
        rmdir /cache/cache_img
      else 
        log_print "Moving /cache/$IMG to /data/$IMG "
        mv /cache/$IMG /data/$IMG
      fi
      rm -f /cache/$IMG
    fi

    # Shrink the image if possible
    target_size_check /data/$IMG
    NEWDATASIZE=$(((curUsedM / 32 + 2) * 32))
    if [ "$curSizeM" -gt "$NEWDATASIZE" ]; then
      log_print "Shrinking $IMG to ${NEWDATASIZE}M..."
      resize2fs /data/$IMG ${NEWDATASIZE}M
    fi

    # Mount /data image
    if [ `cat /proc/mounts | grep /magisk >/dev/null 2>&1; echo $?` -ne 0 ]; then
      loopsetup /data/$IMG
      if [ ! -z "$LOOPDEVICE" ]; then
        mount -t ext4 -o rw,noatime $LOOPDEVICE /magisk
      fi
    fi

    if [ `cat /proc/mounts | grep /magisk >/dev/null 2>&1; echo $?` -ne 0 ]; then
      log_print "magisk.img mount failed, nothing to do :("
      unblock post-fs-data
    fi

    if ($POLICYPATCH); then
      LD_LIBRARY_PATH=$COREDIR/bin $COREDIR/bin/supolicy --live
      if [ "$?" -eq "0" ]; then POLICYPATCH=false; fi;
    fi

    if (! $POLICYPATCH); then
      # If live patch succeeded, we can switch back to enforcing
      echo 1 > /sys/fs/selinux/enforce
    fi

    mkdir -p $DUMMDIR
    mkdir -p $MIRRDIR/system
    rm -rf /magisk/lost+found

    log_print "Preparing bind mounts"
    # First do cleanups
    rm -rf $DUMMDIR/*
    rmdir $(find /magisk -type d -depth ! -path "*core*" ) 2>/dev/null

    # Travel through all mods
    for MOD in /magisk/* ; do
      if [ -f "$MOD/remove" ]; then
        log_print "Remove module: $MOD"
        rm -rf $MOD
      elif [ -f "$MOD/auto_mount" -a -d "$MOD/system" -a ! -f "$MOD/disable" ]; then
        (travel $MOD system)
      fi
    done

    # Directories are not always dummies, need proper permissions
    find $DUMMDIR -type d -exec chmod 755 {} \;
    find $DUMMDIR -type f -exec chmod 644 {} \;

    # linker(64), t*box, and app_process* are required if we need to dummy mount bin folder
    if [ -f "$TMPDIR/dummy/system/bin" ]; then
      rm -f $DUMMDIR/system/bin/linker* $DUMMDIR/system/bin/t*box $DUMMDIR/system/bin/app_process*
      cd /system/bin
      cp -afc linker* t*box app_process* $DUMMDIR/system/bin/
    fi
    
    # Start mounting
      
    log_print "Bind mount dummy system"
    find $TMPDIR/dummy -type f 2>/dev/null | while read ITEM ; do
      TARGET=${ITEM#$TMPDIR/dummy}
      ORIG=$DUMMDIR$TARGET
      bind_mount $ORIG $TARGET
    done

    log_print "Bind mount module items"
    find $TMPDIR/system -type f 2>/dev/null | while read ITEM ; do
      TARGET=${ITEM#$TMPDIR}
      ORIG=`cat $ITEM`$TARGET
      bind_mount $ORIG $TARGET
      rm -f $DUMMDIR${TARGET%/*}/.dummy 2>/dev/null
    done

    log_print "Bind mount system mirror"
    bind_mount /system $MIRRDIR/system

    log_print "Bind mount mirror items"
    # Find all empty directores and dummy files, they should be mounted by original files in /system
    find $DUMMDIR -type d -exec sh -c 'if [ -z "$(ls -A $1)" ]; then echo $1; fi' -- {} \; -o \( -type f -size 0 -print \) | while read ITEM ; do
      ORIG=${ITEM/dummy/mirror}
      TARGET=${ITEM#$DUMMDIR}
      bind_mount $ORIG $TARGET
    done

    # All done
    rm -rf $TMPDIR

    run_scripts post-fs-data

    # Bind hosts for Adblock apps
    if [ ! -f "$COREDIR/hosts" ]; then
      cp -afc /system/etc/hosts $COREDIR/hosts
    fi
    log_print "Enabling systemless hosts file support"
    bind_mount $COREDIR/hosts /system/etc/hosts

    unblock post-fs-data
    ;;

  service )
    rm -rf /cache/unblock
    log_print "Magisk late_start service mode running..."
    run_scripts service
    ;;

  root )
    SUPATH=$(getprop magisk.supath)
    ROOT=$(getprop magisk.root)
    if [ "$ROOT" -eq "1" ]; then
      log_print "Mounting root"
      bind_mount $SUPATH /system/xbin
    else
      log_print "Unmounting root"
      umount -l /system/xbin
    fi
    ;;
esac
