#!/usr/bin/env bash

basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"     #  The location of this script
workingdir=$basedir/workfiles ;     mkdir -p $workingdir
metricsdir=$workingdir/metrics ;    mkdir -p $metricsdir
logdir=$basedir/logs ;              mkdir -p $logdir

source $basedir/config
offset=$((bdoffset+1))

fds=$(date -d "00:00:00" +%Y%U)     ##  Year and numbered week format
ts=$(date +"%Y%m%d" -d "00:00:00 $offset days ago")

## The name of this script
myname=$(basename $0)
 
hostname=$(echo $1 | awk -F "::" '{print $1}')
churl=$(echo $1 | awk -F "::" '{print $2}')

sleep .5

curl -sk $churl | tail -n +2 > $metricsdir/$hostname\__$ts\__hostout
echo Wrote  $metricsdir/$hostname\__$ts\__hostout | logger
