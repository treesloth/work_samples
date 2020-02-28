#! /usr/bin/awk -f

##  Input field information:
#++++++++++++++++++++++++++++++++++++++++++++
#+      1   date/time         1485926372
#+      2   host              A0G4US0360CG200
#+      3   write_lat         1
#+      4   write_iops        2
#+      5   read_lat          0
#+      6   read_iops         0
#+      7   latency           1
#+      8   tier              0
#+      9   target_ms         5
#++++++++++++++++++++++++++++++++++++++++++++

BEGIN {
        FS = ",";
        OFS = ",";
#        sla_ms_array[0] = 5;
        sla_ms_array[0] = 10;
        sla_ms_array[1] = 10;
        sla_ms_array[2] = 20;
        sla_ms_array[3] = 30;
    }
  
##  Now the line-by-line processing of the file starts

    ##  Make an array of datastores
    NR > 1 {ds[$2]}

    ##  Track the tiers
    NR > 1 {tier[$2] = $8}

    ##  Save the min/mean/max latency per datastore
    ##  In all cases, `nz` refers to `n`on-`z`ero datapoints (those with traffic)
    #+  Track the min...  REQ 1, 2
    NR > 1 && ($2 in min) && ($7 < min[$2]) {min[$2] = $7}
    NR > 1 && !($2 in min) {min[$2] = $7}

    #+  Track the non-zero min... REQ 2, 3
    NR > 1 && !($2 in nz_min) && ($4 > 0 || $6 > 0) {nz_min[$2] = $7}
    NR > 1 && ($2 in nz_min) && ($7 < nz_min[$2]) && ($4 > 0 || $6 > 0) {nz_min[$2] = $7}

    #+  Track the max... REQ 2
    NR > 1 && !($2 in max) {max[$2] = $7} 
    NR > 1 && ($2 in max) && ($7 > max[$2]) {max[$2] = $7}

    #+  Track the non-zero max... REQ 2, 3
    NR > 1 && !($2 in nz_max) && ($4 > 0 || $6 > 0) {nz_max[$2] = $7}
    NR > 1 && ($2 in nz_max) && ($7 > nz_max[$2]) && ($4 > 0 || $6 > 0) {nz_max[$2] = $7}

    #+  Track the count and sum of latencies... REQ 2
    NR > 1 {count[$2]++ ; latency_sum[$2] += $7}

    #+  Count of latencies below SLA... REQ 4
    NR > 1 && $7 < $9 {below_sla[$2]++}
    NR > 1 && $7 < $9 && ($4 > 0 || $6 > 0) {nz_below_sla[$2]++}

    #+  Track count and sum of latencies only for dp's with traffic... REQ 3
    #+  nz -- non-zero
    NR > 1 && ($4 > 0 || $6 > 0) {nz_count[$2]++ ; nz_latency_sum[$2] += $7}

END {
    ##  The following are available:
    #+
    #+      min             nz_min
    #+      max             nz_max
    #+      count           nz_count
    #+      latency_sum     nz_latency_sum
    #+      below_sla       nz_below_sla

    print "Datastore,Tier,Min,NZ_Min,Mean,NZ_Mean,Max,NZ_Max,#_Data_Periods,#_Below_SLA,%_Below_SLA,#_NZ_Data_Periods,#_NZ_Below_SLA,%_NZ_Below_SLA"
    for (d in ds) {

        mean =          (count[d] > 0) ? (latency_sum[d] / count[d]) : 0
        nz_mean =       (nz_count[d] > 0) ? (nz_latency_sum[d] / nz_count[d]) : 0
        pct_below =     (count[d] > 0) ? (below_sla[d] / count[d]) : 0
        nz_pct_below =  (nz_count[d] > 0) ? (nz_below_sla[d] / nz_count[d]) : 0

        print   d, tier[d] + 0, \
                min[d] + 0, nz_min[d] + 0, \
                mean + 0, nz_mean + 0, \
                max[d] + 0, nz_max[d] + 0, \
                count[d] + 0, below_sla[d] + 0, pct_below + 0, \
                nz_count[d] + 0, nz_below_sla[d] + 0, nz_pct_below | "sort"
        }
    close(sort)
    h_start = strftime("%d%b%y,%l%p", mindate)
    h_end = strftime("%d%b%y,%l%p", maxdate)
    print "Start," h_start "\nEnd," h_end > "/dev/stderr"
    }
