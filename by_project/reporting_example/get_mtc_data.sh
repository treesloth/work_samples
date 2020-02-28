#!/bin/bash

http_proxy=
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"     #  The location of this script
tempdir=$basedir/tmp;                      mkdir -p $tempdir
logdir=$basedir/logs;                      mkdir -p $logdir
RUN_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fds=$(date -d "00:00:00" +%Y%U)
logfile=$logdir/log_$fds
echo

####################################################################################################
##  Let's read some options...                                                                    ##

#+  These are defaults, overridden by command line if so desired:
w=300
p=3
s=2

while getopts ":c:p:w:s:" opt; do
    case $opt in
        c)
            echo "-$opt set to $OPTARG" >&2
            c=$OPTARG
            ;;
        p)
            echo "-$opt set to $OPTARG" >&2
            p=$OPTARG
            ;;
        w)
            echo "-$opt set to $OPTARG" >&2
            w=$OPTARG
            ;;
        s)
            echo "-$opt set to $OPTARG" >&2
            s=$OPTARG
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

#if [ -z "${c}" ] || [ -z "${p}" ]; then
if [ -z "${c}" ]; then
    usage
fi

window_s=$w
config_file=$c
periods=$p
startline=$s

source $config_file

run_tempfile=$tempdir/$tempfile
run_tempfile+=_$RUN_UUID
echo "Temp file will be " $run_tempfile | logger

echo "Running $0 with config file $config_file for $periods $window_s-second windows"
tsdbdatadir=$basedir/$tsdbdatabasedir;    mkdir -p $tsdbdatadir
echo "Data will be written to $tsdbdatadir"

##  Ok, options are acquired                                                                      ##
####################################################################################################


####################################################################################################
##  And now some handy functions                                                                  ##
  
usage() { 
    echo "Usage: $0 [-c <config_file_name>] [-p <# of periods to check>]" 1>&2
    exit 1
    }


logger () {
      # Log a time- and UUID-stamped piped message
      while read tobelogged
      do
        etsnow=$(date +%s)
        htsnow=$(echo $etsnow | awk '{print strftime("%c", $1, 1)}')
        echo -e $etsnow"\t" $htsnow "\t" $RUN_UUID "\t" $config_file "\t" $tobelogged >> $logfile
    done
    }


tsdbdates() {
    # Generate an MTC-compatible start and end date and a datastamp appropriate for a filename
    i=$1
    startdiff=$((i*window_s))
    startepoch=$((startpoint-startdiff))
    enddiff=$(($((i-1))*window_s+1))
    endepoch=$((startpoint-enddiff))
    startdt=$(date -u +"%Y/%m/%d-%H:%M:00" --date='@'$((startepoch-3600)))
    enddt=$(date -u +"%Y/%m/%d-%H:%M:59" --date='@'$((endepoch-3600)))
    maintepoch=$((86400*$((startepoch/86400))))
    echo $startdt $enddt $maintepoch
    }


build_url() {
    # Usage:
    # build_url $baseurl $startdt $enddt $metric $format
    qurl=$1
    qurl+="start=$2&end=$3"
    qurl+="&m="$4
    qurl+=$5

    qurl=${qurl/"RIDREPLACE"/$rid}

    echo $qurl
    }

show_time () {
    num=$1; min=0; hour=0; day=0;
    if((num>59)); then ((sec=num%60)); ((num=num/60))
        if((num>59)); then ((min=num%60)); ((num=num/60))
            if((num>23)); then ((hour=num%24)); ((day=num/24))
            else ((hour=num))
            fi
        else ((min=num))
        fi
    else ((sec=num))
    fi
    echo "$day"d"$hour"h"$min"m"$sec"s
}

##  And that's a wrap for functions...                                                            ##
####################################################################################################


baseurl="TSDB_API_BASE_URL_HERE"


format="&dtype=epoch&ftype=csvl"
startpoint=$(date +%s -u)
startpoint=$((window_s+window_s*$((startpoint/window_s))))

timespan=$(show_time $((periods*window_s)))
echo "Requested query will cover $timespan" | logger

for i in $(eval echo {1..$periods}); do
    for metric in ${metrics[@]}; do
        read startdt enddt maintepoch <<< $(tsdbdates $i)
        datafile=$(date -u +"%y%m%d" --date='@'$maintepoch)
        datafilearr[$datafile]='used'
    
    ##  Build and perform the first query...
        qurl=$(build_url $baseurl $startdt $enddt $metric $format)
        echo $startdt $metric
    #    curl -gsk $qurl | tail -n +2 >> data/$datafile 
    
        HTTP_STAT=999
        COUNTER=0
        RETRIES=3
        
        while (( "$HTTP_STAT" != "200" && $COUNTER <= $RETRIES)); do
        
            HTTP_STAT=$(curl -gsk $qurl \
              --write-out "%{http_code}" \
              --output $run_tempfile)
        
            #COUNTER=$((COUNTER+1))
            if [[ -e "$run_tempfile" ]]; then
                dos2unix $run_tempfile
            fi
            ((COUNTER++))
            echo TRIES: $COUNTER: $qurl | logger
        done
        
        if (( "$HTTP_STAT" != "200" )); then
            echo FAILED URL:  $qurl | logger
        else
            tail -n +$startline $run_tempfile >> $tsdbdatadir/$datafile
        fi

        sleep .5
    done
done

echo "The following files were updated: ${!datafilearr[@]}" | logger

for file in "${!datafilearr[@]}"; do
    echo Compacting $file | logger
    dos2unix $tsdbdatadir/$file
    sort $tsdbdatadir/$file | uniq > $tsdbdatadir/tmpfile
    mv $tsdbdatadir/tmpfile $tsdbdatadir/$file
    if [[ -e $tsdbdatadir/tmpfile ]]; then
        rm $tsdbdatadir/$file
    fi
done
