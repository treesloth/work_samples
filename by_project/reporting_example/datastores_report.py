"""
This script is to take the existing Bash scripts and convert them all to Python.


Parts of the data request script:
* Logging
* Define the starting date to request data for
* Define the number of periods to get data for
* Store data locally in a uniquely named file
*


This script should take a CSV file as dumped from the Metrics Archive and create another CSV
file. An example row looks like:
vm.perf.metric.get_virtualDisk.numberReadAveraged.number.average,1484348101,0,virtualmachine,A0G4,A0G4US036BCK064,vec,usdc03,commands/sec,.A0G4US036BCK064A0G4US032XVM313/A0G4US032XVM313.vmdk,A0G4US032XVM313.usdc03.vm,scsi0.0,Harddisk1,6000C292-5894-072c-e5cc-999bbc9feeda

"""
import logging
import tempfile
import csv
import sys
import datetime
import requests
import time
import math
from collections import defaultdict, OrderedDict

def get_csv_file(file_path=None):
    """
    Opens the CSV file and returns the data as an OrderedDict
    :param file_path: Absolute or relative path of the file to be read
    :return:
    """
    sys.stderr.write("Getting data from {}...\n".format(file_path))
    field_names = ["Metric", "Time", "Val", "class", "customer", "datastore", "datastoreStorageTier", "gservice",
                   "location", "units", "fileName", "host", "instance", "label", "uuida"]
    with open(file_path, 'r') as fh:
        reader = csv.DictReader(fh, fieldnames=field_names, quotechar="|")
        data = [item for item in reader]
    return data


def build_index_map(data_array):
    """
    Returns an index map like {'1484409234-A0G4US0360HF190': [0, 1900, 6014, 7000]}
    The length of the array may vary, but we probably want that to always be equal to four items in the future.

    :param data_array:
    :return: dict : {'1484409234-A0G4US0360HF190': [0, 1900, 6014, 7000]}
    """
    # Create a unique list of names to be used as the key names
    indexes = set(["{}-{}".format(item['Time'], item['datastore']) for item in data_array])
    index_map = {}

    for index in indexes:
        index_map[index] = defaultdict(lambda :0)

    for i in range(0, len(data_array)):
        index_name = "{}-{}".format(data_array[i]['Time'], data_array[i]['datastore'])
        # index_map[index_name].append(i)
        index_map[index_name][data_array[i]['Metric']] = i
    return index_map


def calc_stats(data_array, index_map, sla_ms):
    """
    For now I am just copying the logic that Andrew does in parser.awk starting at line 29 of that file.
    Returns
    :param data_array:
    :param index_map:
    :return:
    """
    total_instances = 0
    over_sla = 0
    for index in index_map:
        index_time, index_host = index.split("-")
        output_format = "{},{},{},{},{},{},{}"

        write_latency_metric =  'vm.perf.metric.get_virtualDisk.totalWriteLatency.millisecond.average'
        write_count_metric =    'vm.perf.metric.get_virtualDisk.numberWriteAveraged.number.average'
        read_latency_metric =   'vm.perf.metric.get_virtualDisk.totalReadLatency.millisecond.average'
        read_count_metric =     'vm.perf.metric.get_virtualDisk.numberReadAveraged.number.average'

        write_latency =         int(data[index_map[index][write_latency_metric]]['Val'])
        write_count =           int(data[index_map[index][write_count_metric]]['Val'])
        read_latency =          int(data[index_map[index][read_latency_metric]]['Val'])
        read_count =            int(data[index_map[index][read_count_metric]]['Val'])

        if len(index_map[index]) != 4:
            continue

        elif (write_count + read_count == 0):
            out = "{},{},{},{},{},{}".format(index_time, index_host,
                                                write_latency,
                                                write_count,
                                                read_latency,
                                                read_count,
                                                0)
            sys.stdout.write("{}\n".format(out))

        else:
            latency =  (write_latency * write_count + read_latency * read_count) \
                / (write_count + read_count)
            out = "{},{},{},{},{},{}".format(index_time, index_host,
                                             write_latency,
                                             write_count,
                                             read_latency,
                                             read_count,
                                             latency)

            sys.stdout.write("{}\n".format(out))
            if latency >= sla_ms:
                over_sla += 1
        total_instances += 1
    # Here we return the total number of instances, the count of instances over SLA, and then instances over SLA as %
    return (len(index_map), over_sla, 100 * (1 - over_sla / len(index_map)))

"""
total count of instances
the number that were over SLA
 - Look at line 36 (SLA is passed into the script) (5,10,20,30 for tier 0-3 respectively)
Then a percentage of the two above
"""

def dump_csv_file():
    """Dump the data built up in the script to a new CSV file"""
    pass


if __name__ == "__main__":
    start_time = datetime.datetime.now()
    try:
        sla_ms = sys.argv[1]
    except Exception as e:
        sla_ms = 0
    try:
        file_path = sys.argv[1]
    except Exception as e:
        sys.stderr.write("You did not specify a file\n")
        sys.exit(1)

    data = get_csv_file(file_path)
    data_map = build_index_map(data)
#    print "Here's your data_map!!!", data_map
    print(calc_stats(data, data_map, sla_ms))

    end_time = datetime.datetime.now()
    elapsed_time = end_time - start_time
    print(elapsed_time)
