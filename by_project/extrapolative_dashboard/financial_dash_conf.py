metric_prefix   =   "brcalc"
calc_method     =   "br00001"
metric_name     =   "DiskUsage"
archive_ip      =   "10.131.151.155"
glass_url       =   "https://glass02.monilytics.net/widgets/"
cloud_list      =   [ "att_amereast_00001", "att_amereast_00002", "att_amerwest_00001", "att_amerwest_00002", "att_amerwest_00003", "att_amerwest_00004", "att_amerwest_00005", "att_ap_nrt_hkg_00001", "att_australia_00001", "att_euwest_00001", "att_japan_00001" ]
auth_token      =   "moarfl@vorplz"
##  Anything you put into json_parts will be mindlessly read into the JSON of the multiseries posts
json_parts      =   {'auth_token': 'moarfl@vorplz'} #, 'background-color': '#FFFFFF'}
baseval         =   418381824
#baseval         =   314572800
#baseval         =   0
conv            =   2  ##  The exponent on 1024 used to convert from GiB to whatever unit we want.
overage_price   =   .018
standard_price  =   .0045
