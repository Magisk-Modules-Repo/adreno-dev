# Diffusion Installer Config
# osm0sis @ xda-developers

INST_NAME="Adreno Systemless Installer Script";
AUTH_NAME="osm0sis @ xda-developers";

USE_ARCH=false
USE_ZIP_OPTS=false

custom_setup() {
  test ! -f "$DIR/Adreno-Nexus"*.zip && DIR=/sdcard;

  # go local and find our target zip
  cd "$DIR";
  ADRENO=$(ls Adreno-Nexus*.zip 2>/dev/null | head -n 1);
  ui_print " ";
  if [ "$ADRENO" ]; then
    ui_print "Supplied package: $ADRENO";
  else
    ui_print "Error: Adreno zip not detected!";
    abort;
  fi;
  cd /dev/tmp/$MODID;
}

custom_zip_opts() {
  return # stub
}

custom_target() {
  # make room on new installs for adreno which may not fit in su.img/magisk.img if there are other mods
  if [ "$SUIMG" -a ! -e /dev/tmp/su/su.d/000adrenomount -a ! -e /su/su.d/000adrenomount -a ! -e /dev/tmp/magisk/adreno-dev/module.prop -a ! -e /magisk/adreno-dev/module.prop -a ! -e /sbin/.core/img/adreno-dev/module.prop -a ! -e /sbin/.magisk/img/adreno-dev/module.prop -a "$(which e2fsck)" ]; then
    umount $MNT;
    test "$LOOP" && losetup -d $LOOP;
    payload_size_check "$DIR/$ADRENO" system;
    target_size_check $SUIMG;
    if [ "$reqSizeM" -gt "$curFreeM" ]; then
      suNewSizeM=$((((reqSizeM + curUsedM) / 32 + 1) * 32));
      ui_print " ";
      ui_print 'Resizing '"$(basename $SUIMG)"' to '"$suNewSizeM"'M ...';
      e2fsck -yf $SUIMG;
      resize2fs $SUIMG "$suNewSizeM"M;
    fi;
    mount_su;
  fi;

  # abort if not systemless root of some kind
  if [ ! "$SUIMG" -a ! "$BINDSBIN" -a ! "$MAGISK" ]; then
    ui_print " ";
    ui_print "Error: Systemless root not detected!";
    abort;
  fi;
}

custom_install() {
  unzip -o "$DIR/$ADRENO";
  ui_print " ";
  ui_print "Installing to $MNT$MAGISK/vendor ...";
  cp -rf system/* $MNT$MAGISK;
  set_perm_recursive 0 0 755 644 $MNT$MAGISK/vendor;
  set_perm 0 2000 755 $MNT$MAGISK/vendor $MNT$MAGISK/vendor/firmware $MNT$MAGISK/vendor/lib $MNT$MAGISK/vendor/lib/egl;

  if [ "$MNT" == /dev/tmp/su -o "$MNT" == /su -o "$BINDSBIN" ]; then
    ui_print "Installing 000adrenomount script to $MNT/su.d ...";
    cp -rf su.d/* $MNT/su.d;
    set_perm 0 0 755 $MNT/su.d/000adrenomount;
  elif [ "$MAGISK" ]; then
    ui_print "Installing Magisk configuration files ...";
    local adrenoname=$(basename "$ADRENO" .zip | cut -d- -f2-);
    sed -i "s/version=.*/version=${adrenoname}/g" module.prop;
  fi;
}

custom_postinstall() {
  return # stub
}

custom_uninstall() {
  return # stub
}

custom_postuninstall() {
  rm -rf $MNT/su.d/000adrenomount $MNT$MAGISK/vendor;
}

custom_cleanup() {
  return # stub
}

custom_exitmsg() {
  return # stub
}

# additional custom functions
payload_size_check() {
  local entry item zip;
  zip="$1";
  shift;
  for item in "$@"; do
    echo " $item" >> grepfile.tmp;
  done;
  reqSizeM=0;
  for entry in $(unzip -l "$zip" 2>/dev/null | grep -f grepfile.tmp | tail -n +4 | awk '{ print $1 }'); do
    if [ $entry != "--------" ]; then
      reqSizeM=$((reqSizeM + entry));
    else
      break;
    fi;
  done;
  if [ $reqSizeM -lt 1048576 ]; then
    reqSizeM=1;
  else
    reqSizeM=$((reqSizeM / 1048576));
  fi;
  rm -f grepfile.tmp;
}

target_size_check() {
  curBlocks=$(e2fsck -n $1 2>/dev/null | cut -d, -f3 | cut -d\  -f2);
  curUsedM=$((`echo "$curBlocks" | cut -d/ -f1` * 4 / 1024));
  curSizeM=$((`echo "$curBlocks" | cut -d/ -f2` * 4 / 1024));
  curFreeM=$((curSizeM - curUsedM));
}

