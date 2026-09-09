# scripts/_legacy

**不是入口。** 这里是 AutoDL / 任务编号 / 机房写死路径 / base64 备份的化石。不删内容，也不要用它们起今天的栈。

现网入口：[../README.md](../README.md)。规范：`docker-up`、`demo-compatibility` 等。

| 文件 | 当初干什么 |
|------|------------|
| `start_services.sh` | AutoDL 写死 `/root/autodl-tmp/` 的裸机启动（现网裸机用上一级 `start_services.sh`） |
| `auto_test.sh` / `auto_test_v2.sh` | 旧 Linux 全量菜单测试 |
| `auto_test_v2.b64` / `t13_b64.txt` | 脚本的 base64 备份 |
| `targeted_test.sh` | 「447 算力机」一次性 |
| `int-test-task11.sh` | Task 11 集成编号脚本 |
| `test-status.sh` | `auto_test_v2` 进度文件 |
| `fix_db.sh` | 机房 postgres 口令重置 |
| `test_jwt.sh` / `check_env.sh` | 经 `/proc` 看进程环境 |
| `zh-diag.sh` / `llama-log-zh.sh` | 中文排障 / llama 日志翻译 |

要复活某一份，先对照 [运行时端口登记](../../docs/platform/运行时端口登记.md) 和规范入口，不要直接当默认启动器。
