#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DISABLE_COLOR='\033[0m' # Disable Color

wlog_file=/tmp/wlog.out
function wlog_color() {
  printf "$1"
  shift
  printf "$*\n" | tee -a ${wlog_file}
  printf "${DISABLE_COLOR}"
}

function wlog_error {
  wlog_color "${RED}" "$@"
}

function wlog_info {
  wlog_color "${GREEN}" "$@"
}

function wlog_warn {
  wlog_color "${YELLOW}" "$@"
}

function _exit_on_error() {
  if [ $? -ne 0 ]; then
    wlog_error "$@"
    exit 1
  fi
}

function _warn_on_error() {
  if [ $? -ne 0 ]; then
    wlog_warn "$@"
  fi

}
svg_env() {
  echo -e "
   yum install -y lvm2-lockd sanlock

   "
}
svg_cmd() {
  echo "CMD: $@"
  eval "$@"
  _exit_on_error "Error on $@"
  if [ $? -ne 0 ]; then
    return 1
  fi
}

svg_create_vg() {
  [[ "$1" == "" ]] || devname=$1
  lunsize=$(lsblk -nd $devname -b | awk '{print $4}')
  ((lunsize = lunsize / 1024 / 1024))
  echo "Lun lunsize:$lunsize"
  svg_cmd "pvcreate --config global/use_lvmlockd=0 --metadatasize 64m  $devname"
  svg_cmd "vgcreate --shared $vgname $devname"
  svg_cmd "lvmdevices --devicesfile $vgname --adddev $devname"
  svg_cmd "vgchange --devicesfile $vgname --lock-start"
  svg_cmd "vgs --devicesfile $vgname $vgname"
  svg_cmd "vgdisplay -C -o name,mda_size,mda_free $vgname"

}

svg_calc() {
  ((poolsize = lunsize - remain_lunsize))
  ((num = poolsize / lvunit))
  echo $num $lvnum
  [[ "$lvnum" == "" ]] || ((num = num > lvnum ? lvnum : num))
  echo "poolsize=$poolsize lvunit=$lvunit num=$num"

}

svg_test_lv_one_pool() {
  svg_calc
  svg_cmd "lvcreate --type thin-pool -L ${poolsize}M -n $lvpoolname $vgname "

  for r in $(seq $repeat); do
    for i in $(seq $num); do
      iter_lvname="${lvname}$i"
      echo "repeat:$r $i/$num ${iter_lvname}"
      svg_cmd "lvcreate --type thin -V ${lvunit}M -n ${iter_lvname} --thinpool $lvpoolname $vgname"
      svg_cmd "mkfs.ext4 /dev/${vgname}/${iter_lvname} > /dev/null"
    done
    svg_del_lv
  done

}

svg_test_lv_multi_pool() {

  svg_calc

  for r in $(seq $repeat); do
    for i in $(seq $num); do
      iter_lvname="${lvname}$i"
      iter_lvpoolname="${lvpoolname}$i"
      echo "repeat:$r $i/$num $iter_lvpoolname ${iter_lvname}"
      svg_cmd "lvcreate --type thin-pool -L ${lvunit}M -n $iter_lvpoolname $vgname "
      svg_cmd "lvcreate --type thin -V ${lvunit}M -n ${iter_lvname} --thinpool ${iter_lvpoolname} $vgname"
      svg_cmd "mkfs.ext4 /dev/${vgname}/${iter_lvname} > /dev/null"
    done
    svg_del_lv
  done

}

svg_test_lv_extend() {
  :
}

svg_del_lv() {
  mylvs=$(lvs | awk '{print $1}' | grep -E $lvname[0-9]*)
  for mylv in $mylvs; do
    svg_cmd "lvremove -f $vgname/$mylv"
  done
  mypools=$(lvs | awk '{print $1}' | grep -E $lvpoolname[0-9]*)
  for mypool in $mypools; do
    svg_cmd "lvremove -f $vgname/$mypool"
  done

}

svg_del_vg() {
  local dev
  if vgs $vgname; then
    dev=$(
      pvs | awk -v vgname="$vgname" '{if ($2 == vgname) { print $1 }} '
    )
    echo $dev
    svg_cmd "vgremove -f $vgname"
    svg_cmd "rm -rf /etc/lvm/devices/$vgname"
  fi

  if [[ "$dev" != "" ]]; then
    svg_cmd "pvremove -ff --config global/use_lvmlockd=0 $dev"
  fi
}

svg_del_all() {
  svg_del_lv
  svg_del_vg
}

svg_prune_vg() {
  #
  #systemctl restart lvm2-monitor.service
  lvdisplay -a $vgname
  rm -rf /etc/lvm/archive/$vgname*
  #  svg_cmd "vgchange --archivepool-prune $vgname"

}

#Default
devname=/dev/sdb
lvunit=16
repeat=1
vgname=myvg
lvpoolname=mypool
lvname=mylv
remain_lunsize=2048
