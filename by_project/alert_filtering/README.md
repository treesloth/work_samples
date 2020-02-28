# alert_grouping

Note that certain files contain the string <PROP>.  This indicates that something proprietary has been obfuscated.

###  About repo files
The following files are actually important:

**checker.rb**:  The processing script for this tool

**regeces**:  The default regex file.  This contains a list of the regexes that will be used to test alerts.  To use a non-default file, alter `['input_files']['regex_file']` in the config file.

**u_alerts_to_task.subset.csv**:  The default alerts file.  This can be helpful in testing.  To use a non-testing file, alter `['input_files']['alerts_file']` in the config file.

There are lots of other files, hopefully with reasonably intuitive names, that are not documented.


### Modes
This script provides 4 basic functions, described below.  The first 3 are support functions, to be used cleverly to set up and optimize the function of the process.  The last is the script's /raison d'être/.  Yeah, that's right.. French in a README file.

1. **stickiness**

Compares the alerts list to the provided regexes and returns an ordered list, one item per line, each consisting of a number and a regex.  The number is the count of times that the regex matched an alert.  Truncated example output:
```
625 :: (?-mix:Connection problems occured on the system .*? with connector .*? : .*?)
352 :: (?-mix:A log backup with ID [0-9]* has been running for longer than [0-9]* seconds\. \(Hana alert\))
330 :: (?-mix:Syslog match \[.*? : Operating system call recv failed \(error no. [0-9]{1,3} \)\] \[.*?\])
240 :: (?-mix:System .* is not reachable with connector .*?)
141 :: (?-mix:[0-9]{1,3}% of busy work processes \(>=[0-9]{1,3}%\) on \[.*?\] Type \[DIALOG\])
86 :: (?-mix:.* since last LOG successfull backup (.*))
... and so on
```
2.  **overlaps**
Compares the alerts list to the provided and returns a list of all alerts that match more than one regex, as well as the matched regexes.  This is used to determine if the regexes are sufficiently unique or are overly broad.  Naturally, each alert should match a single regex.
3.  **uncaught**
Returns a list, one alert per line, of alerts that match no regex.  Reviewing this list should offer insights into what new regexes may be of use.  A large number of similar uncaught alerts suggests the need for an additional regex.
4.  **host_aggregate**
For each host and regex pair, returns the number of times that a particular regex matches for the given host.  Truncated example output:
```
5038 :: "PCR_10.139.250.15" :: Syslog match \[.*? : Operating system call recv failed \(error no. [0-9]{1,3} \)\] \[.*?\]
1464 :: "DNB_10.12.148.170" :: Connection problems occured on the system .*? with connector .*? : .*?
772 :: "BD2_10.17.20.243" :: Connection problems occured on the system .*? with connector .*? : .*?
547 :: "PLT_172.28.227.60" :: [0-9]{1,3}% of busy work processes \(>=[0-9]{1,3}%\) on \[.*?\] Type \[DIALOG\]
541 :: "ECP_172.28.227.14" :: [0-9]{1,3}% of busy work processes \(>=[0-9]{1,3}%\) on \[.*?\] Type \[DIALOG\]
520 :: "SHP_10.16.6.86" :: The rate of enqueue requests is currently [0-9]*\.[0-9]*\. The threshold is [0-9]*.*?
```
So, the host `PCR_10.139.250.15` had 5038 alerts that matched the regex:
```
Syslog match \[.*? : Operating system call recv failed \(error no. [0-9]{1,3} \)\] \[.*?\]
```

The output file for a mode's run is determined by the config file.  It is `['modes'][<mode>]['output_file']` appended to `output_`.  Hence, for example, the "stickiness" mode run will produce a file called "output_stickness"

###  Now, a token howto:
**Syntax**:  `./checker.rb <runmode> <config_file>`

The 4 run modes are documented above.  At present the output to file is not coded.  A full test against the default full test files can be run with the shell command:
```
for mode in "stickiness" "overlaps" "uncaught" "host_aggregate"; do echo -e "\n\n"; ./checker.rb $mode config.test.full.yml; done
```
