#!/bin/bash
# 此脚本需要 root 权限

if [ `whoami` != "root" ]; then
    echo "[ERROR] The upgrade requires root privileges"
    exit 1
fi

echo "Begin to check sdb and sql install dir"
if [ -f "/etc/default/sequoiadb" ]; then
    . /etc/default/sequoiadb
    SDB_INSTALL_DIR="${INSTALL_DIR}"
    SDB_MD5="${MD5}"
else
    echo "[ERROR] /etc/default/sequoiadb does not exists"
    exit 1
fi

NEWSDBRUNPACKAGE=$(${SDB_INSTALL_DIR}/bin/sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"NEWSDBRUNPACKAGE\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get NEWSDBRUNPACKAGE from config.js" && exit 1
test ! -f "${NEWSDBRUNPACKAGE}" && echo "[ERROR] NEWSDBRUNPACKAGE does not exist" && exit 1

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    test -f /etc/default/sequoiasql-mysql && . /etc/default/sequoiasql-mysql || . /etc/default/sequoiasql-mariadb
    SQL_INSTALL_DIR="${INSTALL_DIR}"
    SQL_MD5="${MD5}"
    NEWSQLRUNPACKAGE=$(${SDB_INSTALL_DIR}/bin/sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"NEWSQLRUNPACKAGE\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get NEWSQLRUNPACKAGE from config.js" && exit 1
    test ! -f "${NEWSQLRUNPACKAGE}" && echo "[ERROR] Failed to get NEWSQLRUNPACKAGE from config.js" && exit 1
else
    echo "[WARNING] SequoiaSQL is not installed on this machine"
    SQL_INSTALL_DIR=""
fi
echo "Done"

echo "Begin to upgrade SequoiaDB"
new_sdb_version=`${NEWSDBRUNPACKAGE} --version | sed 's/.* \([0-9]\.[0-9]\.[0-9]\) .*/\1/'`
test $? -ne 0 && echo "[ERROR] Failed to get SequoiaDB version from ${NEWSDBRUNPACKAGE}" && exit 1
cur_sdb_version=`${SDB_INSTALL_DIR}/bin/sdb -v | head -n 1 | sed 's/.* \([0-9]\.[0-9]\.[0-9]\)/\1/'`
test $? -ne 0 && echo "[ERROR] Failed to get SequoiaDB version from ${SDB_INSTALL_DIR}/bin/sdb" && exit 1
echo "  Current SequoiaDB version is ${cur_sdb_version}, and the upgrade package version is ${new_sdb_version}"

# 如果 sdb 的安装包中的 md5 和当前版本的 md5 相同，则跳过升级
new_sdb_md5=`md5sum ${NEWSDBRUNPACKAGE} | awk '{print $1}'`
test $? -ne 0 && echo "[ERROR] Failed to get SequoiaDB md5 from ${NEWSDBRUNPACKAGE}" && exit 1
if [ "${new_sdb_md5}" == "${SDB_MD5}" ]; then
    echo "  [WARNING] The current SequoiaDB md5 is ${SDB_MD5}, which is the same as the upgrade package md5, no need to upgrade"
else
    # 需要升级时检查节点状态
    if [ "`${SDB_INSTALL_DIR}/bin/sdblist -t all`" != "Total: 0" ]; then
        echo "[ERROR] There are sdb nodes that have not stopped"
        exit 1
    fi
    ${NEWSDBRUNPACKAGE} --mode unattended --prefix "${SDB_INSTALL_DIR}"  --installmode upgrade
    rc=$?
    test $rc -ne 0 && echo "[ERROR] Failed to upgrade sdb, error code: $rc" && exit 1
fi
echo "Done"

if [ "${SQL_INSTALL_DIR}" != "" ]; then
    echo "Begin to upgrade SequoiaSQL"

    new_sql_version=`${NEWSQLRUNPACKAGE} --version | sed 's/.* \([0-9]\.[0-9]\.[0-9]\) .*/\1/'`
    test $? -ne 0 && echo "[ERROR] Failed to get SequoiaSQL version from ${NEWSQLRUNPACKAGE}" && exit 1
    cur_sql_version=`${SQL_INSTALL_DIR}/bin/sdb_sql_ctl -v | head -n 1 | sed 's/.* \([0-9]\.[0-9]\.[0-9]\)/\1/'`
    test $? -ne 0 && echo "[ERROR] Failed to get SequoiaSQL version from ${SQL_INSTALL_DIR}/bin/sdb_sql_ctl" && exit 1
    echo "  Crurrent SequoiaSQL version is ${cur_sql_version}, and the upgrade package version is ${new_sql_version}"

    # 如果 sql 的安装包中的 md5 和当前版本的 md5 相同，则跳过升级
    new_sql_md5=`md5sum ${NEWSQLRUNPACKAGE} | awk '{print $1}'`
    test $? -ne 0 && echo "[ERROR] Failed to get SequoiaSQL md5 from ${NEWSQLRUNPACKAGE}" && exit 1

    if [ "${new_sql_md5}" == "${SQL_MD5}" ]; then
        echo "  [WARNING] The current SequoiaSQL md5 is ${SQL_MD5}, which is the same as the upgrade package md5, no need to upgrade"
    else
        # 需要升级时检查节点状态
        if [ "`${SQL_INSTALL_DIR}/bin/sdb_sql_ctl status | tail -n 1 | grep "Run: 0"`" == "" ]; then
            echo "[ERROR] There are sql nodes that have not stopped"
            exit 1
        fi
        ${NEWSQLRUNPACKAGE} --mode unattended --prefix "${SQL_INSTALL_DIR}"  --installmode upgrade
        rc=$?
        test $rc -ne 0 && echo "[ERROR] Failed to upgrade sql, error code: $rc" && exit 1
    fi
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
