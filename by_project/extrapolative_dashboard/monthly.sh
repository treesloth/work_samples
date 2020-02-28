#!/usr/bin/env bash

http_proxy=

month_start=$(date +%Y/%m)"/01-00:00:00"
days_in_month=$(date +%d -d "$(date +%Y-%m-01 -d "+1 month") -1 day")
#echo $days_in_month

##  Sample line:
#/root/scripts/financial_dashboard/financial_dash.py -m 2016/03/01-00:00:00 -p 30 -f eomproj -r mtdreal -a mtdmeter -b eommeter

/root/scripts/financial_dashboard/financial_dash.py \
    -m $month_start \
    -p $days_in_month \
    -f eomproj \
    -r mtdreal \
    -a mtdmeter \
    -b eommeter 2> /dev/null
