#! /usr/bin/awk -f

##  Now the line-by-line processing of the file starts
    {
        tier[$6] = $7
    }
  
END {
    for (i in tier) {
        print i " " tier[i]
        }
    }
