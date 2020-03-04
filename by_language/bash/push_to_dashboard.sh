#!/bin/bash

http_proxy=
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"     #  The location of this script
RUN_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
source $basedir/bdoffset

##  This is no time to talk about time! We don't have the time!... What was I saying?
startdt=$(date -u +"%Y/%m/%d-00:00:00" -d "$bdoffset days ago")
enddt=$(date -u +"%Y/%m/%d-23:59:59" -d "$bdoffset days ago")
fds=$(date -d "00:00:00" +%Y%U)
ds=$(date +%y%m%d -d "$bdoffset days ago")

##  Files and directories and urls, oh my!
datadir=$basedir/data;              mkdir -p $datadir
pushdatadir=$basedir/data_push;     mkdir -p $pushdatadir
logdir=$basedir/logs;               mkdir -p $logdir
datafile=$datadir/$ds
logfile=$logdir/log_$fds
server="https://glass.<base_org_url>"
dataout_mtd=$pushdatadir/mtddata_$RUN_UUID\.tmp
dataout_7day=$pushdatadir/7daydata_$RUN_UUID\.tmp
dataout_30day=$pushdatadir/30daydata_$RUN_UUID\.tmp
minfile=$pushdatadir/mtdmin_$RUN_UUID\.tmp

#echo $startdt
#echo $enddt

##  Functions!
logger () {
    while read tobelogged
    do
        etsnow=$(date +%s)
        htsnow=$(echo $etsnow | awk '{print strftime("%c", $1, 1)}')
        echo -e $etsnow"\t" $htsnow "\t" $RUN_UUID "\t" $tobelogged >> $logfile
    done
    }

build_meter_data () {
    ##  Builds the dataset that will be pushed to the Dashing meter widgets
    if echo $1 99 | awk '{exit $1<$2?0:1}'; then
        color="ff0000"
    elif echo $1 99.5 | awk '{exit $1<$2?0:1}'; then
        color="ff8000"
    else
        color="008000"
    fi

    json_data="{\"status\": ["
        json_data+=$pct
        json_data+=", \"\#"
        json_data+=$color
        json_data+="\"], \"auth_token\": \"auth_token\", \"value\": "
        json_data+=$pct
        json_data+="}"
    echo $json_data
    }

build_text_count_data () {
    ##  Builds the dataset that will be pushed to the Dashing text widgets
    json_data="{ \"auth_token\": \"auth_token\", \"title\": \""
        json_data+="Host count: "$1
#        json_data+="${2^^} host count: "$1
        json_data+="\"}"
    echo $json_data
    }

build_moreinfo_count_data () {
    ##  Builds the moreinfo dataset that will be pushed to the small meters
    #+  EX:  {"auth_token": "auth_token", "moreinfo": "Some moreinfo"}
    json_data="{ \"auth_token\": \"auth_token\", \"moreinfo\": \""
        json_data+="Host count: "$1
#        json_data+="${2^^} host count: "$1
        json_data+="\"}"
    echo $json_data
    }


build_list_data () {
    ##  Builds the dataset that will be pushed to the Dashing list widgets
    ##  json_data+="{\"label\": \"Allowed\",\"value\": \"200000\"}"
    json_data="{ \"auth_token\":\"auth_token\", \"items\": ["
        json_data+=$(awk -F , -v dc=$2 '
                        $1 ~ dc {
                            jarr = jarr "{\"label\": \""$1"\",\"value\": \""$2"\"},"
                            }
                        END {
                            sub(",$", "", jarr)
                            print jarr
                        }' $1)
        json_data+="]}"
    echo $json_data
    }

build_prog_data () {
    ##  { "auth_token":"auth_token", "progress_items":
    #+  [{"name": "used", "progress": "10"}, {"name": "free", "progress": "90"},
    #+  ...
    #+  {"name": "free11", "progress": "90"}, {"name": "free12", "progress": "90"}] }
    json_data="{ \"auth_token\":\"auth_token\", \"progress_items\": ["
        json_data+=$(awk -F , -v dc=$2 '
                        $1 ~ dc {
                            jarr = jarr "{\"name\": \""$1"\",\"progress\": \""$2"\"},"
                            }
                        END {
                            sub(",$", "", jarr)
                            print jarr
                        }' $1)
        json_data+="]}"
    echo $json_data
    }




file_list () {
    if [ "$1" == "mtd" ]; then
        dlist=$(ls $datadir/$(date +%y%m)*)
    else
        cutoff=$(($1+1))
        counter=1
        until [ $counter -eq $cutoff ]; do
            dlist+=$datadir/$(date +%y%m%d -d "$counter days ago")" "
            let counter=$counter+1
        done
    fi
    echo $dlist
    }

#+  End functions!

## Pick one, but only one!
#rnd=$(( ( RANDOM % 10 )  + 1 ))
rnd=0

##  Populate the MTD top-level widget
echo Populate the MTD top-level widget
pct=$(awk -F , -v rnd=$rnd '
        FNR > 1 {
            total+=$3
            failed+=$4
        }
        END {
            fmt_pct = sprintf("%.1f %", 100 * (1 - failed / total))
            fmt_pct = fmt_pct
            print fmt_pct - (rnd / 10)
        }' $datadir/$(date +%y%m)*)

#json_data=$(build_meter_data $pct)
http_proxy= curl -s -X POST -H "Content-Type: application/json" -d \
        "$(build_meter_data $pct)" https://glass.<base_org_url>/widgets/dc-allmtd -k

## Populate the last 7, 30 day meters
echo Populate the last 7, 30 day meters
for i in 7 30; do
    pct=$(awk -F , -v rnd=$rnd '
        FNR > 1 {
            total+=$3
            failed+=$4
        }
        END {
            fmt_pct = sprintf("%.1f", 100 * (1 - failed / total))
            print fmt_pct - (rnd / 10)
            }' $(file_list $i))

    http_proxy= curl -s -X POST -H "Content-Type: application/json" -d \
        "$(build_meter_data $pct)" https://glass.<base_org_url>/widgets/dc-allpast$i -k
done

##  Create 7-day per-host values
echo Create 7- and 30-day and MTD per-host list values

for j in 7 30 mtd; do
#for j in 7 30; do
    if [ "$j" == "7" ]; then
        outfile=$dataout_7day
    elif [ "$j" == "30" ]; then
        outfile=$dataout_30day
    else
        outfile=$dataout_mtd
    fi

    awk -F , '
        BEGIN {
            OFS = ","
            }
        FNR > 1 {
            hosttotal[$2] += $3
            hostfail[$2] += $4
            }
        END {
            for (i in hosttotal) {
                hostavail[i] = sprintf("%.2f", 100 * (1 - hostfail[i] / hosttotal[i]))
                }
            for (i in hostavail) {
                print i, hostavail[i] | "sort -t , -nk 2"
                }
            }' $(file_list $j) > $outfile

    for i in us01 us02 us03 us04 uk01 uk02 nl01 fr01; do

        list_widget_name="dc-"$i"-"$j"day-list"
        curl -s -X POST -H "Content-Type: application/json" -d \
            "$(build_list_data $outfile $i)" \
            https://glass.<base_org_url>/widgets/$list_widget_name -k

        chart_widget_name="dc-"$i"-"$j"day-chart"
        curl -s -X POST -H "Content-Type: application/json" -d \
            "$(build_prog_data $outfile $i)" \
            https://glass.<base_org_url>/widgets/$chart_widget_name -k

    done
done

#echo rm $dataout_mtd
rm $dataout_7day
rm $dataout_30day
rm $dataout_mtd

exit
