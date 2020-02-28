#!/usr/bin/env ruby
##  This is intended to be a reimplimentation of the checker.awk file in Ruby

##  Features missing:
#+  1:  DONE::  A decent spinner to tell the user how far along the job is (in progress)
#+  2:  Better command line optioning
#+  3:  A data structure that can handle all of these tasks concurrently.  It seems like there ought
#+      to be one that can address all 4 job types in one.  They're not *that* different...

require 'fileutils'
require 'optparse'
require 'yaml'

old_sync = $stdout.sync    ##  Just in case...
$stdout.sync = true
$stderr.sync = true
$start_time = Time.now.to_i


####################################################################################################
####  Start defs
####################################################################################################

def spinner(num, of_num)

    msg = num + " of " + of_num.to_s + " lines processed in " + (Time.now.to_i - $start_time).to_s + " seconds"
    $stderr.print "\b" * msg.length
    $stderr.print msg

end


def stickiness(alert_data, regeces)

    ##  Determine which regex is stickiest--  that is, which one catches the most alerts.  This is
    #+  useful, among other things, for ordering the regex file as efficiently as possible

    sticky_count = Hash.new(0)
    processed_count = 0.0
    alert_data.each_with_index do |alert_line, alert_line_idx|
        processed_count += 1
        next if alert_line_idx == 0
        alert_line_array = alert_line.split("\",\"")
        ##  Adding in the index so we can do some analysis later on how far, on average,
        #+  the loop has to go to find a match.  We want to minimize that, of course.
        #+  Not yet used otherwise...
        regeces.each_with_index do |regex, regex_idx|
            if alert_line_array[1] =~ /#{regex}/ 
                sticky_count[regex] = sticky_count[regex] + 1
                break
            end
        end

        if (processed_count / 250).to_i == (processed_count / 250)
            spinner(processed_count.to_i.to_s, $alerts_count)
        end

    end

    msg = $alerts_count.to_s + " of " + $alerts_count.to_s + " lines processed"
    $stderr.print "\b" * msg.length * 2

    return sticky_count
end


def overlaps(alert_data, regeces)

    ##  So, this takes a long time.  It compares every alert to every regex and determines if any regex
    #+  is triggered more than once.  It returns any alert that is multiplly-triggered and the matching
    #+  regeces

    processed_count = 0.0 
    overlap_hash = Hash.new
    alert_data.each_with_index do |alert_line, alert_line_idx|
        processed_count += 1
        next if alert_line_idx == 0
        alert_line_array = alert_line.split("\",\"")
        overlap_hash[alert_line_array[1]] = Array.new
        regeces.each do |regex|
            if alert_line_array[1] =~ /#{regex}/
                overlap_hash[alert_line_array[1]] << regex
            end

            if (processed_count / 250).to_i == (processed_count / 250)
                spinner(processed_count.to_i.to_s, $alerts_count)
            end
        end
    end

    msg = $alerts_count.to_s + " of " + $alerts_count.to_s + " lines processed"
    $stderr.print "\b" * msg.length * 2

    return overlap_hash

end    


def uncaught(alert_data, regeces)
    
    ##  Return any lines which are matched by no regex

    ##  This part should be rewritten to use a single joined regex-- a union of all regexes on the list
    #+  At least, that was a lot faster on the awk version.

    processed_count = 0.0
    uncaught_arr = []
    alert_data.each_with_index do |alert_line, alert_line_idx|
        is_matched = 0
        processed_count += 1
        next if alert_line_idx == 0
        alert_line_array = alert_line.split("\",\"")

        regeces.each do |regex|
            if alert_line_array[1] =~ /#{regex}/
                is_matched = 1
                break
            end
        end

        if (processed_count / 250).to_i == (processed_count / 250)
            spinner(processed_count.to_i.to_s, $alerts_count)
        end

        if is_matched == 0
            uncaught_arr << alert_line_array[1]
        end
    end

    return uncaught_arr.uniq
end


def host_aggregate(alert_data, regeces)

    ##  Determine how many times a regex matches an alert on a particular host
    #+  Returns a hash which has a " :: "-separated concatenation of host and regex as its index and
    #+  a count of the nunber of times that regex is applied to that host as the value.
    #+  This is sort of what this report is for, afaik.  All other functions are to support this one.

    processed_count = 0.0
    host_regex_arr = Hash.new(0)
    alert_data.each do |alert_line|
        processed_count += 1
        alert_line_array = alert_line.split("\",\"")
        regeces.each do |regex|
            if alert_line_array[1] =~ /#{regex}/
                ##  Index is:  host :: regex
                idx = alert_line_array[2] + " :: " + regex.to_s
                host_regex_arr[idx] += 1
            end
        end

        if (processed_count / 250).to_i == (processed_count / 250)
            spinner(processed_count.to_i.to_s, $alerts_count)
        end
    end
    return host_regex_arr
end


def writeout(output_data, output_file)
    puts "Writing file to `" + output_file + "`"
    File.open(output_file, "w") do |f|
        output_data.each { |line| f.puts(line) }
    end
end

####################################################################################################
####  End defs
####################################################################################################


script_opts = ["stickiness", "overlaps", "uncaught", "host_aggregate"]
if ARGV.length != 2
  puts "Command line format is: #{$0} <runmode> <config_file>"
  puts "Run modes are: " + script_opts.map { |e| "`#{e}`" }.join(', ')
  exit 1
end

run_mode =          ARGV[0]
config_file =       ARGV[1]
yaml_options =      YAML.load_file(config_file)
output_file =       "output_" + yaml_options['modes'][ARGV[0]]['output_file']
regex_file =        yaml_options['input_files']['regex_file']
alerts_file =       yaml_options['input_files']['alerts_file']

$stderr.print "Alerts file:     " + alerts_file
$stderr.print "\nConfig file:     " + config_file
$stderr.print "\nOutput file:     " + output_file
$stderr.print "\nRegex file:      " + regex_file

$alerts_count = %x{wc -l #{alerts_file}}.split.first.to_i - 1

regeces = []
File.open(regex_file, "r") do |f|
    while line = f.gets
        line ||= ''
        regeces << Regexp.new(line.chomp)
    end
end

$regexcount = regeces.length
$stderr.print "\nTesting #{$regexcount} regexes against #{$alerts_count} alerts\n\n"

File.open(alerts_file, "r") do |alert_data|

    writeable_array = Array.new

    ##  This part can be better, I'm sure, but so far Ruby's CLI option handlers have been turrble
    #+  It's probably just me.

    if ARGV[0] == "stickiness"
        regex_stickiness = stickiness(alert_data, regeces)
        spinner($alerts_count.to_s, $alerts_count.to_s)
        $stderr.print "\n" * 2
        
        regex_stickiness.sort_by { |k, v| v }.reverse_each do |regex, value|
            writeable_array << value.to_s  + " :: "  + regex.to_s
        end
    end



    if ARGV[0] == "overlaps"
        regex_overlaps = overlaps(alert_data, regeces)
            spinner($alerts_count.to_s, $alerts_count.to_s)
        $stderr.print "\n" * 2

        regex_overlaps.each do |alert, regexes|
            if regex_overlaps[alert].length >= 2
                writeable_array << regex_overlaps[alert].to_s + " :: \"" + alert.to_s + "\""
            end
        end
    end


    if ARGV[0] == "uncaught"
        uncaught_alerts = uncaught(alert_data, regeces)
        spinner($alerts_count.to_s, $alerts_count.to_s)
        $stderr.print "\n" * 2
        uncaught_alerts.each do |alert|
            writeable_array << alert
        end
        uncaught_count = writeable_array.length + 0.0
        puts "Caught #{($alerts_count-uncaught_count).to_i} of #{$alerts_count} (#{(100 * ($alerts_count-uncaught_count)/$alerts_count).round(2)}%)"
    end


    if ARGV[0] == "host_aggregate"
        host_alert_agg = host_aggregate(alert_data, regeces)
        spinner($alerts_count.to_s, $alerts_count.to_s)
        $stderr.print "\n" * 2
        ##  Index is:  host :: regex
        host_alert_agg.sort_by { |k, v| v }.reverse_each do |hostreg, count|
            writeable_array << count.to_s + " :: " + hostreg.to_s
        end
    end

    writeout(writeable_array, output_file)

    exit 0

end
