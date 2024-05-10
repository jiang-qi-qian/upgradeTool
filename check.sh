#!/bin/bash

echo "Begin to check backup dir UPGRADEBACKUPPATH"
DATESTR="`date +%Y%m%d`"
UPGRADEBACKUPPATH=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"UPGRADEBACKUPPATH\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
test ! -d "${UPGRADEBACKUPPATH}" && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
echo "Backup dir: ${UPGRADEBACKUPPATH}"
echo "Done"

INSTANCEGROUPARRAY=()
if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    echo "Begin to check instance group"
    SDBUSER=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SDBUSER\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SDBUSER from config.js" && exit 1
    SDBPASSWD=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SDBPASSWD\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SDBPASSWD from config.js" && exit 1
    ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" > /dev/null
    test $? -ne 0 && echo "[ERROR] Failed to get HASQL instanace group from ha_inst_group_list" && exit 1

    INSTANCEGROUPARRAY=(`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" | sed '1d' | awk '{print $1}' | uniq`)
    test $? -ne 0 && echo "[ERROR] Failed to get HASQL instance group name from ha_inst_group_list" && exit 1
    echo "HASQL instance group: ${INSTANCEGROUPARRAY[@]}"
    echo "Done"
else
    echo "[WARN] SequoiaSQL is not installed on this machine"
fi

GROUPSTR=""
for name in "${INSTANCEGROUPARRAY[@]}"
do
        if [ "${GROUPSTR}" == "" ]; then
                GROUPSTR="\"${name}\""
        else
                GROUPSTR="${GROUPSTR},\"${name}\""
        fi
done

sdb -e "var CUROPR = \"checkCluster\";var INSTANCEGROUPARRAY = [ ${GROUPSTR} ];var DATESTR = \"${DATESTR}\"" -f cluster_opr.js
sdb -e "var CUROPR = \"collect_new\";var INSTANCEGROUPARRAY = [ ${GROUPSTR} ];var DATESTR = \"${DATESTR}\"" -f cluster_opr.js

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
SDBVERSION=`sdb -v | head -n 1 | sed 's/SequoiaDB shell version: //'`
test $? -ne 0 && echo "[ERROR] Failed to get SequoiaDB version from sdb -v" && exit 1
sdb -e "var CUROPR = \"checkBasic\";var SDBVERSION = \"${SDBVERSION}\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js
echo "Done"

# 每个实例组都需要选两台机器测试同步
if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    echo "Begin to check local SQL"

    SQLUSER=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SQLUSER\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SQLUSER from config.js" && exit 1
    SQLPASSWD=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SQLPASSWD\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SQLPASSWD from config.js" && exit 1
    TESTCS=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"TESTCS\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get TESTCS from config.js" && exit 1
    TESTCL=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"TESTCL\";var DATESTR = \"${DATESTR}\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get TESTCL from config.js" && exit 1

    for instgroup in "${INSTANCEGROUPARRAY[@]}"
    do
        # 找出同一实例组下的两个 SQL 实例，检查是否同步
        echo "Begin to check instance group ${instgroup}"
        if [ "`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" --name="${instgroup}"`" != "" ]; then
            # 发现 ha_inst_group_list 打印间隔有问题，如果某些内容过长会导致 awk $x 出错，暂时没办法搞
            SQLHOSTARRAY=(`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" --name="${instgroup}" | tail -n 2 | awk '{print $3}'`)
            SQLPORTARRAY=(`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" --name="${instgroup}" | tail -n 2 | awk '{print $4}'`)
            test ${#SQLHOSTARRAY[*]} -ne 2 &&echo "[ERROR] Failed to get ${instgroup} HOST from ha_inst_group_list" && exit 1
            test ${#SQLHOSTARRAY[*]} -ne 2 &&echo "[ERROR] Failed to get ${instgroup} PORT from ha_inst_group_list" && exit 1
        else
            echo "[ERROR] Failed to find SQL HA group ${instgroup} in ha_inst_group_list"
            exit 1
        fi

        # 实例1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "create database ${TESTCS};"
        test $? -ne 0 && echo "[ERROR] Create database ${TESTCS} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "create table ${TESTCL}(uid int,name varchar(10),address varchar(10));"
        test $? -ne 0 && echo "[ERROR] Create table ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "alter table ${TESTCL} add index uid_index(uid);"
        test $? -ne 0 && echo "[ERROR] Alter table ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "insert into ${TESTCL} values(1,\"a\",\"广州\"),(2,\"A\",\"深圳\");"
        test $? -ne 0 && echo "[ERROR] Insert data to ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "update ${TESTCL} set address = \"东莞\" where uid =2;"
        test $? -ne 0 && echo "[ERROR] Update ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "delete from ${TESTCL} where uid=1;"
        test $? -ne 0 && echo "[ERROR] Delete ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1

        sleep 2

        # 实例2
        mysql -h"${SQLHOSTARRAY[1]}" -P "${SQLPORTARRAY[1]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "show create table ${TESTCS}.${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Show create table ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[1]}:${SQLPORTARRAY[1]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[1]}" -P "${SQLPORTARRAY[1]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "select * from ${TESTCS}.${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[1]}:${SQLPORTARRAY[1]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[1]}" -P "${SQLPORTARRAY[1]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "drop database ${TESTCS};"
        test $? -ne 0 && echo "[ERROR] Drop ${TESTCS} in ${SQLHOSTARRAY[1]}:${SQLPORTARRAY[1]} SQL failed" && exit 1
        echo "Done"
    done

    # 等待一会再次检查实例组SQLID，避免前面的 DDL 未回放完成
    echo "Begin to check SQLID again"
    sleep 3
    sdb -e "var CUROPR = \"checkCluster\";var INSTANCEGROUPARRAY = [ ${GROUPSTR} ];var DATESTR = \"`date +%Y%m%d`\"" -f cluster_opr.js
    echo "Done"
fi