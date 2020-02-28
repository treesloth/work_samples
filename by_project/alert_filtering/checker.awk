#!/usr/bin/gawk -f

function counter( linenum )
    {
    ORS = " "
    bu = ""
    elapsed = systime() - starttime
    str = NR " lines collected in " elapsed " seconds"
    for (i = 1; i <= length(str) + 2; i++) {
        bu = "\b"bu
        }
    print bu > "/dev/stderr"
    print str > "/dev/stderr"
    ORS = OORS
    }

function pct( val1, val2 )
    {
    return 100 * (val1 / val2)
    }

BEGIN {
    PROCINFO["sorted_in"] = "@val_num_desc"

    if (type ~ /^agg$|^stickiest$/) {
        print > "successful_regeces"
    }
    close("successful_regeces")

    if (type != "agg" && type != "uncaught" && type != "stickiest") {
        print "Error:  Specify `-v type=\"agg\"` or '-v type=\"uncaught\"' or '-v type=\"stickiest\"'"
        doexit = "true"
        exit
        }

    starttime = systime()
    arrcount = 1000000

    if (regs == "") {
        regfile = "regeces"
        }
    else {
        regfile = regs
        }

	while (getline < regfile)
		{
        if ($0 !~ "^#") {
            reg = $0 "|" reg
            regarr[$0] = arrcount
            arrcount--
            }
		}

    sub(/\|$/, "", reg)
    FPAT = "([^,]*)|(\"[^\"]+\")"
    OORS = ORS
    }

NR > 1 {
    count++
    }

NR > 1 && $2 !~ reg && type == "uncaught" {
    print $2
    uncaught++
    }

int(NR / 250) == NR / 250 {
    counter(NR)
    }

type == "agg" {
    for (regex in regarr) {
        if ($2 ~ regex) {
            print 1000000 - regarr[regex] >> "successful_regeces"
            alerts[$3 " :: " regex]++
            break
            }
        }
    }

type == "stickiest" {
    for (regex in regarr) {
        if ($2 ~ regex) {
            print 1000000 - regarr[regex] + 1 >> "successful_regeces"
            regex_used[regex]++
            break
            }
        }
    }

END {
    if (type == "uncaught") {
        counter(NR)
        print "\n"pct(uncaught, count) "% of lines uncaught (" uncaught " of " count")" > "/dev/stderr"
        print "Run completed in " systime() - starttime " seconds" > "/dev/stderr"
        exit 0
        }

    if (doexit == "true") {
        exit 1
        }

    if (type == "stickiest") {
        counter(NR)
        print "Run completed in " systime() - starttime " seconds" > "/dev/stderr"

        for (reg in regex_used) {
            print regex_used[reg] " :: " reg
            }

         for (reg in regarr) {
             if (reg in regex_used == 0) {
                 print "Unused regex :: " reg
                 }
             }

        exit 0
        }
    print "\nProcessing collected data..." > "/dev/stderr"
    for (j in alerts) {
        print alerts[j] " :: " j
        }
    }
