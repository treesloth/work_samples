#!/usr/bin/python

"""
This script converts the base64-encoded compressed strings in the log file to the
JSON data that was posted to Glass.  To use it, take the compressed string between
the triple pipes (excluding the triple pipes) and put it in its own file.  Then
run this script on that file.
"""

import sys, getopt
import base64
import zlib
import argparse

#filename = sys.argv[1]
#outputname =  sys.argv[2]

pdesc_h = __doc__
pdesc_f = 'The name of the file containing the base64-encoded compressed data'
pdesc_o = 'The name of the file which will contain the decompressed, decoded data'

parser = argparse.ArgumentParser(description=pdesc_h)
parser.add_argument('-f', '--filename', required=True, help=pdesc_f)
parser.add_argument('-o', '--outputfile', required=True, help=pdesc_o)
args = parser.parse_args()


decoded = open(args.filename, "rb").read().decode('base64')
decompressed = zlib.decompress(decoded)
with open(args.outputfile, "wb") as f:
    f.write(decompressed)
    f.close()
