#!/bin/bash
# 安装旧版本
# 需要 root 权限
if [ `whoami` != "root" ]; then
    echo "[ERROR] The upgrade requires root privileges"
    exit 1
fi

if [ -f "/etc/default/sequoiadb" ]; then
    . /etc/default/sequoiadb
    SDB_INSTALL_DIR="${INSTALL_DIR}"
else
    echo "[ERROR] /etc/default/sequoiadb does not exists"
    exit 1
fi

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    test -f /etc/default/sequoiasql-mysql && . /etc/default/sequoiasql-mysql || . /etc/default/sequoiasql-mariadb
    SQL_INSTALL_DIR="${INSTALL_DIR}"
    OLDSQLRUNPACKAGE=$(${SDB_INSTALL_DIR}/bin/sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"OLDSQLRUNPACKAGE\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get OLDSQLRUNPACKAGE from config.js" && exit 1
    test ! -f "${OLDSQLRUNPACKAGE}" && echo "[ERROR] Failed to get OLDSQLRUNPACKAGE from config.js" && exit 1
else
    echo "[WARN] SequoiaSQL is not installed on this machine"
    SQL_INSTALL_DIR=""
fi

OLDSDBRUNPACKAGE=$(${SDB_INSTALL_DIR}/bin/sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"OLDSDBRUNPACKAGE\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get OLDSDBRUNPACKAGE from config.js" && exit 1
test ! -f "${OLDSDBRUNPACKAGE}" && echo "[ERROR] Failed to get OLDSDBRUNPACKAGE from config.js" && exit 1

echo "Begin to rollback SequoiaDB"
${OLDSDBRUNPACKAGE} --mode unattended --prefix "${SDB_INSTALL_DIR}" --installmode cover
rc=$?
test $rc -ne 0 && echo "[ERROR] Failed to upgrade sdb, error code: $rc" && exit 1
echo "Done"

if [ "${SQL_INSTALL_DIR}" != "" ]; then
    echo "Begin to rollback SequoiaSQL"
    ${OLDSQLRUNPACKAGE} --mode unattended --prefix "${SQL_INSTALL_DIR}" --installmode cover
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