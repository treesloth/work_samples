#!/usr/bin/env bash

http_proxy=
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 

## A test for the calculations used
#for month in Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec; do
#    curr_quarter_number=$(($((10#$(date -d "$month 01" +%-m)-1))/3))
#    curr_quarter_start_month="0"$((10#$curr_quarter_number*3+1))
#    start_of_curr_quarter=$(date +%Y)/${curr_quarter_start_month:(-2)}"/01-00:00:00"
#    e_start_of_curr_quarter=$(date +%s -d "${start_of_curr_quarter/'-00:00:00'/}")
#    e_end_of_curr_quarter=$(date +%s -d "${start_of_curr_quarter/'-00:00:00'/} +3 months -1 day")
#    echo    $curr_quarter_number \
#            $curr_quarter_start_month \
#            $month $start_of_curr_quarter \
#            $e_end_of_curr_quarter \
#            $e_start_of_curr_quarter \
#            $(($(($e_end_of_curr_quarter-$e_start_of_curr_quarter))/86400))
#done
#exit

curr_quarter_number=$(($((10#$(date +%-m)-1))/3))
curr_quarter_start_month="0"$((10#$curr_quarter_number*3+1))
curr_quarter_start_month=${curr_quarter_start_month:(-2)}
start_of_curr_quarter=$(date +%Y)/${curr_quarter_start_month:(-2)}"/01-00:00:00"
e_start_of_curr_quarter=$(date +%s -d "${start_of_curr_quarter/'-00:00:00'/}")
e_end_of_curr_quarter=$(date +%s -d "${start_of_curr_quarter/'-00:00:00'/} +3 months -1 day")
days_in_quarter=$(($(($e_end_of_curr_quarter-$e_start_of_curr_quarter))/86400+1))

#echo $start_of_curr_quarter
/root/scripts/financial_dashboard/financial_dash.py \
    -m $start_of_curr_quarter \
    -p $days_in_quarter \
    -f eoqproj \
    -r qtdreal 2> /dev/null


curl -k -d '{ "auth_token":"moarfl@vorplz", "text":"Note:  All values are valid until Oct 31." }'  https://glass02.monilytics.net/widgets/caveats
