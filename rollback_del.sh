#!/bin/bash
sdb -e "var CUROPR = \"dropSYSRECYCLEITEMS\";var DATESTR = \"`date +%Y%m%d`\"" -f cluster_opr.js