#!/usr/bin/python

import yaml
import xlsxwriter
import argparse
import sys
import csv

####################################################################################################
##  Classes/Methods block start

def caster( value ):
    """
    Make a reasonable guess whether a value can be cast as float, int, or text.
    Return it cast accordingly.

    """
    try:
        float(value)
    except:
        return str(value)
    else:
        ##  If you made it this far you're some sort of number...
        if int(float(value)) == float(value):
            return int(float(value))
        else:
            return float(value)


def parse_arguments( sysargs ):
    """
    Provide a nice way of parsing arguments
    """

    desc='Convert data from CSV to Excel'
    h_conf = 'The YAML-based config file to be used'
    h_append = 'String to append to the output filename (before the file extension)'
    h_dest_dir = 'The destination in which to place the completed Excel file'
    h_source_dir = 'The destination in which is found the source csv files to convert into Excel'

    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument('-c', '--config', required=True, help=h_conf)
    parser.add_argument('-a', '--append', help=h_append)
    parser.add_argument('-d', '--dest_dir', help=h_dest_dir)
    parser.add_argument('-s', '--source_dir', help=h_source_dir)
    args = parser.parse_args()
    return args


def read_csv( csvfile ):
    """
    Reads a CSV file and returns it as a list
    """

    csv_data_list = []
    with open(csvfile, 'rb') as f:
        reader = csv.reader(f)
        for rvals in reader:
            csv_data_list.append(rvals)
    return csv_data_list


def add_worksheet( sheet_name ):

    worksheet = workbook.add_worksheet(sheet_name)
    return worksheet

##  Methods block end
####################################################################################################


if __name__ == '__main__':

    args = parse_arguments(sysargs=sys.argv[1:])

    with open(args.config, 'r') as ymlfile:
        cfg = yaml.load(ymlfile)

    if args.append is not None:
        wb_name = args.dest_dir + '/' + cfg['workbook']['wbname'] + args.append + ".xlsx"
    else:
        wb_name = args.dest_dir + '/' + cfg['workbook']['wbname'] + ".xlsx"

    wb_name.replace('//', '/')
    workbook = xlsxwriter.Workbook(wb_name)


    ##  Create a list in the widths dictionary to keep track of the various lengths
    #+  Perhaps this should be done as by comparing to current max on the fly?

    for worksheet in cfg['worksheets']:
        widths = {}

        ws = add_worksheet(worksheet['name'])

        ##  First, we work on the file contents, if there is any:
        if 'file' and 'columns' in worksheet:

            for col in worksheet['columns']:
                widths[col['dest_column']] = []

            csv_source = args.source_dir + '/' + worksheet['file']
            csv_source.replace('//', '/')
            csv_data = read_csv(csv_source)
    
            ##  So, first we're going to format the various columns that are about to be populated
            for col in worksheet['columns']:
    
                colnum = col['dest_column'] - 1
                c_format = workbook.add_format({'num_format': col['c_format']})
                ws.set_column(colnum, colnum, None, c_format)
    
            #+  Now let's put some data in those nice columns
            #+  We keep track of the lengths of the cell entries to be used to set column width
            for rownum, line in enumerate(csv_data):
                for col in worksheet['columns']:
                    colnum = col['dest_column'] - 1
                    datapoint = caster(line[col['source_column'] - 1])
                    widths[col['dest_column']].append(len(str(datapoint)))
                    ws.write(rownum, colnum, datapoint)

            ##  Finally, apply the widths we just saved
            for column_num, column_widths in widths.iteritems():
                ws.set_column(column_num - 1 , column_num - 1, max(column_widths) + 2)

        ##  Next, we add any explicit contents
        if 'contents' in worksheet:
            for content in worksheet['contents']:
                rownum = content['dest_row'] - 1
                colnum = content['dest_column'] - 1
#                print content['content'], content['dest_row'], content['dest_column']
                ws.write(rownum, colnum, caster(content['content']))

        ##  And now, formulas...
        if 'formulas' in worksheet:
            for formula in worksheet['formulas']:
                rownum = formula['dest_row'] - 1
                colnum = formula['dest_column'] - 1
                if 'c_format' in formula:
                    c_format = workbook.add_format({'num_format': formula['c_format']})
                    ws.write_formula(rownum, colnum, formula['formula'], c_format)
                else:
                    ws.write_formula(rownum, colnum, formula['formula'])

    workbook.close()
    print wb_name
