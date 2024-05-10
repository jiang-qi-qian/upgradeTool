- 配置在 config.js 文件中
- 工具限制
    - 自动获取每个SQL实例组下的两个实例做测试（实例组里必须有两个及以上的实例）
    - 如果使用了 SQL ，所有只使用一次的工具需要在有 SQL 和 SDB 的机器执行
    - 使用了当天时间作为目录名，不建议跨天操作；如果需要跨天操作，需要修改备份目录名为当天日期

- 升级前
                        刷盘，停止业务
    collect.sh          (sdbadmin)选择一台同时拥有 SDB 和 SQL 的机器 host1 执行，收集升级前集群信息
    stop.sh             (sdbadmin)所有机器执行，停止所有 SQL 实例，SDB 节点 和 sdbcm
    upgrade_backup.sh   (sdbadmin)所有机器执行备份，可并发

- 升级              
    upgrade_install.sh  (root)所有机器执行升级，可并发
    start.sh            (root)所有机器执行，检查并启动所有 SQL 实例，SDB 节点 和 sdbcm
                        人工关闭回收站 db.getRecycleBin().disable()
                        人工索引升级
- 升级校验
    check.sh            (sdbadmin)选择一台同时拥有 SDB 和 SQL 的机器 host1 执行，校验升级前后信息是否一致
    reelect.sh          (sdbadmin)重新选主，目前是固定脚本（结果不太好看，建议做巡检看）

- 回滚              
    stop.sh             (sdbadmin)需要回滚的机器上执行，停止所有 SQL 实例，SDB 节点 和 sdbcm
    rollback_backup.sh  (sdbadmin)需要回滚的机器上执行备份，可并发
    rollback_install.sh (root)需要回滚的机器上执行升级，可并发
    start.sh            (root)所有机器执行，检查并启动所有 SQL 实例，SDB 节点 和 sdbcm
    rollback_del.sh     (sdbadmin)一台机器执行，删除升级后数据节点中多余的系统表，防止下次升级失败

- 回滚校验
    check.sh            (sdbadmin)选择一台同时拥有 SDB 和 SQL 的机器 host1 执行，校验回退后与升级前信息是否一致
                            因为使用了 SQL 语句进行测试，此时 HASQL 相关校验不通过是正常的，不通过项为:
                            - 表中记录数变多，且变多的记录内容为测试语句: HALock, HAPendingObject, HAInstanceObjectState, HAObjectState, HASQLLog
    reelect.sh          (sdbadmin)重新选主，目前是固定脚本，需要根据客户修改，后续会改进为通用工具


- 未修复问题
    - 表现:
        ha_inst_group_list 在不同版本下会在使用 --name 或不使用 --name 出现格式超长的问题，如果同一列长字符串比最短字符串长 >= 4 个字符，会导致两列在长字符串的行连在一起
    - 影响范围:
        工具不可用
    - 检查方法:
        在使用工具前用 ha_inst_group_list 和 ha_inst_group_list --name=xxx 检查是否有上述情况
    - 后续解决方案:
        修复 ha_inst_group_list 并打包到工具中，使用新版本的 ha_inst_group_list 工具