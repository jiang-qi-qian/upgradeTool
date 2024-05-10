// SequoiaDB 用户
var SDBUSER = "sdbadmin";
// SequoiaDB 用户对应的密码
var SDBPASSWD = "sdbadmin";
// COORD 节点主机
var COORDADDR = "localhost";
// COORD 节点端口号
var COORDSVC = 11810;
// 所有机器都可用的备份目录，注意此目录下不要有其他文件，否则可能会被覆盖
var UPGRADEBACKUPPATH = "/sdbdata/data01/upgradebackup";
// SequoiaSQL 用户
var SQLUSER = "sdbadmin";
// SequoiaSQL 用户密码
var SQLPASSWD = "sdbadmin";
// 升级包
var NEWSDBRUNPACKAGE = "/opt/test/sequoiadb-5.8.2-linux_x86_64-enterprise-installer.run";
var NEWSQLRUNPACKAGE = "/opt/test/sequoiasql-mysql-5.8.2-linux_x86_64-enterprise-installer.run";
// 回滚包
var OLDSDBRUNPACKAGE = "/opt/test/sequoiadb-5.0.2-linux_x86_64-enterprise-installer.run";
var OLDSQLRUNPACKAGE = "/opt/test/sequoiasql-mysql-5.0.2-linux_x86_64-enterprise-installer.run";
// 创建的测试 DOMAIN 名
var TESTDOMAIN = "testDomain";
// 创建的测试 CS 名，对应 SQL 的库
var TESTCS = "testCS";
// 创建的测试 CL 名，对应 SQL 的表
var TESTCL = "testCL"
