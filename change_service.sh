#!/bin/bash
# 设置系统服务的超时时间(单位为秒)
TIMEOUTSEC=1300

# 需要 root 权限
if [ `whoami` != "root" ]; then
    echo "[ERROR] Change service config requires root privileges"
    exit 1
fi

echo "Begin to change service config, TimeoutSes is ${TIMEOUTSEC}s"

# 获取系统服务文件路径
SERVICEFILE=`systemctl status sdbcm | grep ' loaded ' | sed 's#[^(]*(\([^;]*\);.*#\1#'`
test $? -ne 0 && echo "[ERROR] Failed to get system service config file from systemctl" && exit 1
test ! -f "${SERVICEFILE}" && echo "[ERROR] System service config file ${SERVICEFILE} does not exist" && exit 1
echo "Service config file is: ${SERVICEFILE}"


if [ "`cat ${SERVICEFILE}` | grep 'TimeoutSec='" != "" ]; then
    # 如果超时时间已经存在，则直接修改
    echo "TimeoutSec is already in file ${SERVICEFILE}, begin to change it"
    sed -i "s#^ *\(TimeoutSec=\).*#\1${TIMEOUTSEC}#" "${SERVICEFILE}"
    test $? -ne 0 && echo "[ERROR] Failed to change TimeoutSes in the file ${SERVICEFILE}" && exit 1
    echo "The TimeoutSes is successfully change in the file ${SERVICEFILE}"
else
    # 不存在则在系统服务中增加超时时间
    # 获取插入的行号
    LINE=`cat -n ${SERVICEFILE} | grep KillMode | awk '{print $1}'`
    test $? -ne 0 && echo "[ERROR] Failed to check file ${SERVICEFILE}" && exit 1
    test "${LINE}" == "" && echo "[ERROR] Failed to get KillMode line from file ${SERVICEFILE}" && exit 1

    # 插入超时时间配置
    sed -i -e "${LINE}a\TimeoutSec=${TIMEOUTSEC}" "${SERVICEFILE}"
    test $? -ne 0 && echo "[ERROR] Failed to add TimeoutSes into the file ${SERVICEFILE}" && exit 1
    echo "The TimeoutSes is successfully insert into the file ${SERVICEFILE}"
fi

# 重新加载系统服务
systemctl daemon-reload
echo "Begin to reload system service"
test $? -ne 0 && echo "[ERROR] Failed to exec systemctl daemon-reload" && exit 1

# 查看系统服务状态，没有警告则修改成功
if [ "`systemctl status sdbcm | grep 'systemctl daemon-reload'`" == "" ]; then
    echo "Done"
    echo "There is file ${SERVICEFILE}:"
    cat "${SERVICEFILE}"
else
    echo "[ERROR] Failed to check systemctl status sdbcm, please check it again"
    exit 1
fi

exit 0