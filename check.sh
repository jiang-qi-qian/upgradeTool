#!/bin/bash

echo "Begin to check backup dir UPGRADEBACKUPPATH"
DATESTR="`date +%Y%m%d`"
UPGRADEBACKUPPATH=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"UPGRADEBACKUPPATH\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
test ! -d "${UPGRADEBACKUPPATH}" && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
echo "Backup dir: ${UPGRADEBACKUPPATH}"
echo "Done"

INSTANCEGROUP=""
if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    echo "Begin to check instance group"
    SDBUSER=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SDBUSER\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SDBUSER from config.js" && exit 1
    SDBPASSWD=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SDBPASSWD\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SDBPASSWD from config.js" && exit 1
    ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" > /dev/null
    test $? -ne 0 && echo "[ERROR] Failed to get HASQL instanace group from ha_inst_group_list" && exit 1

    # 检查是否有多个实例组，不支持多实例组
    if [ "`ha_inst_group_list -u${SDBUSER} -p${SDBPASSWD} | sed '1d' | awk '{print $1}' | uniq | wc -l`" != "1" ]; then
            echo "[ERROR] More than one instance group was detected"
    fi
    INSTANCEGROUP=`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" | sed '1d' | awk '{print $1}' | uniq`
    test $? -ne 0 && echo "[ERROR] Failed to get HASQL instance group name from ha_inst_group_list" && exit 1
    echo "Done"
else
    echo "[WARN] SequoiaSQL is not installed on this machine"
fi

sdb -e "var CUROPR = \"checkCluster\";var INSTANCEGROUP = \"${INSTANCEGROUP}\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js
sdb -e "var CUROPR = \"collect_new\";var INSTANCEGROUP = \"${INSTANCEGROUP}\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js

echo "Begin to diff backup file"
diff "${UPGRADEBACKUPPATH}/snapshot_cl_old.info" "${UPGRADEBACKUPPATH}/snapshot_cl_new.info"
test $? -ne 0 && echo "[ERROR] Diff file ${UPGRADEBACKUPPATH}/snapshot_cl_old.info ${UPGRADEBACKUPPATH}/snapshot_cl_new.info failed"
diff "${UPGRADEBACKUPPATH}/domain_name_old.info" "${UPGRADEBACKUPPATH}/domain_name_new.info"
test $? -ne 0 && echo "[ERROR] Diff file ${UPGRADEBACKUPPATH}/domain_name_old.info ${UPGRADEBACKUPPATH}/domain_name_new.info failed"
if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    diff "${UPGRADEBACKUPPATH}/hasql_old.info" "${UPGRADEBACKUPPATH}/hasql_new.info"
    test $? -ne 0 && echo "[ERROR] Diff file ${UPGRADEBACKUPPATH}/hasql_old.info ${UPGRADEBACKUPPATH}/hasql_new.info failed"
fi
echo "Done"

echo "Begin to check SDB"
sdb -e "var CUROPR = \"checkBasic\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js
echo "Done"

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    # SQL
    echo "Begin to check local SQL"
    SQLUSER=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SQLUSER\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SQLUSER from config.js" && exit 1
    SQLPASSWD=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SQLPASSWD\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SQLPASSWD from config.js" && exit 1
    SQLPORT=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SQLPORT\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SQLPORT from config.js" && exit 1
    TESTCS=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"TESTCS\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get TESTCS from config.js" && exit 1
    TESTCL=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"TESTCL\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get TESTCL from config.js" && exit 1
    SQLHOST=`hostname`

    test $? -ne 0 && echo "[ERROR] Failed to use \`hostname\`" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "create database ${TESTCS};"
    test $? -ne 0 && echo "[ERROR] Create database ${TESTCS} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "create table ${TESTCL}(uid int,name varchar(10),address varchar(10));"
    test $? -ne 0 && echo "[ERROR] Create table ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "alter table ${TESTCL} add index uid_index(uid);"
    test $? -ne 0 && echo "[ERROR] Alter table ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "insert into ${TESTCL} values(1,\"a\",\"广州\"),(2,\"A\",\"深圳\");"
    test $? -ne 0 && echo "[ERROR] Insert data to ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
    test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "update ${TESTCL} set address = \"东莞\" where uid =2;"
    test $? -ne 0 && echo "[ERROR] Update ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
    test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "delete from ${TESTCL} where uid=1;"
    test $? -ne 0 && echo "[ERROR] Delete ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
    test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in SQL failed" && exit 1
    echo "Done"

    # 尝试连接其他机器的 SQL 实例检查是否同步
    if [ "`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" | sed '1d' | grep -w " ${SQLPORT} " | grep "\`hostname\`"`" != "" ]; then
        echo "Begin to check another machine SQL"
        SQLHOST=`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" | sed '1d' | grep -w " ${SQLPORT} " | grep -v "\`hostname\`" | head -n 1 | awk '{print $3}'`
        SQLPORT=`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" | sed '1d' | grep -w " ${SQLPORT} " | grep -v "\`hostname\`" | head -n 1 | awk '{print $4}'`
        mysql -h"${SQLHOST}" -P "${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "show create table ${TESTCS}.${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Show create table ${TESTCS}.${TESTCL} in ${SQLHOST} SQL failed" && exit 1
        mysql -h"${SQLHOST}" -P"${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "select * from ${TESTCS}.${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOST} SQL failed" && exit 1
        mysql -h"${SQLHOST}" -P"${SQLPORT}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "drop database ${TESTCS};"
        test $? -ne 0 && echo "[ERROR] Drop ${TESTCS} in ${SQLHOST} SQL failed" && exit 1
        echo "Done"
    else
        echo "[WARN] Failed to find SQL HA group in ha_inst_group_list"
    fi

    # 等待一会再次检查实例组SQLID，避免前面的 DDL 未回放完成
    echo "Begin to check SQLID again"
    sleep 3
    sdb -e "var CUROPR = \"checkCluster\";var INSTANCEGROUP = \"${INSTANCEGROUP}\";var DATESTR = \"`date +%Y%m%d`\"" -f cluster_opr.js
    echo "Done"
fi