#!/usr/bin/python

import json
import csv
import argparse
import requests
import math
import calendar as cal
import time
import os
import financial_dash_conf as config
import base64
import zlib

def logger( log_data ):

    """
    Logs whatever is passed to it in a date-stamped log entry
    """
    d = time.strptime(time.strftime("%d %b %Y"), "%d %b %Y")
    week_num = str("%02d" % (int(time.strftime("%U", d)) + 1))
    year = str("%04d" % (int(time.strftime("%Y", d)) + 1))
    script_path = os.path.realpath(__file__).rsplit('/', 1)[0]
    log_path = script_path + "/logs"
    if not os.path.exists(log_path):
        os.makedirs(log_path)
    logfile = log_path + "/" + "finances_" + year + week_num + ".log"
    write_line = str(time.time()) + " :: " + str(log_data) + '\n'
    f = open(logfile, 'a')
    f.write(write_line)
    f.close()

def get_from_archive( site, ip, metric, startdate, calc_method ):
    """
    Retrieves and t
    Input:      A row of CSV data
    Output:     A data structure ready for JSON dumping
    """

    url =       "http://" + ip + "/metrics-archive/mtc/query2x?"
    url +=      "start=" + startdate
    url +=      "&m=zimsum:" + metric
    url +=      "%7bcustomer=*,cloud=" + site + ",calcmethod=" + calc_method + "%7d"
    url +=      "&trans=agg&nalign=86400&ftype=json"
   
    ma_data = requests.get(url)
    return url, ma_data

def calc_slope( data_list ):
    """Calculates the slope from a dataset
    Input:      Valid x-y data
    Output:     A slope
    """
    ##  Calculate the slope using the formula m = (a - b) / (c - d) where:
    #+  n = number of values in the set
    #+  A = n times the sum of products of corresponding x and y values
    #+  Keep on documenting....
    valcount = len(data_list)
    a, b, c, d, e =                 0, 0, 0, 0, 0
    m, x_sum, x_sq_sum, y_sum =     0, 0, 0, 0
    for i in range(valcount):
        a = a + (i + 1) * data_list[i]
        x_sum = x_sum + (i + 1)
        x_sq_sum = x_sq_sum + math.pow(i + 1, 2)
        y_sum = y_sum + data_list[i]
    a = valcount * a
    b = x_sum * y_sum
    c = valcount * x_sq_sum
    d = math.pow(x_sum, 2)
    m = (a - b) / (c - d)
    return(m)

def calc_y_int( data_list ):
    """Calculates the y-intercept from a dataset
    Input:      Valid x-y data
    Output:     A y-intercept
    """
    ##  Now, calculate the y-intercept using the formula (e - f) / n where:
    #+  n is defined as in calc_slope
    #+  e is the same as y_sum
    #+  f is the slope (m) times the sum of x values (x_sum)
    e, x_sum = 0, 0
    valcount = len(data_list)
    for i in range(valcount):
        e = e + data_list[i]
        x_sum = x_sum + (i + 1)
    m = calc_slope(data_list)
    f = m * x_sum
    y_int = (e - f) / valcount
    return y_int

def project_values( data_list, values_wanted ):
    """
    Calculates datapoints for a trendline
    Input:      Period-to-date data list
    Output:     Values for a formula and datapoints to the end of the period
    """
    valcount = len(data_list)
    mssing_count = values_wanted - valcount
    m = calc_slope(data_list)
    b = calc_y_int(data_list)
    projection = []
    for i in range(1, values_wanted + 1):
        projection.append(int(m * i + b))
    
    return m, b, projection

def fill_in_missing_days( date_list ):
    """
    Completes a date list, lengthening it from current to the user-specified period
    Input:      Ordered list of dates
    Output:     A completed date list
    """
    missing_days =  int(args.period) - len(date_list)
    
    for i in range(len(date_list), missing_days + len(date_list)):
        date_list.append(str(int(date_list[-1]) + 86400))

    return date_list

def build_postable_json( ma_data ):
    """
    Docstring
    """
    json_ma_data =          ma_data.json()
    ordered_values =        []
    date_list =             []

    for i in json_ma_data[0]['dps']:
        if i[0] == 0:
            val = prev
        else:
            val = i[0]
        ordered_values.append(val)
        date_list.append(i[1])
        prev = i[0]

    (slope, y_intercept, projection) = project_values(ordered_values, int(args.period))
    date_list = fill_in_missing_days(date_list)

    ##  ste:  "Start to end", projected data from the beginning to the end of the month/quarter
    ste_data =                              {}
    ste_data['series'] =                    []

    ##  ttd:  "Time to date", real data from the beginning to present
    ttd_data =                              {}
    ttd_data['series'] =                    []

    for i in config.json_parts:
        ste_data[i] = config.json_parts[i]
        ttd_data[i] = config.json_parts[i]

    real_data =                             {}
    real_data['color'] =                    '#2C95DD'
    real_data['data'] =                     []

    proj_data =                             {}
    proj_data['color'] =                    '#ED1F25'
    proj_data['data'] =                     []

    base_data =                             {}
    base_data['color'] =                    '#888888'
    base_data['data'] =                     []

    real_meter =                            {}
    proj_meter =                            {}

    first_of_month = time.strftime("%Y/%m/01")

    for i in range(len(ordered_values)):
        real_temp_dict = {}
        if ordered_values[i] == 0:
            val = prev
        else:
            val = ordered_values[i]
        real_temp_dict['x'] = int(date_list[i])
        real_temp_dict['y'] = float("{0:.2f}".format(val / unit_conv))
        last_real = val
        real_data['data'].append(real_temp_dict)
        prev = ordered_values[i]

    ttd_data['displayedValue'] = float("{0:.2f}".format(prev / unit_conv))

    if len(ordered_values) < int(args.period):
        for i in range(int(args.period) - len(ordered_values)):
            real_data['data'].append(real_temp_dict)

    for i in range(len(projection)):
        proj_temp_dict = {}
        proj_temp_dict['x'] = int(date_list[i])
        proj_temp_dict['y'] = projection[i] / unit_conv
        last_proj = projection[i]
        proj_data['data'].append(proj_temp_dict)
        base_temp_dict = {}
        base_temp_dict['x'] = int(date_list[i])
        base_temp_dict['y'] = config.baseval / unit_conv
        base_data['data'].append(base_temp_dict)

    proj_basepay =      config.baseval * config.standard_price
    quarter_earned =    0
    qrtr_expln_str =    'Quarter value is the sum of month values.<br \>'

    if int(args.period) in range(90, 93) and args.monthstart.startswith(first_of_month):
        for i in proj_data['data']:
            curr_ts_month_num =     time.strftime('%m', time.localtime(i['x']))
            next_day_month_num =    time.strftime('%m', time.localtime(i['x'] + 86400))

            if curr_ts_month_num != next_day_month_num:
                overage = max(0, (i['y'] * 1024 ** int(config.conv)) - config.baseval)
                quarter_earned += proj_basepay + overage * config.overage_price
        ste_data['displayedValue'] = float("{0:.0f}".format(quarter_earned))
    elif int(args.period) in range(28, 32) and args.monthstart.startswith(first_of_month):
        for i in proj_data['data']:
            curr_ts_month_num =     time.strftime('%m', time.localtime(i['x']))
            next_day_month_num =    time.strftime('%m', time.localtime(i['x'] + 86400))
            if curr_ts_month_num != next_day_month_num:
                overage = max(0, (i['y'] * 1024 ** int(config.conv)) - config.baseval)
                month_earned = proj_basepay + overage * config.overage_price
        ste_data['displayedValue'] = float("{0:.0f}".format(month_earned))

    ##  Create the meter percentages
    real_meter['auth_token'] = config.json_parts['auth_token']
    real_meter['value'] = float("{0:.2f}".format(100 * last_real / (config.baseval))) ## / unit_conv)))
    real_meter['status'] = []
    real_meter['status'].append(real_meter['value'])
    real_meter['status'].append('#4C4C4C')

    proj_meter['auth_token'] = config.json_parts['auth_token']
    proj_meter['value'] = float("{0:.2f}".format(100 * last_proj / (config.baseval))) ##  / unit_conv)))
    proj_meter['status'] = []
    proj_meter['status'].append(proj_meter['value'])
    proj_meter['status'].append('#4C4C4C')

    last_proj = float("{0:.2f}".format(last_proj))
    last_real = float("{0:.2f}".format(last_real))
        
    ste_data['dataMin'] =                   "200"
    ttd_data['dataMin'] =                   "200"
    
    ste_data['series'].append(base_data)
    ste_data['series'].append(proj_data)
    ttd_data['series'].append(base_data)
    ttd_data['series'].append(real_data)

    return ste_data, ttd_data, real_meter, proj_meter

def base64_encode( data ):
    compressed = zlib.compress(data)
    b = base64.b64encode(compressed)
    return b

def post_data( json_dataset, widget_name ):
    post_url = config.glass_url + widget_name
    #print "\n", post_url, "\n"
    r = requests.post(post_url, data = json_dataset, verify=False)
    return r
    
    
if __name__ == '__main__':

    pdesc_h = 'Acquire, prepare, and send data to the financials dashboard'
    pdesc_m = 'The date on which the month starts, in the format YYYY/MM/DD-HH:mm:SS'
    pdesc_p = 'The length of the time to be plotted, in days'
    pdesc_f = 'The name of the forecast (projected) data widget'
    pdesc_r = 'The name of the real data widget'
    pdesc_a = 'The name of the real data meter widget'
    pdesc_b = 'The name of the projected data widget'
    pdesc_w = 'The path and file prefix to which to write out the JSON'

    parser = argparse.ArgumentParser(description=pdesc_h)
    parser.add_argument('-m', '--monthstart', required=True, help=pdesc_m)
    parser.add_argument('-p', '--period', required=True, help=pdesc_p)
    parser.add_argument('-f', '--forecastwidget', required=True, help=pdesc_f)
    parser.add_argument('-r', '--realwidget', required=True, help=pdesc_r)
    parser.add_argument('-a', '--realmeter', help=pdesc_a)
    parser.add_argument('-b', '--projmeter', help=pdesc_b)
    parser.add_argument('-w', '--writeout', action='store_true', help=pdesc_w)
    args = parser.parse_args()

    monthstart =            args.monthstart
    metric_name =           config.metric_prefix + "." + config.metric_name
    calc_method =           config.metric_prefix + "." + config.calc_method
    archive_ip =            config.archive_ip
    allclouds =             "|".join(config.cloud_list)
    (url, ma_data) =        get_from_archive( allclouds, archive_ip, metric_name, monthstart, calc_method )
    logger(url)
    unit_conv =             math.pow(1024, config.conv)

##  Uncomment to test your intermediate data structures.
#    json_real_data = json.dumps(real_data, sort_keys=True,
#                     indent=4, separators=(',', ': '))
#    print json_real_data
#    
#    json_proj_data = json.dumps(real_data, sort_keys=True,
#                     indent=4, separators=(',', ': '))
#    print json_proj_data

    (ste_data, ttd_data, last_real, last_proj) = build_postable_json(ma_data)
    
    json_ste_data = json.dumps(ste_data, sort_keys=True,
                     indent=4, separators=(',', ': '))
    json_ttd_data = json.dumps(ttd_data, sort_keys=True,
                     indent=4, separators=(',', ': '))
    json_lr_data = json.dumps(last_real)
    json_lp_data = json.dumps(last_proj)

    logger("json_last_real_data: |||" + base64_encode(json_lr_data) + "|||")
    logger("json_last_projected_data: |||" + base64_encode(json_lp_data) + "|||")
    logger("json_start_to_end_data: |||" + base64_encode(json_ste_data) + "|||")
    logger("json_time_to_date_data: |||" + base64_encode(json_ttd_data) + "|||")

    post_data(json_ste_data, args.forecastwidget)
    post_data(json_ttd_data, args.realwidget)
    
    if args.realmeter is not None:
        post_data(json_lr_data, args.realmeter)

    if args.projmeter is not None:
        post_data(json_lp_data, args.projmeter)

    ##  You want a copy?  Here, have a copy.
    if args.writeout is True:
        current_epoch = cal.timegm(time.gmtime())
        script_path = os.path.realpath(__file__).rsplit('/', 1)[0]
        json_struct_list = ('json_ste_data', 'json_lr_data', 'json_ttd_data', 'json_lp_data')
        for i in json_struct_list:
            savefile = script_path + "/" + i + "_" + str(current_epoch) + ".json"
            f = open(savefile, 'w')
            f.write(locals()[i])
            f.close()
