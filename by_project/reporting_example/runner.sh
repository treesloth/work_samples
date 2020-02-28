#!/usr/bin/env bash

export https_proxy="http://10.131.149.111:3128/"

basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"     #  The location of this script
logdir=$basedir/logs;                       mkdir -p $logdir
referencedir=$basedir/data_reference;       mkdir -p $referencedir
interimdir=$basedir/data_interim_storage;   mkdir -p $interimdir
exceldir=$basedir/data_storage_excel;       mkdir -p $exceldir
fds=$(date -d "00:00:00" +%Y%U)
logfile=$logdir/log_$fds

source $basedir/config_storage.sh
tsdbdatadir=$basedir/$tsdbdatabasedir;      mkdir -p $tsdbdatadir

ts=$(date +%y%m%d_%H%M%S)
ds=$(date +%y%m%d)

api_token=$(cat /root/scripts/workspace/slackapi/slack_api_amh)

echo $basedir
echo $tsdbdatadir

file_list () {

    prelist=""
    dlist=""

    if [ "$1" == "mtd" ]; then
        prelist=$(ls $tsdbdatadir/$(date +%y%m)*)
    elif [ "$1" == "lm" ]; then
        prelist=$(ls $tsdbdatadir/$(date +%y%m -d "1 month ago")*)
    else
        cutoff=$(($1+1))
        counter=1
        until [ $counter -eq $cutoff ]; do
            prelist+=$tsdbdatadir/$(date +%y%m%d -d "$counter days ago")" "
            let counter=$counter+1
        done
    fi

    for file in ${prelist[@]}; do
        if [ -e $file ]; then
            dlist+=" "$file
        fi
    done

    echo $dlist
    }


logger () {
    # Log a time- and UUID-stamped piped message
    while read tobelogged
    do
        etsnow=$(date +%s)
        htsnow=$(echo $etsnow | awk '{print strftime("%c", $1, 1)}')
        echo -e $etsnow"\t" $htsnow "\t" $RUN_UUID "\t" $0 "\t" $tobelogged >> $logfile
    done
    }

#$basedir/parser.awk data_tsdb_storage/1702{12..13} > data_interim_storage/interim_pre_xlsx_170213

interimfile=$interimdir/interim_pre_xlsx
xlsxreadyfile=$interimdir/xlsx_ready
datesfile=$interimdir/xlsx_dates

$basedir/get_tiers.awk -F , $(file_list $1) > $referencedir/tiers

for file in $interimfile $xlsxreadyfile $datesfile; do
    if [ -e "$file" ]; then
        mv $file $file\_$ts
        gzip -9 $file\_$ts
    fi
done

fileappend="_"
fileappend+=$customer
fileappend+="_"
fileappend+=$rid
fileappend+="_"
fileappend+=$ds

echo $fileappend | logger

echo "Starting parser" | logger
$basedir/parser.awk \
        -v path=$referencedir \
        $(file_list $1) > \
        $basedir/data_interim_storage/interim_pre_xlsx | logger

echo "Starting post-parser" | logger
$basedir/post_parser.awk \
        $interimdir/interim_pre_xlsx > \
        $interimdir/xlsx_ready 2> \
        $interimdir/xlsx_dates

echo "Generating Excel file" | logger
excel_name=$($basedir/csv_to_xslx.py -c $basedir/xlsx_storage_config.yml -a $fileappend -s $interimdir -d $exceldir)
echo "Generated Excel file with name: $excel_name" | logger

##  Send to Slack
echo "Sending to Slack" | logger
slackcomment="Auto-posted by sch-rp01"
curl    -F initial_comment="$slackcomment" \
        -F file=@$excel_name \
        -F channels=#$slackchannel \
        -F token=$api_token \
        "https://slack.com/api/files.upload" | logger

