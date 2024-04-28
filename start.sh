#!/bin/bash
# 启动本机器上所有 sdb 节点，mysql 或 mariadb 实例和 sdbcm

# 需要 root 权限
if [ `whoami` != "root" ]; then
    echo "[ERROR] The upgrade requires root privileges"
    exit 1
fi
echo "Running: sdbcmart"

if [ -f "/etc/default/sequoiadb" ]; then
    . /etc/default/sequoiadb
    SDB_INSTALL_DIR="${INSTALL_DIR}"
else
    echo "[ERROR] /etc/default/sequoiadb does not exists"
    exit 1
fi

${SDB_INSTALL_DIR}/bin/sdbcmart
rc=$?
test $rc -ne 0 && echo "[ERROR] sdbcmart error: $rc" && exit 1
echo "Done"
echo "----------------------------------------------------------"


# 循环看节点启动 1s ，循环 20s
echo "Waiting 20s for nodes start"
loop_count=0
while true
do
    run_count=`${SDB_INSTALL_DIR}/bin/sdblist -m run | sort`
    all_count=`${SDB_INSTALL_DIR}/bin/sdblist -m local | sort`
    if [ "${run_count}" == "${all_count}" ]; then
        break;
    else
        test $loop_count -eq 20 && echo "[ERROR] Waiting sdb nodes start timeout" && exit 1
        sleep 1
        ((loop_count++))
    fi
done
echo "Done"
echo "----------------------------------------------------------"

if [[ -f '/etc/default/sequoiasql-mysql' || -f '/etc/default/sequoiasql-mariadb' ]]; then
    test -f /etc/default/sequoiasql-mysql && . /etc/default/sequoiasql-mysql || . /etc/default/sequoiasql-mariadb
    SQL_INSTALL_DIR="${INSTALL_DIR}"
    echo "Running: sdb_sql_ctl status"
    ${SQL_INSTALL_DIR}/bin/sdb_sql_ctl status
    rc=$?
    test $rc -ne 0 && echo "[ERROR] sdb_sql_ctl status error: $rc" && exit 1
    echo "Done"
    echo "----------------------------------------------------------"

    echo "Running: sdb_sql_ctl startall"
    ${SQL_INSTALL_DIR}/bin/sdb_sql_ctl startall
    rc=$?
    test $rc -ne 0 && echo "[ERROR] sdb_sql_ctl startall error: $rc" && exit 1
    echo "Done"
    echo "----------------------------------------------------------"

    echo "Running: sdb_sql_ctl status"
    ${SQL_INSTALL_DIR}/bin/sdb_sql_ctl status
    rc=$?
    test $rc -ne 0 && echo "[ERROR] sdb_sql_ctl status error: $rc" && exit 1
    echo "Done"
else 
    echo "[WARN] SequoiaSQL is not installed on this machine"
fi
echo "----------------------------------------------------------"

echo "Start success"