#! /usr/bin/awk -f

function abs(v) {return v < 0 ? -v : v}
function corr(w) {return (w + abs(w)) / 2}

BEGIN {
        ##  First, some assignments that will make this a little more readable
        wrlat = "vm.perf.metric.get_virtualDisk.totalWriteLatency.millisecond.average"
        rdlat = "vm.perf.metric.get_virtualDisk.totalReadLatency.millisecond.average"
        wriops = "vm.perf.metric.get_virtualDisk.numberWriteAveraged.number.average"
        rdiops = "vm.perf.metric.get_virtualDisk.numberReadAveraged.number.average"
        ##  Print the header line for the output data
        print "date/time,host,write_lat,write_iops,read_lat,read_iops,latency,tier,target_ms"

        FS = " "
        while ("cat " path "/tiers" | getline)
            {
            tiers[$1] = $2
            }
        FS = ","
##  uncomment to verify that the tiers were properly read
#        for (i in tiers) {
#            print i " " tiers[i]
#            }

        sla_ms_array[0] = 10
        sla_ms_array[1] = 10
        sla_ms_array[2] = 20
        sla_ms_array[3] = 30
    }
  
##  Now the line-by-line processing of the file starts
    FNR == 1 {
        print "Starting " FILENAME > "/dev/stderr"
    }
  
    $1 == wrlat {wr_lat[$2 "," $6] = corr($3)}
    $1 == rdlat {rd_lat[$2 "," $6] = corr($3)}
    $1 == wriops {wr_iops[$2 "," $6] = corr($3)}
    $1 == rdiops {rd_iops[$2 "," $6] = corr($3)}

    {
        metcount[$2 "," $6]++
        idx[$2 "," $6]
##  Uncomment to verify that the tiers array can be accessed by the rest of the script properly
#        print $6 " " tiers[$6]
    }

END {
    for (i in idx) {
        split(i, timehost, ",") ; host = timehost[2]
        sla_ms = sla_ms_array[tiers[host]]
##  Uncomment to verify that the SLA value is properly called
#        print sla_ms
        if (metcount[i] != 4) {
#            print i " doesn't have enough vals"
            continue;
            }
        else if (wr_iops[i] + rd_iops[i] == 0) {
#            print i " isn't non-zero"
            out =       i "," \
                        wr_lat[i] "," wr_iops[i] "," \
                        rd_lat[i] "," rd_iops[i] "," \
                        0 "," \
                        tiers[host] "," sla_ms_array[tiers[host]];
            count++;
            }
        else {
            latency = (wr_lat[i] * wr_iops[i] + rd_lat[i] * rd_iops[i]) / (wr_iops[i] + rd_iops[i]);
            out =       i "," \
                        wr_lat[i] "," wr_iops[i] "," \
                        rd_lat[i] "," rd_iops[i] "," \
                        latency "," \
                        tiers[host] "," sla_ms_array[tiers[host]];
            (latency >= sla_ms) ? oversla++ : oversla += 0;
            count++;
            }
        print out | "sort -t , -k 2,2 -k 1,1n"
        }
    close(sort)
#    print count, oversla, 100 * (1 - oversla / count)
#    for (j in metcount) {
#        print j "\t" metcount[j]
#        }
    }
