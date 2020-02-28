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

if [ ! -e $basedir/lockfile/.lock ]; then       ##  If there's no lockfile...
    echo Starting run, creating lockfile | logger
    echo $RUN_UUID > $basedir/lockfile/.lock
    if [ -e $3 ]; then                          ##  If the supplied metricss file exists...
        echo $3 exists....
    ##  Produce a list of metrics that will be iterated over.
    #+  If the file given is `mets`:
    #+  Start by getting the current hour of the day.  Then return every line in the metrics file
    #+  that is even divisble by the current hour of the day.  The effect is that each metric is
    #+  evaluated and updated once a day.  There is a (+1) on the hour in the gawking because
    #+  there's no line zero, but there is an hour zero.
    #+  If the file is not `mets`:
    #+  Just spit out each line.  Isn't that easy?
        echo "metfile is $metfile"
        echo "metfile full path is $3"
        for met in $(gawk -v metfile=$metfile '
                         {LN = strftime("%H")} 
                         (NR+1)%24 == LN && metfile == "mets" {print} 
                         metfile != "mets" {print}' $3); do
            echo Starting $met | logger
            echo Starting $met

            ##  We want to be able to tell the script to use the full set of data, not a reduction.
            #+  So, we split on the comma.  Almost all metric lines have no comma, which simply 
            #+  causes the line to have a single field and the settype is null... nbd.

            arrLINE=(${met//,/ })
            met=${arrLINE[0]}
            settype=${arrLINE[1]}       ##  This is usually null and 'tagset.py' is used.
            echo $settype

            if [ "$settype" == "full" ]; then
		parser="fullset.py"     ##  Rarely used
            else
                parser="tagset.py"      ##  Usually used
            fi
            echo $parser

            ##  The command that will be sent to the MA server:
            remotecmd="/usr/share/opentsdb/bin/tsdb scan --import $1-ago avg $met"
            echo $remotecmd

            echo "SSH Command: " ssh -A -i $keyfile -tT root@10.131.151.161 $remotecmd | logger
            echo "Tag Command: " python $basedir/tagset.py --metric $met --stdin --$2 | logger

            ##  Get the data, send it to the parser, and save/zip it in the output directory 
            ssh -A -i $keyfile -tT root@10.131.151.161 $remotecmd | python $basedir/$parser \
                --metric $met --stdin --$2 > $outputdir/$met.$1.$2.$ts 2> >(cat | logger)
            gzip -9 $outputdir/$met.$1.$2.$ts   

            ##  Send the gzipped files to the storage server with the capacity to handle this
            rsync -avz --remove-source-files -e "ssh -i $keyfile" \
                $outputdir/$met.$1.$2.$ts\.gz \
                root@<IP_ADDRESS_HERE>:<full_path_on_storage_server>
            echo Rsync completed with status $? | logger
        
        done
    fi

    ##  If the file passed to the script was `newmets` then we need to get those new metrics into
    #+  the normal `mets` metrics file.  Here it goes...
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
