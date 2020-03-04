#!/usr/bin/env bash

http_proxy=""

basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"     #  The location of this script
logdir=$basedir/logs;                       	mkdir -p $logdir
referencedir=$basedir/data_reference;       	mkdir -p $referencedir
interimdir=$basedir/data_interim_storage;   	mkdir -p $interimdir
tsdb_datadir=$basedir/data_tsdb__storage;       mkdir -p $tsdb_datadir
exceldir=$basedir/data_storage_excel;       	mkdir -p $exceldir

ts=$(date +%y%m%d_%H%M%S)

api_token=$(cat /root/scripts/workspace/slackapi/slack_api_token)

source $basedir/config_storage.sh


##  A function to generate the last $1 days' list of files
file_list () {

    prelist=""
    dlist=""

    if [ "$1" == "mtd" ]; then
        prelist=$(ls $tsdb_datadir/$(date +%y%m)*)
    elif [ "$1" == "lm" ]; then
        prelist=$(ls $tsdb_datadir/$(date +%y%m -d "1 month ago")*)
    elif [[ $1 =~ .ma ]]; then
        re='^[0-9]+$'
        months=${1/ma/}
        if [[ $months =~ $re ]]; then
            prelist=$(ls $tsdb_datadir/$(date +%y%m -d "$months month ago")*)
        else
            echo None, because $months is not a number.  Invalid option.  Exiting.
            exit 1
        fi
    else
        cutoff=$(($1+1))
        counter=1
        until [ $counter -eq $cutoff ]; do
            prelist+=$tsdb_datadir/$(date +%y%m%d -d "$counter days ago")" "
            let counter=$counter+1
        done
    fi

    for file in ${prelist[@]}; do
#        if [ -e $file ]; then
        if [ -f $file ]; then
            dlist+=" "$file
        fi
    done

    echo $dlist
    }


start_end () {
    filelist=($(file_list $1))
    start=${filelist[0]}
    end=${filelist[-1]}
    echo "${start##*/}_${end##*/}"
    }


user_hak () {
    if [ "$1" == "hak" ]; then
        read -n 1 -s -r -p "Press any key to continue "
        echo ""
    fi
    }


interimfile=$interimdir/interim_pre_xlsx
xlsxreadyfile=$interimdir/xlsx_ready
datesfile=$interimdir/xlsx_dates

for file in $interimfile $xlsxreadyfile $datesfile; do
    if [ -e "$file" ]; then
        mv $file $file\_$ts
        gzip -9 $file\_$ts
    fi
done

filelist=$(file_list $1)
if [[ $1 =~ .ma ]]; then
    filearray=($filelist)
    firstfile="${filearray[0]}";    lastfile="${filearray[-1]}"
    firstdate="${firstfile##*/}";   lastdate="${lastfile##*/}"
    ds=$firstdate
    ds+="_to_"
    ds+=$lastdate
else
    ds=$(date +%y%m%d)
fi

fileappend="_"
fileappend+=$rid
fileappend+="_"
fileappend+=$(start_end $1)


echo "Starting parsing"
echo $basedir/parser.awk -v basedir=$basedir $filelist
exit
$basedir/parser.awk -v basedir=$basedir $filelist > $basedir/data_interim_storage/interim_pre_xlsx
$basedir/post_parser.awk $interimdir/interim_pre_xlsx > $interimdir/xlsx_ready 2> $interimdir/xlsx_dates
excel_name=$($basedir/csv_to_xslx.py -c $basedir/xlsx_storage_config.yml -a $fileappend -s $interimdir -d $exceldir)

echo $interimdir
echo $exceldir

user_hak $2

##  Send to Slack
export https_proxy="<PROXY_HERE>"
slackcomment="Auto-posted by sch-rp01"
curl    -F initial_comment="$slackcomment" \
        -F file=@$excel_name \
        -F channels=$slackchannel \
        -F token=$api_token \
        "https://slack.com/api/files.upload"
echo
