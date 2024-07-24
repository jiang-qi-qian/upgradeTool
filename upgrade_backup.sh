#!/bin/bash
# 此脚本 root 用户和 sdb 安装用户执行都可，如果 sdb 安装用户权限不足，需要使用 root 用户

MY_USER=`whoami`
echo "Begin to get sequoiadb install info"
if [ -f "/etc/default/sequoiadb" ]; then
    . /etc/default/sequoiadb
    
    # 需要 root 用户去处理 /etc/default 下的文件，删除 INSTALL_DIR 后的 '/'
    if [ "`echo ${INSTALL_DIR} | grep '.*/$'`" != "" ]; then
        if [ "${MY_USER}" != "root" ]; then
            echo "[ERROR] The INSTALL_DIR cannot end with '/' in /etc/default/sequoiadb, please run this tool as the root"
            exit 1
        fi
        # 去除 /etc/default/sequoiadb 中的 INSTALL_DIR 末尾的 /
        sed -i 's#INSTALL_DIR=\(.*\)/ *$#INSTALL_DIR=\1#' /etc/default/sequoiadb
        test $? -ne 0 && echo "Failed to delete the '/' at the end of INSTALL_DIR in /etc/default/sequoiadb" && exit 1
        echo "  Remove the '/' at the end of INSTALL_DIR in /etc/default/sequoiadb"
        # 重新加载文件
        . /etc/default/sequoiadb
    fi

    SDB_INSTALL_DIR="${INSTALL_DIR}"
    SDB_USER="${SDBADMIN_USER}"
    test ! -f "${SDB_INSTALL_DIR}/bin/sdblist" && echo "[ERROR] ${SDB_INSTALL_DIR}/bin/sdblist does not exist" && exit 1
    if [[ "${MY_USER}" != "${SDB_USER}" && "${MY_USER}" != "root" ]]; then
        echo "[ERROR] Only user ${SDB_USER} or root can execute this tool"
        exit 1
    fi
else
    echo "[ERROR] /etc/default/sequoiadb does not exists"
    exit 1
fi
echo "Done"

echo "Begin to get sequoiasql install info"
if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    sql_type=""
    test -f /etc/default/sequoiasql-mysql && { . /etc/default/sequoiasql-mysql;sql_type="mysql"; } || { . /etc/default/sequoiasql-mariadb;sql_type="mariadb"; }

    # 需要 root 用户去处理 /etc/default 下的文件，删除 INSTALL_DIR 后的 '/' 和添加 SQL 的版本号
    if [ "`echo ${INSTALL_DIR} | grep '.*/$'`" != "" ]; then
        if [ "${MY_USER}" != "root" ]; then
            echo "[ERROR] The INSTALL_DIR cannot end with '/' in /etc/default/sequoiasql-$sql_type, please run this tool as the root"
        fi
        # 去除 /etc/default/sequoiasql-... 中的 INSTALL_DIR 末尾的 /
        sed -i 's#INSTALL_DIR=\(.*\)/ *$#INSTALL_DIR=\1#' /etc/default/sequoiasql-$sql_type
        test $? -ne 0 && echo "Failed to delete the '/' at the end of INSTALL_DIR in /etc/default/sequoiasql-$sql_type" && exit 1
        echo "  Remove the '/' at the end of INSTALL_DIR in /etc/default/sequoiasql-$sql_type"
        # 重新加载文件
        test -f /etc/default/sequoiasql-mysql && . /etc/default/sequoiasql-mysql || . /etc/default/sequoiasql-mariadb
    fi

    SQL_INSTALL_DIR="${INSTALL_DIR}"
    test ! -f "${SQL_INSTALL_DIR}/bin/sdb_sql_ctl" && echo "[ERROR] ${SQL_INSTALL_DIR}/bin/sdb_sql_ctl does not exist" && exit 1

    if [ "${VERSION}" == "" ]; then
        if [ "${MY_USER}" != "root" ]; then
            echo "[ERROR] The VERSION cannot be empty in /etc/default/sequoiasql-$sql_type, please run this tool as the root"
            exit 1
        fi
        # 追加版本号
        sql_version=`${SQL_INSTALL_DIR}/bin/sdb_sql_ctl -v | head -n 1 | sed 's#[^0-9]*\([0-9]\.[0-9]\.[0-9]\.\?[0-9]\?\).*#\1#'`
        test $? -ne 0 && echo "Failed to get version from ${SQL_INSTALL_DIR}/bin/sdb_sql_ctl -v" && exit 1
        test "${sql_version}" == "" && echo "Failed to get version from ${SQL_INSTALL_DIR}/bin/sdb_sql_ctl -v" && exit 1
        sed -i "s#VERSION=#VERSION=$sql_version#" /etc/default/sequoiasql-$sql_type
        test $? -ne 0 && echo "Failed to add version into /etc/default/sequoiasql-$sql_type" && exit 1
        echo "  Add the VERSION in /etc/default/sequoiasql-$sql_type"
    fi
else
    echo "[WARNING] SequoiaSQL is not installed on this machine"
    SQL_INSTALL_DIR=""
fi
echo "Done"

echo "Begin to check backup dir UPGRADEBACKUPPATH"
UPGRADEBACKUPPATH=$(${SDB_INSTALL_DIR}/bin/sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"UPGRADEBACKUPPATH\"" -f cluster_opr.js)
test $? -ne 0 && echo "Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
test "${UPGRADEBACKUPPATH}" == "" && echo "Failed to get UPGRADEBACKUPPATH from config.js" && exit 1

if [ ! -d "${UPGRADEBACKUPPATH}" ]; then
    echo "  Backup dir ${UPGRADEBACKUPPATH} does not exists, mkdir it now"
    if [ "${MY_USER}" == "root" ]; then
        su - "${SDB_USER}" -c "mkdir -p ${UPGRADEBACKUPPATH}"
    else
        mkdir -p "${UPGRADEBACKUPPATH}"
    fi
else
    echo "Backup dir: ${UPGRADEBACKUPPATH}"
fi
echo "Done"

echo "Begin to check sdb and sql nodes"
if [ "${SQL_INSTALL_DIR}" != "" ]; then
    if [ "`${SQL_INSTALL_DIR}/bin/sdb_sql_ctl status | tail -n 1 | grep "Run: 0"`" == "" ]; then
        echo "[ERROR] There are sql nodes that have not stopped"
        exit 1
    fi
fi
if [ "`${SDB_INSTALL_DIR}/bin/sdblist -t all`" != "Total: 0" ]; then
    echo "[ERROR] There are sdb nodes that have not stopped"
    exit 1
fi
echo "Done"

echo "Begin to backup sdb node info"
if [ "`${SDB_INSTALL_DIR}/bin/sdblist -m local -r catalog -l | grep 'catalog'`" != "" ]; then
    CATALOGARRAY=(`${SDB_INSTALL_DIR}/bin/sdblist -m local -r catalog -l | grep 'catalog' | sort | awk '{print $2" "$10}'`)
    echo "  Backup catalog node ${CATALOGARRAY[1]} to ${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old"
    if [ "${MY_USER}" == "root" ]; then
        su - "${SDB_USER}" -c "mkdir -p ${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old"
    else
        mkdir -p "${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old"
    fi
    test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old" && exit 1
    cp -a -r "${CATALOGARRAY[1]}" "${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old/"
    test $? -ne 0 && echo "[ERROR] Failed to cp ${CATALOGARRAY[1]} to ${UPGRADEBACKUPPATH}/catalog_${CATALOGARRAY[0]}_old" && exit 1
fi

DATAARRAY=(`${SDB_INSTALL_DIR}/bin/sdblist -m local -r data -l | grep 'data' | sort | awk '{print $2" "$10}'`)
for((i=0;i<${#DATAARRAY[*]};i+=2));
do
    echo "  Backup data ${DATAARRAY[i+1]}/SYSSTAT.1.* to ${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old"
    if [ "${MY_USER}" == "root" ]; then
        su - "${SDB_USER}" -c "mkdir -p ${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old"
    else
        mkdir -p "${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old"
    fi
    test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old" && exit 1
    cp -a ${DATAARRAY[i+1]}/SYSSTAT.1.* "${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old"
    test $? -ne 0 && echo "[ERROR] Failed to cp ${DATAARRAY[i+1]}/SYSSTAT.1.* to ${UPGRADEBACKUPPATH}/data_${DATAARRAY[i]}_old" && exit 1
done
echo "Done"

echo "Begin to backup SequoiaDB install dir ${SDB_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old"
if [ "${MY_USER}" == "root" ]; then
    su - "${SDB_USER}" -c "mkdir -p ${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old"
else
    mkdir -p "${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old"
fi
test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old" && exit 1
cp -a -r "${SDB_INSTALL_DIR}" "${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old"
test $? -ne 0 && echo "[ERROR] Failed to cp ${SDB_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiadb_install_dir_old" && exit 1
echo "Done"

if [ "${SQL_INSTALL_DIR}" != "" ]; then
    echo "Begin to backup SequoiaSQL install dir ${SQL_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old"
    if [ "${MY_USER}" == "root" ]; then
        su - "${SDB_USER}" -c "mkdir -p ${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old"
    else
        mkdir -p "${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old"
    fi
    test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old" && exit 1
    cp -a -r "${SQL_INSTALL_DIR}" "${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old"
    test $? -ne 0 && echo "[ERROR] Failed to cp ${SQL_INSTALL_DIR} to ${UPGRADEBACKUPPATH}/sequoiasql_install_dir_old" && exit 1
    echo "Done"
fi