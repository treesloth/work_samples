# ETL

This README is incomplete.  Expect updates.  I might be typing even as you read this...

Note that certain files have elements that have been obfuscated due to containing proprietary information, such as paths, IP addresses, etc.

This project provided extraction, transformation, and loading for a time-series data workflow.  Data is extracted from an OpenTSDB database and then transformed.  Specifically, the data is reduced from the full time series to a minimal spanning set of tag keys and tag values for the extracted data set.  Once the transformation is completed, the data is converted to PUT format, suitable for load operations, and set to the receiving database server.

###  About repo files

This section under construction...

fullset.py - This file converts scan import lines directly to PUT'able lines, suitable for feeding to an OpenTSDB writer.  It does not peform tranformations in the ETL sense of the term.  This is used for testing and nontransformational data loading.

mets - A plain-text listing of metrics that are imported from the extraction database.

newmets - A plain-text list of any new metrics that an administrator may wish to add to the ETL process.

notes - notes

runner.sh - 

runner_yaml.sh
support_files
tagset.py



