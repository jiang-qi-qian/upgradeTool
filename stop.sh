#!/bin/bash
# 停止本机器上所有 sdb 节点，mysql 或 mariadb 实例和 sdbcm

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    echo "Running: sdb_sql_ctl status"
    sdb_sql_ctl status
    rc=$?
    test $rc -ne 0 && echo "[ERROR] sdb_sql_ctl status error: $rc" && exit 1

    echo "Done"
    echo "----------------------------------------------------------"

    echo "Running: sdb_sql_ctl stopall"
    sdb_sql_ctl stopall
    rc=$?
    test $rc -ne 0 && echo "[ERROR] sdb_sql_ctl stopall error: $rc" && exit 1

    echo "Done"
    echo "----------------------------------------------------------"

    echo "Running: sdb_sql_ctl status"
    sdb_sql_ctl status
    rc=$?
    test $rc -ne 0 && echo "[ERROR] sdb_sql_ctl status error: $rc" && exit 1

    echo "Done"
    echo "----------------------------------------------------------"
else 
    echo "[WARN] SequoiaSQL is not installed on this machine"
fi

echo "Running: sdblist -t all -l"
sdblist -t all -m local -l
rc=$?
test $rc -ne 0 && echo "[ERROR] sdb_sql_ctl sdblist error: $rc" && exit 1

echo "Done"
echo "----------------------------------------------------------"

echo "Running: sdbstop -t all"
sdbstop -t all
rc=$?
test $rc -ne 0 && echo "[ERROR] sdbstop error: $rc" && exit 1

echo "Done"
echo "----------------------------------------------------------"

echo "Running: sdbcmtop"
sdbcmtop
rc=$?
test $rc -ne 0 && echo "[ERROR] sdbcmtop error: $rc" && exit 1

echo "Done"
echo "----------------------------------------------------------"

echo "Running: sdblist -t all -m local -l"
sdblist -t all -m local -l
rc=$?
test $rc -ne 0 && echo "[ERROR] sdblist error: $rc" && exit 1

echo "Done"
echo "Stop success"