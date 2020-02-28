#ssh -A -tT root@10.131.149.141

basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"     #  The location of this script
keyfile=$basedir/support_files/keyfile

##  $1 :  The timespan (5m, 2h, etc)
##  $2 :  The output format
##  $3 :  The file with a list of metrics to send
##  Ex:  bash runner.sh datastore.perf.metric.get_disk.total.kiloBytesPerSecond.average 1h telnet

timespan=$1
outputdir=$basedir/data
ts=$(date +%y%m%d_%H%M%S)
metfile=$(basename $3)
RUN_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fds=$(date -d "00:00:00" +%Y%U)
logdir=$basedir/logs;                      mkdir -p $logdir
logfile=$logdir/log_$fds




logger () {
      # Log a time- and UUID-stamped piped message
      while read tobelogged
      do
        etsnow=$(date +%s)
        htsnow=$(echo $etsnow | awk '{print strftime("%c", $1, 1)}')
        echo -e $etsnow" "$htsnow" "$RUN_UUID" "$config_file" "$tobelogged >> $logfile
    done
    }

delete_lockfile () {
    ##  Does exactly what it says on the tin...
    if [ -e $basedir/lockfile/.lock ]; then
        rm $basedir/lockfile/.lock
        echo Delete lockfile completed with status $? | logger
    fi
   }


## gawk '{LN = strftime("%H")} NR%24 == LN' mets

echo Starting...

if [ ! -e $basedir/lockfile/.lock ]; then
    echo Starting run, creating lockfile | logger
    echo $RUN_UUID > $basedir/lockfile/.lock
    if [ -e $3 ]; then
        echo $3 exists....
    #    for met in $(cat $3); do
        for met in $(gawk -v metfile=$metfile '
                         {LN = strftime("%H") + 1} 
                         NR%24 == LN && metfile == "mets" {print} 
                         metfile != "mets" {print}' $3); do
            echo Starting $met | logger
            echo Starting $met

            arrLINE=(${met//,/ })
            met=${arrLINE[0]}
            settype=${arrLINE[1]}
            echo $settype

            if [ "$settype" == "full" ]; then
		parser="fullset.py"
            else
                parser="tagset.py"
            fi
            echo $parser

            remotecmd="/usr/share/opentsdb/bin/tsdb scan --import $1-ago avg $met"
            echo $remotecmd

            echo "SSH Command: " ssh -A -i $keyfile -tT root@10.131.151.161 $remotecmd | logger
            echo "Tag Command: " python $basedir/tagset.py --metric $met --stdin --$2 | logger

            
            ssh -A -i $keyfile -tT root@10.131.151.161 $remotecmd | python $basedir/$parser --metric $met --stdin --$2 > $outputdir/$met.$1.$2.$ts 2> >(cat | logger)
            gzip -9 $outputdir/$met.$1.$2.$ts
        
            rsync -avz --remove-source-files -e "ssh -i $keyfile" \
                $outputdir/$met.$1.$2.$ts\.gz \
                root@10.131.149.35:/root/scripts/workspace/grafana/vec_templating_putfiles/
            echo Rsync completed with status $? | logger
        
        done
    fi
    
    if [ "$metfile" == "newmets" ]; then
        if [ -e "$3" ]; then
        	cat $3 >> $basedir/mets
            rm $3
        else
            echo Specifed file does not exist.  Nothing to do.
	    delete_lockfile
            exit 1
        fi
    fi

    delete_lockfile

fi
