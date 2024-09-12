#!/bin/bash
source ./svg.sh

usage="$0 <-d devname>  [-u lvunit ] [-r loop ]  [-n lvnum ] \n
[-m metasize] [-a 1/0 active] [-l logfile]\n
devname:The LNU device name \n
lvunit: The size (Megabyte) of a lv or pool .  optional. default is 16. \n
loop : The loop test number.  optional. default is 1 \n
lvnum: The number of lv/pool.  optional. default is auto calc. \n
       if specify it , the final value is min(lvnum, auto) \n
metasize: the meta size of vg, default  256M        \n
avtive: active flag of lv 1:active(default) 0 deactive 
logfile: logfile
Example: $0 -d /dev/sdb -u 1024 -r 1 -n 2 \n"

#Default
devname=/dev/sdb
lvunit=16
repeat=1
vgname=myvg
lvpoolname=mypool
lvname=mylv
remain_lunsize=2048
metasize=256
active=1
kubesan_test_log="/tmp/kubesan-"$(date "+%F-%H%M").log


while getopts "hd:u:r:n:m:a:l:" opt; do
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
  m)
    echo "$OPTARG"
    metasize=$OPTARG
    ;;
  a)
    echo "$OPTARG"
    active=$OPTARG
    ;;
  l)
    echo "$OPTARG"
    kubesan_test_log=$OPTARG
    ;;
  ?|*)
    echo -e $usage
    echo "Unknown parameter"
    exit 1
    ;;
  esac
done

wlog_set_log $kubesan_test_log 1
wlog_info "hello $kubesan_test_log"
 

svg_create_vg $devname $metasize

svg_test_lv_multi_pool $active
svg_del_all