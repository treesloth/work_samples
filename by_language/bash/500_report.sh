#!/usr/bin/env bash

##  Available metrics:
#+  syn_sla_calc
#+  syn_fail_calc
#+  syn_success_calc
#+  syn_total_calc
#+  And each has a "raw" instead of "calc" version as well

basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"     #  The location of this script
logdir=$basedir/logs ;              mkdir -p $logdir
workingdir=$basedir/workfiles ;     mkdir -p $workingdir
oldruns=$basedir/archive_oldruns ;  mkdir -p $oldruns
oldexcel=$basedir/archive_excel ;   mkdir -p $oldexcel
mtddir=$basedir/mtdfiles ;          mkdir -p $mtddir
mtdfilelist=$basedir/mtdfilelist ;  touch $mtdfilelist
fds=$(date -d "00:00:00" +%Y%U)     ## Year and week number.  Ex:  201448, the 48th week of 2014
ts=$(date +%s)                      ## Epoch timestamp
logfile=$logdir/availability_sla_log_$fds
baseurl="https://tsdb.<tsdb_base_url>"
period=$1                           ## Daily or monthly
maillist=$basedir/addrReal.list

##  A 'b'ack'd'oor offset to allow queries on other days.  Just add something like:
#+  bdoffset=14
#+  into the file $basedir/bdoffset

if [ -e $basedir/bdoffset ]; then
    source $basedir/bdoffset
else
    bdoffset=0
fi

startoffset=$(($bdoffset+1))
endoffset=$(($bdoffset))

#echo $startoffset $endoffset
dayStart=$(date +"%Y/%m/%d-%H:%M:%S" -d "00:00:00 $startoffset day ago")    #* SoM, yyyy/mm/dd-hh:mm:ss
dayEnd=$(date +"%Y/%m/%d-%H:%M:%S" -d "00:00:00 $endoffset day ago")        #* MTDy, yyyy/mm/dd-hh:mm:ss
emailDate=$(date +"%Y/%m/%d" -d "00:00:00 $startoffset day ago")            #* SoD, yyyy/mm/dd
excelDayStart=$(date +"%Y%m%d.%H" -d "00:00:00 $startoffset day ago")    #* SoM, yyyymmddhhmmss
excelDayEnd=$(date +"%Y%m%d.%H" -d "00:00:00 $endoffset day ago")        #* MTDy, yyyymmddhhmmss
fileTestDate=$(date +"%Y%m%d" -d "00:00:00 $startoffset day ago")
lastMonthStart=$(date -ud "$(echo $(date +"%Y-%m-01 00:00:00") 1 month ago)" +"%Y/%m/%d-%H:%M:%S")
lastMonthEnd=$(date -ud "$(echo $(date +"%Y-%m-01 00:00:00") 1 second ago)" +"%Y/%m/%d-%H:%M:%S")
filenameDateStamp=$(date +"%Y%m%d" -d "00:00:00 $startoffset day ago")
todayDayNum=$(date +"%d" -d "00:00:00 $startoffset day ago")
noargs=0

if [ "$todayDayNum" == "01" ]
then
    shortFilenameDateStamp=$(date +"%Y%m" -d "00:00:00 $startoffset day ago - 1 day")
else
    shortFilenameDateStamp=$(date +"%Y%m" -d "00:00:00 $startoffset day ago")
fi
    


excelFileName=$filenameDateStamp
    excelFileName+="__beatle500Report.xls"

dfilename=$mtddir
    dfilename+="/"
    dfilename+=$filenameDateStamp

##  START Some nice functions!  ##
logger () {
    while read tobelogged
    do
        etsnow=$(date +%s)
        htsnow=$(echo $etsnow | awk '{print strftime("%c", $1, 1)}')
        echo -e $etsnow"\t" $htsnow "\t" $tobelogged >> $logfile
    done
    }

callProcessSave () {
    #      $1 <-> The name of the output file that temporarily stores the curl data
    #      $2 <-> The URL that will be queried
    #      Build the csv files that will become the worksheets of the xls

    ##  This part is so freakishly complicated because the Metrics Archive does
    #+  not currently produce a consistent (or, at least, convenient) field order.
    #+  So, the first part strips out odd formatting in the header and passes along
    #+  to the send part.  The second then (1) figures out which field contains 500
    #+  data and which contain the tx count metrics, and then (2) uses that to find
    #+  the counts and sums.

        echo "Time,50x Errors,Total Tx,Pass Rate (%)" > $1.csv
#        if [ "$period" == "daily" ]; then
#            echo Starting curl
            curl --noproxy emcrubicon.com -sk $2  |\
                dos2unix |\
                sed 's/,,/,0,/g'|\
                awk -F , '
                    NR == 1 {
                        gsub(/\{[^}]*\}/,"",$0);
                        gsub("\"", "", $0);
                        print
                        }
                    NR >= 2 {
                        print
                        }' |\
                awk -F , '
                    NR == 1 {
                        inc = 1
                        for (i = 1 ; i <= 5 ; i++)
                            {
                            if ($i ~ "_500_errors")
                                {
                                errors = i
                                }
                            if ($i ~ "cb.req.count")
                                {
                                http[inc] = i
                                inc++
                                }
                            }
                        }
                    NR > 1  {
                        txcount = $http[1] + $http[2] + $http[3] + 0
                        if (txcount == 0)
                            {
                            txcount = 1
                            $errors = 0
                            }
                        passpct = 100 * (1 - ($errors / txcount))
                        print $1 "," $errors + 0 "," txcount "," passpct
                        }' &>> $1.csv
    }

buildHeader () {
    #   Build the header that will be included on each page of the spreadsheet.
    echo Deleting old header, building new file. | logger
    echo "Report Period:" > $workingdir/$1.header
    echo $headerDayStart" + "$headInterval >> $workingdir/$1.header
    echo Locale: $1 >> $workingdir/$1.header
    echo Done building header with values $headerDayStart and $1
    }
##  END  ##


##  START Preserve old runs...  ##
if [ "$(ls -A $workingdir)" ]; then
    tar --transform "s,^./,$ts/,S" -c -zf $oldruns/$ts.tar.gz -C $workingdir .
    echo Tarred old run files into $ts.tar.gz
    rm -rf $workingdir/*
else
    echo No old files found.  Moving on...
fi | logger
##  END  ##

##  START Make sure we can output today's MTD-helping file  ##
if [ -e $dfilename ]; then
    rm -f $dfilename
fi

echo Starting run | logger

if [ ! -s $basedir/locales ]; then
    echo Locales file does not exist.  Creating. | logger
    $basedir/genlocales.sh | logger
fi

nalign=300
qStart=$dayStart
qEnd=$dayEnd
valagg="zimsum"
headerDayStart=$(date +"%Y/%m/%d" -d "00:00:00 $startoffset day ago")
headInterval="24 hours"

if [ "$1" == "showdates" ]; then
    echo $qStart $qEnd
    echo $filenameDateStamp $shortFilenameDateStamp
    echo $dfilename
    exit
fi

for locale in $(cat $basedir/locales); do
    buildHeader $locale

    metric=$locale
        metric+="_500_errors"

    churl="$baseurl/archive/tsdb/query2x?"
        churl+="start=$qStart&end=$qEnd"
        churl+="&m=$valagg:$metric"
        churl+="&m=$valagg:cb.req.count%7blocation=$locale,http_request=GET|POST|DELETE%7d"
#        churl+="&ftype=csv&trans=norm&nalign=300&dtype=%25Y%25m%25d.%25H:%25M&utc=true"
        churl+="&ftype=csv&trans=norm&nalign=(300,%22sum%22)&dtype=%25Y%25m%25d.%25H:%25M&utc=true"

    echo $workingdir/$locale will contain the query $churl
    callProcessSave $workingdir/$locale $churl # &&\
done | logger

echo Creating $workingdir/subTotals.tcsv | logger

for line in $(cat $basedir/cloudpairs); do
    cloud=$(echo $line | cut -d \| -f 1)
    members=$(echo $line | cut -d \| -f 2)
    echo "Cloud: "$cloud","
    for member in $(echo $members | sed 's/,/ /g'); do
        echo -n $member","
        awk -F , -v dfilename=$dfilename -v member=$member '
            BEGIN {
                OFS = ","
                }
            NR > 1 {
                fiftyxcount += $2
                txcount += $3
                passsum += $4
                linecount++
                }
            END {
            f_txcount = sprintf("%.2f", txcount)
            f_fiftyxcount = sprintf("%.2f", fiftyxcount)
            print member, fiftyxcount, f_txcount, passsum / linecount >> dfilename
            close(dfilename)
            print fiftyxcount, f_txcount, passsum / linecount
            }' $workingdir/$member.csv
    done
    echo
done > $workingdir/subTotals.tcsv

##  This next part reads daily files for the month and calculates the mtd values.
#+  Format of read files:
#+  ex:  alln01,202981,333770091.00,99.9383
#+  host,500_txns,total_txns,%_passed

shortFilenameDateStamp=$(date +"%Y%m" -d "00:00:00 $startoffset day ago")
cp /dev/null $mtdfilelist
for file in $mtddir/$shortFilenameDateStamp*; do
    fdate=$(echo $file | awk -F "/" '{print $NF}')
    echo Is $fileTestDate -ge $fdate        ##  DIAG
    if [ $fileTestDate -ge $fdate ]; then
        echo $fileTestDate -ge $fdate -- $file
        echo $file >> $mtdfilelist
    fi
done | logger

cat $mtdfilelist

awk -F , -v basedir=$basedir '
    BEGIN {
        OFS = ","
        }
        {
        count500[$1] += $2
        countTotal[$1] += $3
        sumPct[$1] += $4
        countDays[$1] ++
        }
    FNR == 1 {
        dest = basedir "/MTDFileListAwkYo"
        print FILENAME >> dest
        close(dest)
       }
    END {
        for (i in countDays)
            {
            f_count500 = sprintf("%.0f", count500[i])
            f_countTotal = sprintf("%.0f", countTotal[i])
            print i, f_count500, f_countTotal, sumPct[i] / countDays[i]
            }
        }
' `cat $mtdfilelist` > $workingdir/mtdTotals.tcsv

awk -F , -v mtdt=$workingdir/mtdTotals.tcsv '
    BEGIN   {
        while ("cat " mtdt | getline)
            {
            mtd[$1] = $2 "," $3 "," $4
            }
        }
        {
        locale = $1
        if (mtd[locale] != "")
            {
            print $0 "," mtd[locale]
            }
        if (mtd[locale] == "")
            {
            print $0
            }
        }' $workingdir/subTotals.tcsv > $workingdir/Totals.tcsv

##  END  ##

##  Now, if there happens to be an Excel report in basedir, or if the filename we want to move
#+  an archived copy to is in use, we deal with it:

if [ -e $basedir/$excelFileName ]; then
    mv $basedir/$excelFileName $archive_oldruns/$ts.$excelFileName
fi

if [ -e $oldexcel/$excelDayStart\_$excelDayEnd\_$excelFileName ]; then
        mv $oldexcel/$excelDayStart\_$excelDayEnd\_$excelFileName \
	    $oldexcel/$ts\_$excelDayStart\_$excelDayEnd\_$excelFileName
fi

##  Now, create the Excel doc based on this run:
echo Creating the file $basedir/$excelFileName | logger
$basedir/xlsformatreport.py $basedir $excelFileName | logger
if [ -e $basedir/$excelFileName ]; then
    echo File exists
        echo $basedir/$excelFileName
        /root/scripts/general/sendfile.py \
            -a $basedir/$excelFileName \
            -d $(cat $maillist) \
            -s "Daily Beatle 50x Report: $emailDate"
    mv $basedir/$excelFileName $oldexcel/$excelDayStart\_$excelDayEnd\_$excelFileName
    echo $excelDayStart\_$excelDayEnd\_$excelFileName
else
    echo Report not found.
fi | logger
