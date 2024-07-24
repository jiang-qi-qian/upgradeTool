#!/bin/bash
# 由于此停止脚本是第一个在所有机器上执行的脚本，此处增加一些检查

# 检查环境中是否同时存在多个 SQL，不支持使用此脚本升级
if [ `find /etc/default -regex "/etc/default/sequoiasql-\(mysql\|mariadb\)[1-4]?[0-9]?" | wc -l` -gt 1 ]; then
    echo "[ERROR] Check for multiple sequoiasql-[mysql|mariadb] files in /etc/default"
    exit 1
fi

# 检查 /etc/default 文件中 MD5, 安装路径，版本号是否存在，并且安装路径后不能带有 /
. /etc/default/sequoiadb
if [ "${MD5}" == "" ]; then
    echo "[ERROR] Failed to get MD5 in /etc/default/sequoiadb"
    exit 1
fi

if [ "${INSTALL_DIR}" != "" ]; then
    if [ "`echo ${INSTALL_DIR} | grep '.*/$'`" != "" ]; then
        echo "[ERROR] The INSTALL_DIR cannot end with '/' in /etc/default/sequoiadb"
        echo "[WARNING] Next upgrade_backup.sh needs to be use as the [root] and it will delete the '/' at the end of INSTALL_DIR in file /etc/default/sequoiadb"
    fi
else
    echo "[ERROR] Failed to get INSTALL_DIR in /etc/default/sequoiadb"
    exit 1
fi

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    sql_type=""
    test -f /etc/default/sequoiasql-mysql && { . /etc/default/sequoiasql-mysql;sql_type="mysql"; } || { . /etc/default/sequoiasql-mariadb;sql_type="mariadb"; }
    if [ "${MD5}" == "" ]; then
        echo "[ERROR] Failed to get MD5 in file /etc/default/sequoiasql-$sql_type"
        exit 1
    fi

    if [ "${VERSION}" == "" ]; then
        echo "[ERROR] Failed to get VERSION in file /etc/default/sequoiasql-$sql_type"
        echo "[WARNING] Next upgrade_backup.sh needs to be use as the [root] and it will add the VERSION in file /etc/default/sequoiasql-$sql_type"
    fi

    if [ "${INSTALL_DIR}" != "" ]; then
        if [ "`echo ${INSTALL_DIR} | grep '.*/$'`" != "" ]; then
            echo "[ERROR] The INSTALL_DIR cannot end with '/' in /etc/default/sequoiasql-$sql_type"
            echo "[WARNING] Next upgrade_backup.sh needs to be use as the [root] and it will delete the '/' at the end of INSTALL_DIR in file /etc/default/sequoiasql-$sql_type"
        fi
    else
        echo "[ERROR] Failed to get INSTALL_DIR in file /etc/default/sequoiasql-$sql_type"
        exit 1
    fi
fi


# 以下是原停止脚本逻辑
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