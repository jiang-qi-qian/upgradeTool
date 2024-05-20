#!/bin/bash
# 此脚本需要 root 权限

if [ `whoami` != "root" ]; then
    echo "[ERROR] The upgrade requires root privileges"
    exit 1
fi

echo "Begin to check sdb and sql nodes"
if [ -f "/etc/default/sequoiadb" ]; then
    . /etc/default/sequoiadb
    SDB_INSTALL_DIR="${INSTALL_DIR}"
else
    echo "[ERROR] /etc/default/sequoiadb does not exists"
    exit 1
fi

NEWSDBRUNPACKAGE=$(${SDB_INSTALL_DIR}/bin/sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"NEWSDBRUNPACKAGE\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get NEWSDBRUNPACKAGE from config.js" && exit 1
test ! -f "${NEWSDBRUNPACKAGE}" && echo "[ERROR] Failed to get NEWSDBRUNPACKAGE from config.js" && exit 1

if [ "`${SDB_INSTALL_DIR}/bin/sdblist -t all`" != "Total: 0" ]; then
    echo "[ERROR] There are sdb nodes that have not stopped"
    exit 1
fi

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    test -f /etc/default/sequoiasql-mysql && . /etc/default/sequoiasql-mysql || . /etc/default/sequoiasql-mariadb
    SQL_INSTALL_DIR="${INSTALL_DIR}"
    if [ "`${SQL_INSTALL_DIR}/bin/sdb_sql_ctl status | tail -n 1 | grep "Run: 0"`" == "" ]; then
        echo "[ERROR] There are sql nodes that have not stopped"
        exit 1
    fi
    NEWSQLRUNPACKAGE=$(${SDB_INSTALL_DIR}/bin/sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"NEWSQLRUNPACKAGE\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get NEWSQLRUNPACKAGE from config.js" && exit 1
    test ! -f "${NEWSQLRUNPACKAGE}" && echo "[ERROR] Failed to get NEWSQLRUNPACKAGE from config.js" && exit 1
else
    echo "[WARN] SequoiaSQL is not installed on this machine"
    SQL_INSTALL_DIR=""
fi
echo "Done"

echo "Begin to upgrade SequoiaDB"
${NEWSDBRUNPACKAGE} --mode unattended --prefix "${SDB_INSTALL_DIR}"  --installmode upgrade
rc=$?
test $rc -ne 0 && echo "[ERROR] Failed to upgrade sdb, error code: $rc" && exit 1
echo "Done"

if [ "${SQL_INSTALL_DIR}" != "" ]; then
    echo "Begin to upgrade SequoiaSQL"
    ${NEWSQLRUNPACKAGE} --mode unattended --prefix "${SQL_INSTALL_DIR}"  --installmode upgrade
    rc=$?
    test $rc -ne 0 && echo "[ERROR] Failed to upgrade sql, error code: $rc" && exit 1
    echo "Done"
fi

echo "Begin to check version"
su - sdbadmin -c "sdb -v"
if [ "${SQL_INSTALL_DIR}" != "" ]; then
    su - sdbadmin -c "sdb_sql_ctl -v"
fi
echo "Done"

echo "Begin to check sdbcm status"
# 防止过长卡住
service sdbcm status | head -n 10
echo "Done"
