#!/bin/bash
DATESTR="`date +%Y%m%d`"
UPGRADEBACKUPPATH=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"UPGRADEBACKUPPATH\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
test ! -d "${UPGRADEBACKUPPATH}" && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1

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
else
    echo "[WARN] SequoiaSQL is not installed on this machine"
    SQL_INSTALL_DIR=""
fi

# 备份新安装的编目目录
if [ "`sdblist -m local -r catalog -l | grep 'catalog'`" != "" ]; then
    echo "Begin to backup new catalog path"
    CATALOGPATH=`sdblist -m local -r catalog -l | grep 'catalog' | sort | awk '{print $10}'`
    test $? -ne 0 && echo "[ERROR] Failed to get catalog path from sdblist" && exit 1
    test ! -d "${CATALOGPATH}" && echo "[ERROR] Catalog path ${CATALOGPATH} does not exists" && exit 1

    CATALOGSVC=`sdblist -m local -r catalog -l | grep 'catalog' | sort | awk '{print $2}'`
    test $? -ne 0 && echo "[ERROR] Failed to get catalog svcname from sdblist" && exit 1

    mkdir -p "${UPGRADEBACKUPPATH}/catalog_${CATALOGSVC}_new/"
    test $? -ne 0 && echo "[ERROR] Failed to mkdir ${UPGRADEBACKUPPATH}/catalog_${CATALOGSVC}_new/" && exit 1

    mv "${CATALOGPATH}" "${UPGRADEBACKUPPATH}/catalog_${CATALOGSVC}_new/"
    test $? -ne 0 && echo "[ERROR] Failed to mv ${CATALOGPATH} to ${UPGRADEBACKUPPATH}/catalog_${CATALOGSVC}_new/" && exit 1
    echo "Done"

    # 回退旧版本编目目录
    echo "Begin to rollback old catalog path"
    cp -a -r ${UPGRADEBACKUPPATH}/catalog_${CATALOGSVC}_old/* "${CATALOGPATH}"
    test $? -ne 0 && echo "[ERROR] Failed to cp ${UPGRADEBACKUPPATH}/catalog_${CATALOGSVC}_old to ${CATALOGPATH}" && exit 1
    echo "Done"
fi

# 回退数据节点目录的 SYSSTAT.1.* 文件
echo "Begin to rollback old data node SYSSTAT.1.* file"
DATAPATHARRAY=(`sdblist -m local -r data -l | grep 'data' | sort | awk '{print $2" "$10}'`)
test $? -ne 0 && echo "[ERROR] Failed to get data path from sdblist" && exit 1
# 数组长度必须为偶数
test $((${#DATAPATHARRAY[*]}%2)) -ne 0 && echo "[ERROR] Failed to get data path from sdblist" && exit 1
for((i=0;i<${#DATAPATHARRAY[*]};i+=2));
do
    cp ${UPGRADEBACKUPPATH}/data_${DATAPATHARRAY[i]}_old/* "${DATAPATHARRAY[i+1]}/"
    test $? -ne 0 && echo "[ERROR] Failed to rollback data node ${UPGRADEBACKUPPATH}/data_${DATAPATHARRAY[i]}_old/SYSSTAT.1.* to ${DATAPATHARRAY[i+1]}/" && exit 1
done
echo "Done"