#!/bin/bash
source ./svg.sh

usage="$0 <-d devname>  [-u lvunit ] [-r loop ]  [-n lvnum ]\n
devname:The LNU device name \n
lvunit: The size (Megabyte) of a lv or pool .  optional. default is 16. \n
loop : The loop test number.  optional. default is 1 \n
lvnum: The number of lv/pool.  optional. default is auto calc. \n
       if specify it , the final value is min(lvnum, auto) \n\n

Example: $0 -d /dev/sdb -u 1024 -r 1 -n 2 \n"

#Default
devname=/dev/sdb
lvunit=16
repeat=1
vgname=myvg
lvpoolname=mypool
lvname=mylv
remain_lunsize=2048
while getopts "hd:u:r:n:" opt; do
  case $opt in
  h)
    echo -e $usage
    exit 0
    ;;
  d)
    devname="$OPTARG"
    ;;
  u)
    lvunit=$OPTARG
    ;;
  r)
    repeat="$OPTARG"
    ;;
  n)
    echo "$OPTARG"
    lvnum=$OPTARG
    ;;
  ?|*)
    echo -e $usage
    echo "Unknown parameter"
    exit 1
    ;;
  esac
done





svg_create_vg $devname
svg_test_lv_multi_pool
svg_del_all