#!/usr/bin/python

import re
import sys
import argparse

##  A test dataset command:
#+  met="ifInOctets"; /usr/share/opentsdb/bin/tsdb scan --import 5m-ago avg $met

def parse_arguments( sysargs ):
    """
    Provide a nice way of parsing arguments
    """

    desc='Get SN data and calculate percentiles'
    h_stdin = 'Get the data for last year'
    h_file = 'Get the data for last week'
    h_metric = 'The metric to search for in the returned data'
    h_yaml = 'Use an output format suitable for the putter.rb utiity'
    h_telnet = 'Use an output format suitable for piping directly to a telnet connection'
    h_tcollector = 'Use an output format suitable for use by tcollector'

    parser = argparse.ArgumentParser(description=desc)

    me_source = parser.add_mutually_exclusive_group(required=True)
    me_source.add_argument('--stdin', action='store_true', help=h_stdin)
    me_source.add_argument('--file', help=h_file)

    parser.add_argument('--metric', help=h_metric)

    me_output = parser.add_mutually_exclusive_group(required=True)
    me_output.add_argument('--yaml', action='store_true', help=h_yaml)
    me_output.add_argument('--telnet', action='store_true', help=h_telnet)
    me_output.add_argument('--tcollector', action='store_true', help=h_tcollector)

    args = parser.parse_args()
    return args

args = parse_arguments(sysargs=sys.argv[1:])

##  A useful line:
#+  gawk --posix '$1 == "icmppingloss" && $2 ~ /^[0-9]{10}$/' pingloss

if args.stdin:
    content = sys.stdin
else:
    with open(args.file, 'r') as fp:
        content = fp.readlines()

content = [x.strip() for x in content]
listoftaglists = []
datestamp = 999999999999
value = "123456789.987654321"

for line in content:
    linelist = line.split()
    linetagset = []

    if  (
        ##  The second field is an epoch timestamp - 10 digits.  That should work until 2033
        re.match("^(\d{10})$", linelist[1]) and
        ##  The first field is the metric name
        linelist[0] == args.metric and
        ##  The third digit is any number (+/-, dec or int)
        re.match("[+-]?\d+(?:\.\d+)?", linelist[2])
        ):
        datestamp = min(datestamp, int(linelist[1]))
        for i in range(3, len(linelist)):
            linetagset.append(linelist[i])
        linetagset = sorted(linetagset)
        listoftaglists.append(' '.join(linetagset))

uniqtaglists = set(listoftaglists)
setsize=len(uniqtaglists)
sizemsg = args.metric + ' contains ' + str(setsize) + ' datapoints\n'
sys.stderr.write(sizemsg)

if args.yaml:
    print "puts:"
    for linenum, taglist in enumerate(uniqtaglists):
        putline =   "    put" \
                    + str(linenum) \
                    + ": \"" \
                    + 'template.xfer.' + args.metric \
                    + " " \
                    + str(datestamp) \
                    + " " \
                    + value \
                    + " " \
                    + taglist \
                    + "\""
        print putline

elif args.telnet:
    for linenum, taglist in enumerate(uniqtaglists):
        putline =   'put' \
                    + ' template.xfer.' + args.metric \
                    + " " \
                    + str(datestamp) \
                    + " " \
                    + value \
                    + " " \
                    + taglist
        print putline

elif args.tcollector:
    for linenum, taglist in enumerate(uniqtaglists):
        putline =   ' template.xfer.' + args.metric \
                    + " " \
                    + str(datestamp) \
                    + " " \
                    + value \
                    + " " \
                    + taglist
        print putline

