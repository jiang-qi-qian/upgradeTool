#!/bin/bash

echo "Begin to check backup dir UPGRADEBACKUPPATH"
UPGRADEBACKUPPATH=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"UPGRADEBACKUPPATH\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
test ! -d "${UPGRADEBACKUPPATH}" && echo "[ERROR] Failed to get UPGRADEBACKUPPATH from config.js" && exit 1
echo "Backup dir: ${UPGRADEBACKUPPATH}"
echo "Done"

INSTANCEGROUPARRAY=()
if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    echo "Begin to check instance group"
    SDBUSER=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SDBUSER\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SDBUSER from config.js" && exit 1
    SDBPASSWD=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SDBPASSWD\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SDBPASSWD from config.js" && exit 1

    ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" > /dev/null
    rc=$?
    # 222 错误是不存在实例组，忽略
    test $? -ne 0 && $rc -ne 222 && echo "[ERROR] Failed to get HASQL instanace group from ha_inst_group_list" && exit 1

    if [ $rc -eq 0 ]; then
        INSTANCEGROUPARRAY=(`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" | sed '1d' | awk '{print $1}' | uniq`)
        test $? -ne 0 && echo "[ERROR] Failed to get HASQL instance group name from ha_inst_group_list" && exit 1
        echo "  HASQL instance group: ${INSTANCEGROUPARRAY[@]}"
    else # 222
        INSTANCEGROUPARRAY=()
        echo "  No HASQL instance group in current cluster"
    fi
    echo "Done"
else
    echo "[WARNING] SequoiaSQL is not installed on this machine"
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

sdb -e "var CUROPR = \"checkCluster\";var INSTANCEGROUPARRAY = [ ${GROUPSTR} ]" -f cluster_opr.js
sdb -e "var CUROPR = \"collect_new\";var INSTANCEGROUPARRAY = [ ${GROUPSTR} ]" -f cluster_opr.js

SKIPCHECK=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SKIPCHECK\"" -f cluster_opr.js)
test $? -ne 0 && echo "[ERROR] Failed to get SKIPCHECK from config.js" && exit 1
# 如果是滚动升级，根据 config.js 的参数跳过检查
if [ "${SKIPCHECK}" == "true" ]; then
    echo "[WARNING] Skip checking dynamic information"
elif [ "${SKIPCHECK}" == "false" ]; then
    echo "Begin to diff backup file"
    diff "${UPGRADEBACKUPPATH}/snapshot_cl_old.info" "${UPGRADEBACKUPPATH}/snapshot_cl_new.info"
    test $? -ne 0 && echo "[ERROR] Diff file ${UPGRADEBACKUPPATH}/snapshot_cl_old.info ${UPGRADEBACKUPPATH}/snapshot_cl_new.info failed"
    diff "${UPGRADEBACKUPPATH}/domain_name_old.info" "${UPGRADEBACKUPPATH}/domain_name_new.info"
    test $? -ne 0 && echo "[ERROR] Diff file ${UPGRADEBACKUPPATH}/domain_name_old.info ${UPGRADEBACKUPPATH}/domain_name_new.info failed"
    if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
        # 有实例组才对比实例组信息
        if [ "${#INSTANCEGROUPARRAY[*]}" != "0" ]; then
            diff "${UPGRADEBACKUPPATH}/hasql_old.info" "${UPGRADEBACKUPPATH}/hasql_new.info"
            test $? -ne 0 && echo "[ERROR] Diff file ${UPGRADEBACKUPPATH}/hasql_old.info ${UPGRADEBACKUPPATH}/hasql_new.info failed"
        fi
    fi
    echo "Done"
else
    echo "[ERROR] Unknown SKIPCHECK \"${SKIPCHECK}\" in config.js" && exit 1
fi

echo "Begin to check SDB"
SDBVERSION=`sdb -v | head -n 1 | sed 's/SequoiaDB shell version: //'`
test $? -ne 0 && echo "[ERROR] Failed to get SequoiaDB version from sdb -v" && exit 1
# sdb 的检查不做 DDL
sdb -e "var CUROPR = \"checkBasic\";var SDBVERSION = \"${SDBVERSION}\"" -f cluster_opr.js
echo "Done"

# 实例组同步测试
if [ "${#INSTANCEGROUPARRAY[*]}" == "0" ]; then
    echo "There is no need to check HASQL instance group, because instance group array is empty"
fi

if [[ ( -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ) && "${#INSTANCEGROUPARRAY[*]}" != "0" ]]; then
    echo "Begin to check local SQL"

    SQLUSER=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SQLUSER\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SQLUSER from config.js" && exit 1
    SQLPASSWD=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"SQLPASSWD\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get SQLPASSWD from config.js" && exit 1
    TESTCS=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"TESTCS\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get TESTCS from config.js" && exit 1
    TESTCL=$(sdb -e "var CUROPR = \"getArg\";var ARGNAME = \"TESTCL\"" -f cluster_opr.js)
    test $? -ne 0 && echo "[ERROR] Failed to get TESTCL from config.js" && exit 1
    TESTCS="${TESTCS}_sql"
    TESTCL="${TESTCL}_sql"

    for instgroup in "${INSTANCEGROUPARRAY[@]}"
    do
        # 找出同一实例组下的两个 SQL 实例，检查是否同步
        # 如果只有一个实例组，则只做基本测试，不做同步检查
        echo "Begin to check instance group ${instgroup}"
        if [ "`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" --name="${instgroup}"`" != "" ]; then
            # 发现 ha_inst_group_list 打印间隔有问题，如果某些内容过长会导致 awk $x 出错，暂时没办法搞
            SQLHOSTARRAY=(`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" --name="${instgroup}" | sed -n '2,$p' | sort | tail -n 2 | awk '{print $3}'`)
            SQLPORTARRAY=(`ha_inst_group_list -u"${SDBUSER}" -p"${SDBPASSWD}" --name="${instgroup}" | sed -n '2,$p' | sort | tail -n 2 | awk '{print $4}'`)
            
            test ${#SQLHOSTARRAY[*]} -ne ${#SQLPORTARRAY[*]} && echo "[ERROR] Failed to get ${instgroup} HOST from ha_inst_group_list" && exit 1
            ONLY_ONE_INSTANCE="false"
            if [ "${#SQLHOSTARRAY[*]}" != "2" ]; then
                ONLY_ONE_INSTANCE="true"
            fi
        else
            echo "[ERROR] Failed to find SQL HA group ${instgroup} in ha_inst_group_list"
            exit 1
        fi

        # 实例1
        # 不做 DDL
        # mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "create database ${TESTCS};"
        # test $? -ne 0 && echo "[ERROR] Create database ${TESTCS} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        # mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "create table ${TESTCL}(uid int,name varchar(10),address varchar(10));"
        # test $? -ne 0 && echo "[ERROR] Create table ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        # mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "alter table ${TESTCL} add index uid_index(uid);"
        # test $? -ne 0 && echo "[ERROR] Alter table ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "insert into ${TESTCL} values(1,\"a\",\"广州\"),(2,\"A\",\"深圳\");"
        test $? -ne 0 && echo "[ERROR] Insert data to ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "update ${TESTCL} set address = \"东莞\" where uid =2;"
        test $? -ne 0 && echo "[ERROR] Update ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "delete from ${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Delete ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1
        mysql -h"${SQLHOSTARRAY[0]}" -P "${SQLPORTARRAY[0]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -D "${TESTCS}" -e "select * from ${TESTCL};"
        test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[0]}:${SQLPORTARRAY[0]} SQL failed" && exit 1

        sleep 2

        if [ "${ONLY_ONE_INSTANCE}" == "false" ]; then
            # 实例2
            echo "Begin to check another instance in the instance group ${instgroup}"
            mysql -h"${SQLHOSTARRAY[1]}" -P "${SQLPORTARRAY[1]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "show create table ${TESTCS}.${TESTCL};"
            test $? -ne 0 && echo "[ERROR] Show create table ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[1]}:${SQLPORTARRAY[1]} SQL failed" && exit 1
            mysql -h"${SQLHOSTARRAY[1]}" -P "${SQLPORTARRAY[1]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "select * from ${TESTCS}.${TESTCL};"
            test $? -ne 0 && echo "[ERROR] Select ${TESTCS}.${TESTCL} in ${SQLHOSTARRAY[1]}:${SQLPORTARRAY[1]} SQL failed" && exit 1
            # 不做 DDL
            # mysql -h"${SQLHOSTARRAY[1]}" -P "${SQLPORTARRAY[1]}" -u "${SQLUSER}" -p"${SQLPASSWD}" -e "drop database ${TESTCS};"
            # test $? -ne 0 && echo "[ERROR] Drop ${TESTCS} in ${SQLHOSTARRAY[1]}:${SQLPORTARRAY[1]} SQL failed" && exit 1
        else
            echo "[INFO] There is only one instance in the instance group ${instgroup}"
        fi
        echo "Done"
    done

    # 等待一会再次检查实例组SQLID，避免前面的 DDL 未回放完成（前面DDL已注释，此处可不等待）
    echo "Begin to check SQLID again"
    sleep 3
    sdb -e "var CUROPR = \"checkCluster\";var INSTANCEGROUPARRAY = [ ${GROUPSTR} ]" -f cluster_opr.js
    echo "Done"
fi
