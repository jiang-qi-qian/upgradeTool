#!/bin/bash
echo "Begin to check backup dir UPGRADEBACKUPPATH"
DATESTR="`date +%Y%m%d`"
UPGRADEBACKUPPATH=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"UPGRADEBACKUPPATH\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
test $? -ne 0 && echo "Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
test "${UPGRADEBACKUPPATH}" == "" && echo "Failed to get UPGRADEBACKUPPATH from config.js" && exit 1

if [ ! -d "${UPGRADEBACKUPPATH}" ]; then
    echo "Backup dir ${UPGRADEBACKUPPATH} does not exists, mkdir it now"
    mkdir -p "${UPGRADEBACKUPPATH}"
else
    echo "Backup dir: ${UPGRADEBACKUPPATH}"
fi
echo "Done"

echo "Begin to check sdb and sql nodes"
if [ -f "/etc/default/sequoiadb" ]; then
    . /etc/default/sequoiadb
    SDB_INSTALL_DIR="${INSTALL_DIR}"
else
    echo "[ERROR] /etc/default/sequoiadb does not exists"
    exit 1
fi

if [ "`sdblist -t all`" != "Total: 0" ]; then
    echo "[ERROR] There are sdb nodes that have not stopped"
    exit 1
fi

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    if [ "`sdb_sql_ctl status | tail -n 1 | grep "Run: 0"`" == "" ]; then
        echo "[ERROR] There are sql nodes that have not stopped"
        exit 1
    fi
    test -f /etc/default/sequoiasql-mysql && . /etc/default/sequoiasql-mysql || . /etc/default/sequoiasql-mariadb
    SQL_INSTALL_DIR="${INSTALL_DIR}"
else
    echo "[WARN] SequoiaSQL is not installed on this machine"
    SQL_INSTALL_DIR=""
fi
echo "Done"

echo "Begin to backup sdb node info"
if [ "`sdblist -m local -r catalog -l | grep 'catalog'`" != "" ]; then
    CATALOGARRAY=(`sdblist -m local -r catalog -l | grep 'catalog' | sort | awk '{print $2" "$10}'`)
    echo "Backup catalog node ${CATALOGARRAY[1]} to ${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old"
    mkdir -p "${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old"
    test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old" && exit 1
    cp -a -r "${CATALOGARRAY[1]}" "${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old/"
    test $? -ne 0 && echo "[ERROR] Failed to cp ${CATALOGARRAY[1]} to ${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old" && exit 1
fi

DATAARRAY=(`sdblist -m local -r data -l | grep 'data' | sort | awk '{print $2" "$10}'`)
for((i=0;i<${#DATAARRAY[*]};i+=2));
do
    echo "Backup data ${DATAARRAY[i+1]}/SYSSTAT.1.* to ${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old"
    mkdir -p "${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old"
    test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old" && exit 1
    cp -a ${DATAARRAY[i+1]}/SYSSTAT.1.* "${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old"
    test $? -ne 0 && echo "[ERROR] Failed to cp ${DATAARRAY[i+1]}/SYSSTAT.1.* to ${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old" && exit 1
done
echo "Done"

echo "Begin to backup SequoiaDB install dir ${SDB_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old"
mkdir -p "${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old"
test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old" && exit 1
cp -a -r "${SDB_INSTALL_DIR}" "${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old"
test $? -ne 0 && echo "[ERROR] Failed to cp ${SDB_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old" && exit 1
echo "Done"

if [ "${SQL_INSTALL_DIR}" != "" ]; then
    echo "Begin to backup SequoiaSQL install dir ${SQL_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old"
    mkdir -p "${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old"
    test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old" && exit 1
    cp -a -r "${SQL_INSTALL_DIR}" "${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old"
    test $? -ne 0 && echo "[ERROR] Failed to cp ${SQL_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old" && exit 1
    echo "Done"
fi