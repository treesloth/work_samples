"""
Need to query data since the beginning

"""
import csv
import sys
from pprint import pprint

import requests
from common import get_csv_file, notify
from collections import defaultdict

def build_index_map(data_array):
    """
    Copied from datastores_report.build_index_map and updated for use here

    :param data_array: Generated from get_csv_file function
    :return: dict : {'1484409234-A0G4US0360HF190': [0, 1900, 6014, 7000]}
    """
    # Create a unique list of names to be used as the key names
    key_name = "{}:::{}"
    indexes = set([key_name.format(item['host'], item['ifAlias']) for item in data_array])
    index_map = {}

    # Basically set everything to a Null value if it's ever referenced
    for index in indexes:
        index_map[index] = []

    #
    for i in range(0, len(data_array)):
        index_name = key_name.format(data_array[i]['host'], data_array[i]['ifAlias'])

        # index_map[index_name][data_array[i]['Metric']] = i
        index_map[index_name].append(i)
    return index_map


def calc_stats(data_array, index_map):
    """
    Calculate the per port number of responses as a percent in each state (Up, Down, Unknow)

    :param data_array: A data array as provided from get_csv_file
    :param index_map:
    :return:
    """
    for index in index_map:

        # for location in index_map[index]:
        host, port = index.split(":::")
        # Expected output fields host, port, value (1,2,3,4,etc.), count of value, total data point count
        output_format = "{},{},{},{},{},{},{},{},{}\n"
        count_one = len([data_array[item]['Val'] for item in index_map[index] if data_array[item]['Val'] == 1])
        count_two = 0
        count_three = 0
        count_four = 0
        count_five = 0
        count_six = 0
        count_seven = 0
        sys.stdout.write(
            output_format.format(host, port, count_one, count_two, count_three, count_four, count_five, count_six,
                                 count_seven))



if __name__ == "__main__":
    try:
        file_path = sys.argv[1]
        notify("Getting network data...")
        field_names = ['Metric','Time','Val','class','gservice','host','ifAlias','ifDescr','location']
        data = get_csv_file(file_path=file_path, field_names=field_names)
        # index_map = build_index_map(data)
        # calc_stats(data, index_map)
        output_data = {}
        for row in data:
            key_name = "{}:::{}".format(row['host'], row['ifAlias'])
            output_data[key_name] = [0,0,0,0,0,0,0]

        for row in data:
            key_name = "{}:::{}".format(row['host'], row['ifAlias'])

            output_data[key_name][int(row['Val']) - 1] += 1

        output_format = "{},{},{},{},{},{},{},{},{}\n"
        for row in output_data:
            host, port = row.split(":::")
            sys.stdout.write(output_format.format(host,
                                                  port,
                                                  output_data[row][0],
                                                  output_data[row][1],
                                                  output_data[row][2],
                                                  output_data[row][3],
                                                  output_data[row][4],
                                                  output_data[row][5],
                                                  output_data[row][6]))


    except IndexError as e:
        notify("Please provide a file path to import data from")
        sys.exit(1)

    except Exception as e:
        notify("Unknown error occurred.")
        raise


