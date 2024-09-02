import("config.js");

/* 数据库登入用户名定义 */
if ( typeof(SDBUSER) != "string" ) { SDBUSER = "sdbadmin"; }
/* 数据库登入密码定义 */
if ( typeof(SDBPASSWD) != "string" ) { SDBPASSWD = "sdbadmin"; }
/* 当前操作" */
if ( typeof(CUROPR) == "undefined" ) { CUROPR = "init"; }
/* coord 节点主机名 */
if ( typeof(COORDADDR) == "undefined" ) { COORDADDR = "localhost"; }
/* coord 节点端口号 */
if ( typeof(COORDSVC) == "undefined" ) { COORDSVC = 11810; }
/* 所有机器都可用的备份目录 */
if ( typeof(UPGRADEBACKUPPATH) == "undefined" ) { UPGRADEBACKUPPATH = "/sdbdata/data01/upgradebackup"; }
/* 操作时间 */
if ( typeof(DATESTR) == "undefined" ) { var a = new Date(); DATESTR = a.getFullYear() + "_" + (a.getMonth() + 1) + "_" + a.getDate(); }

UPGRADEBACKUPPATH = UPGRADEBACKUPPATH + "/" + DATESTR;
// 收集 $SNAPSHOT_CL 中 Name,TotalRecords和TotalLobs 字段
var SNAPSHOTCLFILE = UPGRADEBACKUPPATH + '/snapshot_cl_old.info';
// 记录集群中的域信息
var DOMAINFILE = UPGRADEBACKUPPATH + '/domain_name_old.info';
// 记录HASQL状态
var HASQLFILE = UPGRADEBACKUPPATH + '/hasql_old.info';
// 记录 sdbcm 配置
var SDBCMFILE = UPGRADEBACKUPPATH + '/all_sdbcm.conf';

// 升级后验证
var SNAPSHOTCLFILE_NEW = UPGRADEBACKUPPATH + '/snapshot_cl_new.info';
var DOMAINFILE_NEW = UPGRADEBACKUPPATH + '/domain_name_new.info';
var HASQLFILE_NEW = UPGRADEBACKUPPATH + '/hasql_new.info';
var LOBFILE = "config.js"

/* *****************************************************************************
@discription: 校验参数正确性
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function checkArgs() {
    // check connect sdb
    try {
        var db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
        db.close();
    } catch (error) {
        println( "Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")" );
        return false;
    }
    return true;
}

/* *****************************************************************************
@discription: 获取 $SNAPSHOT_CL 中的 Name , TotalRecords 和 TotalLobs 并写入文件
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function saveSNAPSHOTCLInfo(filename) {
    var db;
    var file;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    if (File.exist(filename)) {
        try {
            File.remove(filename);
        } catch (error) {
            println("Failed to clean " + filename + ", error info: " + error + "(" + getLastErrMsg() + ")");
            db.close();
            return false;
        }
    }

    try {
        file = new File(filename);
    } catch(error) {
        println("Create or open file[" + filename + "] failed: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }

    try {
        var cursor = db.exec('select t2.Name,t2.TotalRecords,t2.TotalLobs from (select t.Name,t.Details.TotalRecords as TotalRecords,t.Details.TotalLobs as TotalLobs from (select Name,Details from $SNAPSHOT_CL split by Details) as t ) as t2 order by t2.Name,t2.TotalRecords,t2.TotalLobs');
        while(cursor.next()) {
            let current = cursor.current().toObj();
            // 拼成一行写入， diff 可以看到哪些表不对
            file.write(current.Name + " TotalRecords: " + current.TotalRecords + " TotalLobs: " + current.TotalLobs + "\n");
        }
    } catch (error) {
        println("Write $SNAPSHOT_CL info to file[" + filename + "] failed, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        file.close();
        if (cursor != null) {
            cursor.close();
        }
        db.close();
    }
    return true;
}

/* *****************************************************************************
@discription: 获取全部域信息并写入文件
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function saveDomainInfo(filename) {
    var db;
    var file;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    if (File.exist(filename)) {
        try {
            File.remove(filename);
        } catch (error) {
            println("Failed to clean " + filename + ", error info: " + error + "(" + getLastErrMsg() + ")");
            db.close();
            return false;
        }
    }

    try {
        file = new File(filename);
    } catch(error) {
        println("Create or open file[" + filename + "] failed: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }

    try {
        var cursor = db.listDomains({},{},{Name:1})
        while(cursor.next()) {
            file.write(cursor.current().toString() + "\n");
        }
    } catch (error) {
        println("Write domain info to file[" + filename + "] failed, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        file.close();
        if (cursor != null) {
            cursor.close();
        }
        db.close();
    }
    return true;
}

/* *****************************************************************************
@discription: 获取HASQL实例组表的信息并写入文件
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function saveHASQL(filename) {
    if (INSTANCEGROUPARRAY.length == 0) {
        println("There is no need to collect HASQL information, because instance group array is empty");
        return true;
    }

    var db;
    var file;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    if (File.exist(filename)) {
        try {
            File.remove(filename);
        } catch (error) {
            println("Failed to clean " + filename + ", error info: " + error + "(" + getLastErrMsg() + ")");
            db.close();
            return false;
        }
    }

    try {
        file = new File(filename);
    } catch(error) {
        println("Create or open file[" + filename + "] failed: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }

    try {
        var cursor;
        for (let i = 0; i < INSTANCEGROUPARRAY.length; i++) {
            var cmd = "db.HAInstanceGroup_" + INSTANCEGROUPARRAY[i] + ".HASQLLog.find().sort({SQLID:1})";
            cursor = eval(cmd);
            while(cursor.next()) {
                file.write(cursor.current().toString() + "\n");
            }
            cursor.close();
        }
    } catch (error) {
        println("Write HASQL info to file[" + filename + "] failed, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        if (null != cursor) {
            cursor.close();
        }
        file.close();
        db.close();
    }
    return true;
}

/* *****************************************************************************
@discription: 检查集群是否存在任务
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function checkTasks() {
    var db;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    try {
        var size = db.listTasks().size();
        if (size != 0) {
            println("There are still exist tasks in the current cluster, please confirm with db.listTasks()");
            return false;
        }
    } catch (error) {
        println("Failed to get db.listTasks().size(), error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        db.close();
    }
    return true;
}

/* *****************************************************************************
@discription: 检查存在差异的主备节点
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function checkLSN() {
    var db;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    try {
        var size = db.exec('select DiffLSNWithPrimary from $SNAPSHOT_HEALTH where DiffLSNWithPrimary > ' + LSNDIFF).size();
        if (size != 0) {
            println("There are still exist DiffLSNWithPrimary node in the current cluster, please confirm with $SNAPSHOT_HEALTH");
            return false;
        }
    } catch (error) {
        println("Failed to get $SNAPSHOT_HEALTH, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        db.close();
    }
    return true;
}

/* *****************************************************************************
@discription: 检查存在事务列表 SDB_LIST_TRANSACTIONS，要求为空
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function checkTransactions() {
    var db;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    try {
        var size = db.list(SDB_LIST_TRANSACTIONS).size();
        if (size != 0) {
            println("There are still exist TRANSACTIONS in the current cluster, please confirm with \"db.list(SDB_LIST_TRANSACTIONS)\"");
            return false;
        }
    } catch (error) {
        println("Failed to get \"db.list(SDB_LIST_TRANSACTIONS)\", error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        db.close();
    }
    return true;
}

/* *****************************************************************************
@discription: 检查，并收集集群升级前信息（文件名）
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function collectInfo_old() {
    if (!File.exist(UPGRADEBACKUPPATH)) {
        try {
            File.mkdir(UPGRADEBACKUPPATH);
        } catch (error) {
            println("Failed to create " + UPGRADEBACKUPPATH + ", error info: " + error + "(" + getLastErrMsg() + ")");
            return false;
        }
    }

    println("   Begin to check Tasks");
    if (checkTasks()) {
        println("   Done");
    } else {
        return false;
    }

    println("   Begin to check DiffLSNWithPrimary");
    if (checkLSN()) {
        println("   Done");
    } else {
        return false;
    }

    println("   Begin to check SDB_LIST_TRANSACTIONS");
    if (checkTransactions()) {
        println("   Done");
    } else {
        return false;
    }

    println("   Begin to save $SNAPSHOT_CL info");
    if (saveSNAPSHOTCLInfo(SNAPSHOTCLFILE)) {
        println("   Done");
    } else {
        return false;
    }

    println("   Begin to save Domain info");
    if (saveDomainInfo(DOMAINFILE)) {
        println("   Done");
    } else {
        return false;
    }

    println("   Begin to save HASQL info");
    if (saveHASQL(HASQLFILE)) {
        println("   Done");
    } else {
        return false;
    }

    return true;
}

/* *****************************************************************************
@discription: 收集升级后或回退后的信息（文件名）
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function collectInfo_new() {
    println("   Begin to save $SNAPSHOT_CL info");
    if (saveSNAPSHOTCLInfo(SNAPSHOTCLFILE_NEW)) {
        println("   Done");
    } else {
        return false;
    }

    println("   Begin to save domain info");
    if (saveDomainInfo(DOMAINFILE_NEW)) {
        println("   Done");
    } else {
        return false;
    }

    println("   Begin to save HASQL");
    if (saveHASQL(HASQLFILE_NEW)) {
        println("   Done");
    } else {
        return false;
    }

    return true;
}

/* *****************************************************************************
@discription: 检查升级后的集群
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function checkCluster() {
    var db;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    println("   Begin to check $SNAPSHOT_HEALTH");
    try {
        var cursor = db.exec('select count(1) as count from $SNAPSHOT_HEALTH where Status <> "Normal"');
        if (cursor.current().toObj().count != 0) {
            println("There are abnormal nodes in the cluster");
            return false;
        }
        cursor.close();
    } catch (error) {
        println("Failed to check sdb cluster $SNAPSHOT_HEALTH, error info: " + error + "(" + getLastErrMsg() + ")");
        if (null != cursor) {
            cursor.close();
        }
        db.close();
        return false;
    }
    println("   Done");
    println("   Begin to check SDB_SNAP_DATABASE");
    try {
        var cursor = db.snapshot(SDB_SNAP_DATABASE,{},{"ErrNodes":1});
        if (cursor.current().toObj().ErrNodes.length != 0) {
            println("There are ErrNodes in the cluster");
            return false;
        }
        cursor.close();
    } catch (error) {
        println("   Failed to check sdb cluster SDB_SNAP_DATABASE, error info: " + error + "(" + getLastErrMsg() + ")");
        if (null != cursor) {
            cursor.close();
        }
        return false;
    }
    println("   Done");
    if (INSTANCEGROUPARRAY.length != 0) {
        println("   Begin to check HASQL");
        try {
            var cursor;
            for (let i = 0; i < INSTANCEGROUPARRAY.length; i++) {
                var cursor = db.exec('select max(SQLID) as max_id,min(SQLID) as min_id from HAInstanceGroup_' + INSTANCEGROUPARRAY[i] + '.HAInstanceState');
                while(cursor.next()) {
                    var current = cursor.current().toObj();
                    if (current.max_id - current.min_id > HASQLIDDIFF) {
                        println("There are different SQLID more than " + HASQLIDDIFF + " in the HAInstanceGroup_" + INSTANCEGROUPARRAY[i] + ".HAInstanceState");
                        cursor.close();
                        db.close();
                        return false;
                    }
                }
                cursor.close();
            }
        } catch (error) {
            println("Failed to check SQLID in the HAInstanceGroup");
            if (null != cursor) {
                cursor.close();
            }
            return false;
        } finally {
            db.close();
        }
        println("   Done");
    }
    println("   Begin to check DiffLSNWithPrimary");
    if (checkLSN()) {
        println("   Done");
    } else {
        return false;
    }
    return true;
}

/* *****************************************************************************
@discription: 获取所有数据节点的主机名和端口号，并返回一个对象数组 
@author: Qiqian Jiang
@return: String Array
***************************************************************************** */
function getAllDataGroupsHostAndPort() {
    var db;
    var dataArray = [];
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        throw error;
    }

    try {
        var cursor = db.exec('select GroupName,HostName,ServiceName from $SNAPSHOT_DB where GroupName <> "SYSCatalogGroup" and GroupName <> "SYSCoord" order by GroupName');
        while (cursor.next()) {
            dataArray.push(cursor.current().toObj());
        }
    } catch (error) {
        println("Failed to get data groups from $LIST_GROUP, error info: " + error + "(" + getLastErrMsg() + ")");
        throw error;
    } finally {
        if (null != cursor) {
            cursor.close();
        }
        db.close();
    }
    return dataArray;
}

/* *****************************************************************************
@discription: 获取所有数据组名，并返回一个数组
@author: Qiqian Jiang
@return: String Array
***************************************************************************** */
function getAllDataGroupsName() {
    var db;
    var dataArray = [];
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        throw error;
    }

    try {
        var cursor = db.exec('select GroupName from $LIST_GROUP where GroupName <> "SYSCatalogGroup" and GroupName <> "SYSCoord" order by GroupName');
        while (cursor.next()) {
            dataArray.push(cursor.current().toObj().GroupName);
        }
    } catch (error) {
        println("Failed to get data groups from $LIST_GROUP, error info: " + error + "(" + getLastErrMsg() + ")");
        throw error;
    } finally {
        if (null != cursor) {
            cursor.close();
        }
        db.close();
    }
    return dataArray;
}

/* *****************************************************************************
@discription: 校验集群状态，以及增删改查等基本能力
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function checkBasic() {
    var db;
    var dataArray;
    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    try {
        dataArray = getAllDataGroupsName();
    } catch (error) {
        println("Failed to check sdb basic ability");
        return false;
    }
    
    // 不创建 Domain
    // println("Begin to create domain [" + TESTDOMAIN + "]");
    // try {
    //     db.createDomain( TESTDOMAIN, dataArray, { "AutoSplit": true } );
    // } catch (error) {
    //     println("Failed to create domain [" + TESTDOMAIN +"], error info: " + error + "(" + getLastErrMsg() + ")");
    //     db.close();
    //     return false;
    // }
    // println("Done");
    println("   Begin to insert data");
    try {
        for(var num = 1; num < 1000; num++){
            db.getCS(TESTCS).getCL(TESTCL).insert({"id":num,"name":num+""})
        }
    } catch (error) {
        println("Failed to insert data to [" + TESTCS + "." + TESTCL + "], error info: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }
    println("   Done");
    println("   Begin to check find,update and remove");
    try {
        var cursor=db.getCS(TESTCS).getCL(TESTCL).find();
        cursor.close();
        db.getCS(TESTCS).getCL(TESTCL).update({$set:{"name":"a1"}},{"id":1});
        db.getCS(TESTCS).getCL(TESTCL).remove();
    } catch (error) {
        println("Failed to check find,update and remove, error info: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }
    println("   Done");
    println("   Begin to insert LOB");
    try {
        for(var num = 1; num < 100; num++){
            db.getCS(TESTCS).getCL(TESTCL).putLob(LOBFILE);
        }
    } catch (error) {
        println("Failed to put LOB to [" + TESTCS + "." + TESTCL + "], error info: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }
    println("   Done");
    println("   Begin to check LOB find");
    try {
        var cursor = db.getCS(TESTCS).getCL(TESTCL).listLobs();
        cursor.close();
    } catch (error) {
        println("Failed to check LOB find, error info: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }
    println("   Done");
    return true;
    // 不做DDL
    // println("Begin to remove cs [" + TESTCS + "]");
    // try {
    //     var VERSIONARRAY = SDBVERSION.split('.');
    //     if (VERSIONARRAY[0] >= 5 && VERSIONARRAY[1] >= 8 && VERSIONARRAY[2] >= 2) {
    //         db.dropCS(TESTCS,{"SkipRecycleBin":true});
    //     } else {
    //         db.dropCS(TESTCS);
    //     }
    // } catch (error) {
    //     println("Failed to remove cs [" + TESTCS + "], error info: " + error + "(" + getLastErrMsg() + ")");
    //     db.close();
    //     return false;
    // }
    // println("Done");
    // println("Begin to remove domain [" + TESTDOMAIN + "]");
    // try {
    //     db.dropDomain(TESTDOMAIN);
    // } catch (error) {
    //     println("Failed to remove cl [" + TESTDOMAIN + "], error info: " + error + "(" + getLastErrMsg() + ")");
    //     db.close();
    //     return false;
    // } finally {
    //     db.close();
    // }
    // println("Done");
}

/* *****************************************************************************
@discription: 连接所有数据节点，删除 SYSLOCAL.SYSRECYCLEITEMS 表
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function dropSYSRECYCLEITEMS() {
    var db;

    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    try {
        var cursor = db.exec('select GroupName,ServiceName,HostName from $SNAPSHOT_SYSTEM where GroupName <> "SYSCoord" and GroupName <> "SYSCatalogGroup" order by GroupName');
        while(cursor.next()) {
            var current = cursor.current().toObj();
            try {
                println("Drop " + current.GroupName + " SYSRECYCLEITEMS on " + current.HostName + ":" + current.ServiceName);
                var sub_db = new Sdb(current.HostName, current.ServiceName, SDBUSER, SDBPASSWD);
                sub_db.SYSLOCAL.dropCL('SYSRECYCLEITEMS');
            } catch (error) {
                println("Failed to drop SYSRECYCLEITEMS, error info: " + error + "(" + getLastErrMsg() + ")");
                return false;
            } finally {
                sub_db.close();
            }
        }
    } catch (error) {
        println("Failed to get $SNAPSHOT_SYSTEM, error info: " + error + "(" + getLastErrMsg() + ")");
        if (null != cursor) {
            cursor.close();
        }
        db.close();
        return false;
    }
    return true;
}

/* *****************************************************************************
@discription: 创建测试用的表
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function createTestCSCL() {
    var db;

    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    println("   Begin to create cs [" + TESTCS + "]");
    try {
        db.createCS(TESTCS);
    } catch (error) {
        if (-33 != error) {
            println("   Failed to create cs [" + TESTCS + "], error info: " + error + "(" + getLastErrMsg() + ")");
            db.close();
            return false;
        } else {
            println("   TESTCS [" + TESTCS + "] is already exists");
        }
    }
    println("   Done");
    println("   Begin to create cl [" + TESTCL + "]");
    try {
        db.getCS(TESTCS).createCL(TESTCL, { "ShardingKey": { "_id": 1 }, "ShardingType": "hash", "ReplSize": -1, "Compressed": true, "CompressionType": "lzw", "AutoSplit": true, "EnsureShardingIndex": false } );
    } catch (error) {
        if (-22 != error) {
            println("   Failed to create cl [" + TESTCS + "." + TESTCL + "], error info: " + error + "(" + getLastErrMsg() + ")");
            db.close();
            return false;
        } else {
            println("   TESTCL [" + TESTCL + "] is already exists");
        }
    }
    println("   Done");
    return true;
}

/* *****************************************************************************
@discription: 获取索引数量（所有副本总数）
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function getIndexCount() {
    var db;

    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    try {
        var count = db.exec('select sum(t1.Details.Indexes) as totalIndexesCount from (select Details from $SNAPSHOT_CL split by Details) as t1').current().toObj().totalIndexesCount;
        println("   Indexes count: " + count);
    } catch (error) {
        println("Failed to get indexes count from $SNAPSHOT_CL, error info: " + error + "(" + getLastErrMsg() + ")");
        db.close();
        return false;
    }
    return true;
}

/* *****************************************************************************
@discription: 升级前修改 sdbcm AutoStart 配置为 false
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function changeSDBCM() {
    var oma;
    var db;
    var file;

    if (true == KEEPSDBCMCONF) {
        if (File.exist(SDBCMFILE)) {
            try {
                File.remove(SDBCMFILE);
            } catch (error) {
                println("Failed to clean " + SDBCMFILE + ", error info: " + error + "(" + getLastErrMsg() + ")");
                return false;
            }
        }
    
        try {
            file = new File(SDBCMFILE);
        } catch(error) {
            println("Create or open file[" + SDBCMFILE + "] failed: " + error + "(" + getLastErrMsg() + ")");
            return false;
        }
    }

    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    // 获取主机名列表
    var hostArray = [];
    try {
        var cursor = db.exec('select HostName from $SNAPSHOT_SYSTEM group by HostName');
        while(cursor.next()) {
            hostArray.push(cursor.current().toObj().HostName);
        }
        cursor.close();
    } catch (error) {
        println("Failed to get HostName count from $SNAPSHOT_SYSTEM, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        db.close();
    }

    // 获取本地 Oma
    try {
        oma = new Oma();
    } catch (error) {
        println("Failed to get Oma, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    // 逐个修改 sdbcm 配置
    var allCmConf = [];
    for (let i = 0; i < hostArray.length; i++) {
        var hostName = hostArray[i];
        // 获取 sdbcm 端口号
        var port = oma.getAOmaSvcName(hostName);
        // sdbcm.conf 的文件路径
        var sdbcmFile;
        try {
            // 通过远程 oma 获取 sdbcm.conf 的文件路径
            var remoteOma = new Oma(hostName, port);
            sdbcmFile = remoteOma.getOmaConfigFile();
            remoteOma.close();
        } catch (error) {
            println("Failed to get sdbcm.conf path from oma on " + hostName + ":" + port + ", error info: " + error + "(" + getLastErrMsg() + ")");
            oma.close();
            return false;
        }
        // 连接 remote
        var remoteObj;
        try {
            remoteObj = new Remote(hostName, port);
        } catch (error) {
            println("Failed to get remoteObj on " + hostName + ":" + port + ", error info: " + error + "(" + getLastErrMsg() + ")");
            oma.close();
            return false;
        }

        try {
            var ini = remoteObj.getIniFile(sdbcmFile, SDB_INIFILE_EQUALSIGN | SDB_INIFILE_STRICTMODE | SDB_INIFILE_HASHMARK )
            // 如果需要保持 sdbcm 配置，需要在本地用文件记住每台机器的配置
            if (true == KEEPSDBCMCONF) {
                allCmConf.push({"HostName":hostName, "AutoStart":ini.getValue("AutoStart")});
            }
            ini.setValue("AutoStart","false");
            ini.save();
            println("   change " + hostName + ":" + port + " AutoStart = false");
            // 无需重新加载，稍后升级流程会停止 sdbcm，等待升级后重启自动生效
        } catch (error) {
            println("Failed to set AutoStart = false on " + hostName + ":" + port + ", error info: " + error + "(" + getLastErrMsg() + ")");
            oma.close();
            return false;
        } finally {
            remoteObj.close();
        }
    }

    try {
        oma.close();
    } catch (error) {
        println("Failed to close Oma, error info: " + error + "(" + getLastErrMsg() + ")");
    }

    if (true == KEEPSDBCMCONF) {
        try {
            file.write(JSON.stringify(allCmConf) + "\n");
        } catch (error) {
            println("Failed to wirte file " + SDBCMFILE + ", error info: " + error + "(" + getLastErrMsg() + ")");
            return false;
        } finally {
            file.close();
        }
    }
    
    return true;
}

/* *****************************************************************************
@discription: 升级后恢复 sdbcm AutoStart
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function restoreSDBCM() {
    var oma;
    var db;
    var file;
    var allCmConf = [];

    if (true == KEEPSDBCMCONF) {
        // 读取 sdbcm 配置文件
        if (!File.exist(SDBCMFILE)) {
            println("File " + SDBCMFILE + " does not exist");
            return false;
        }
    
        try {
            file = new File(SDBCMFILE);
        } catch(error) {
            println("Open file[" + SDBCMFILE + "] failed: " + error + "(" + getLastErrMsg() + ")");
            return false;
        }
    
        try {
            allCmConf = JSON.parse(file.read(file.getSize(SDBCMFILE)));
            file.close();
        } catch(error) {
            println("Failed to get sdbcm conf array from file[" + SDBCMFILE + "], " + error + "(" + getLastErrMsg() + ")");
            file.close();
            return false;
        }
        
        if (!Array.isArray(allCmConf)) {
            println("Failed to get sdbcm conf array from file[" + SDBCMFILE + "]");
            return false;
        }
    }

    try {
        db = new Sdb(COORDADDR, COORDSVC, SDBUSER, SDBPASSWD);
    } catch (error) {
        println("Failed to connect sdb, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    // 获取主机名列表
    var hostArray = [];
    try {
        // 根据主机名分组并排序，确保相同环境每次执行返回的结果顺序是一致的
        var cursor = db.exec('select HostName from $SNAPSHOT_SYSTEM group by HostName order by HostName');
        while(cursor.next()) {
            hostArray.push(cursor.current().toObj().HostName);
        }
        cursor.close();
    } catch (error) {
        println("Failed to get HostName count from $SNAPSHOT_SYSTEM, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    } finally {
        db.close();
    }

    // 获取本地 Oma
    try {
        oma = new Oma();
    } catch (error) {
        println("Failed to get Oma, error info: " + error + "(" + getLastErrMsg() + ")");
        return false;
    }

    // 逐个修改 sdbcm 配置
    for (let i = 0; i < hostArray.length; i++) {
        var hostName = hostArray[i];
        var port = oma.getAOmaSvcName(hostName);
        var remoteOma;

        if (true == KEEPSDBCMCONF) {
            // 通过快照获取的主机名要和文件中的对应，否则报错
            if (allCmConf[i].HostName != hostName) {
                println("Failed to check " + hostName + ":" + port + " in file SDBCMFILE");
                oma.close();
                return false;
            }
        }

        try {
            remoteOma = new Oma(hostName, port);
        } catch (error) {
            println("Failed to get Oma on " + hostName + ":" + port + ", error info: " + error + "(" + getLastErrMsg() + ")");
            oma.close();
            return false;
        }

        // sdbcm.conf 的文件路径
        var sdbcmFile;
        try {
            sdbcmFile = remoteOma.getOmaConfigFile();
        } catch (error) {
            println("Failed to get sdbcm.conf path from oma on " + hostName + ":" + port + ", error info: " + error + "(" + getLastErrMsg() + ")");
            oma.close();
            return false;
        }

        // 连接 remote
        var remoteObj;
        try {
            remoteObj = new Remote(hostName, port);
        } catch (error) {
            println("Failed to get remoteObj on " + hostName + ":" + port + ", error info: " + error + "(" + getLastErrMsg() + ")");
            remoteOma.close();
            oma.close();
            return false;
        }

        try {
            var ini = remoteObj.getIniFile(sdbcmFile, SDB_INIFILE_EQUALSIGN | SDB_INIFILE_STRICTMODE | SDB_INIFILE_HASHMARK );
            var value = true;
            if (true == KEEPSDBCMCONF) {
                value = allCmConf[i].AutoStart;
            } else {
                value = true;
            }
            println("   restore " + hostName + ":" + port + " AutoStart = " + value);
            ini.setValue("AutoStart",value);
            ini.save();
            // 重新加载
            remoteOma.reloadConfigs();
        } catch (error) {
            println("Failed to restore AutoStart = " + value + " on " + hostName + ":" + port + ", error info: " + error + "(" + getLastErrMsg() + ")");
            return false;
        } finally {
            remoteOma.close();
            remoteObj.close();
        }
    }

    try {
        oma.close();
    } catch (error) {
        println("Failed to close Oma, error info: " + error + "(" + getLastErrMsg() + ")");
    }

    return true;
}

/* *****************************************************************************
@discription: 入口函数
@author: Qiqian Jiang
@return: true/false
***************************************************************************** */
function main() {
    // shell 获取 config.js 中参数接口，跳过参数检查
    if ("getArg" == CUROPR) {
        var cmd = "println(" + ARGNAME + ")";
        eval(cmd);
        return;
    }

    println("Begin to check args...");
    if (checkArgs()) {
       println("Done");
    } else {
       println("Failed");
       return 1;
    }

    /* Doing */
    if ("createTestCSCL" == CUROPR) {
        println("Begin to create SDB test CS.CL");
        if (createTestCSCL()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("collect_old" == CUROPR) {
        if (typeof(INSTANCEGROUPARRAY) == "undefined") {
            println("[ERROR] INSTANCEGROUPARRAY is undefined");
            return 1;
        }
        println("Begin to collect cluster information before upgrade...");
        if (collectInfo_old()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("collect_new" == CUROPR) {
        if (typeof(INSTANCEGROUPARRAY) == "undefined") {
            println("[ERROR] INSTANCEGROUPARRAY is undefined");
            return 1;
        }
        println("Begin to collect cluster information...");
        if (collectInfo_new()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("checkCluster" == CUROPR) {
        if (typeof(INSTANCEGROUPARRAY) == "undefined") {
            println("[ERROR] INSTANCEGROUPARRAY is undefined");
            return 1;
        }
        println("Begin to check cluster...");
        if (checkCluster()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("checkBasic" == CUROPR) {
        println("Begin to check basic ability");
        if (typeof(SDBVERSION) == "undefined") {
            println("[ERROR] SDBVERSION is undefined");
            return 1;
        }
        if (checkBasic()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("dropSYSRECYCLEITEMS" == CUROPR) {
        println("Begin to drop SYSRECYCLEITEMS after rollback");
        if (dropSYSRECYCLEITEMS()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("getIndexCount" == CUROPR) {
        println("Begin to get indexes count");
        if (getIndexCount()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("changeSDBCM" == CUROPR) {
        println("Begin to change sdbcm.conf");
        if (changeSDBCM()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else if ("restoreSDBCM" == CUROPR) {
        println("Begin to restore sdbcm.conf");
        if (restoreSDBCM()) {
            println("Done");
        } else {
            println("Failed");
            return 1;
        }
    } else {
        println("Unknown operation");
        return 1;
    }
    return;
}

main();
