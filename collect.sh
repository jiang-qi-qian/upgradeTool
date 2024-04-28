#!/bin/bash

# 获取实例组
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
# 保存集群升级前集合名，各个集合数据条数，域名和 HASQL 相关信息，用于升级后对比
sdb -e "var CUROPR = \"collect_old\";var INSTANCEGROUP = \"${INSTANCEGROUP}\";var DATESTR = \"`date +%Y%m%d`\"" -f cluster_opr.js
