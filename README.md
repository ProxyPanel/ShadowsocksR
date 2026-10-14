SSRR

兼容ProxyPanel & SSRPanel的自改版SSR(R)后端，可兼容原版SS、SSR，本版本是带有IP自动上报功能的

## 支持范围

以代码里的运行时注册表为准，不随文档漂移。

| 类别 | 可填值 | 注册条目 |
| --- | --- | --- |
| 加密 `method` | `table` / `none`；`rc4`、`rc4-md5`、`rc4-md5-6`；`aes-128/192/256` 的 `cfb`、`cfb1`、`cfb8`、`ctr`、`ofb`、`cbc`、`gcm`；`cast5-cfb`、`des-cfb`、`idea-cfb`、`rc2-cfb`、`seed-cfb`、`bf-cfb`、`camellia-128/192/256-cfb`；`chacha20`、`chacha20-ietf`、`xchacha20`、`salsa20`、`salsa20-ctr`、`xsalsa20` | 本机实测 40 条 |
| 协议 `protocol` 与混淆 `obfs` | `origin`、`plain`、`verify_deflate`；`auth_sha1_v4`、`auth_aes128_md5`、`auth_aes128_sha1`、`auth_chain_a` ~ `auth_chain_f`；`http_simple`、`http_post`、`random_head`、`tls1.2_ticket_auth`、`tls1.2_ticket_fastauth`（后五类各带一个 `_compatible` 兼容原版形式） | 两张表同源，各 23 条 |

- 加密表取决于部署机上 OpenSSL / libsodium 提供了什么，缺库时对应条目不会注册。核对命令：
  `python -c "from shadowsocks import encrypt; print(sorted(encrypt.method_supported))"`
- `protocol` 与 `obfs` 共用 `shadowsocks/obfs.py` 里同一份 `method_supported`，带 `_compatible` 后缀的表示兼容原版客户端。
- CI 只回归 9 条加密：`aes-256-cfb`、`aes-256-cfb1`、`aes-256-cfb8`、`aes-256-ctr`、`chacha20`、`salsa20`、`salsa20-ctr`、`rc4-md5`、`table`（见 `tests/*.json`）。其余条目是注册可用但未纳入回归。

## 安装
- git clone https://github.com/ProxyPanel/ShadowsocksR.git

## 更新软件源
#### CentOS
- yum update

#### Ubuntu/Debian
- sudo apt-get update

## 安装
#### Python 3.14（最低 3.13）

1. 安装pyenv 参照:[Pyenv Common build problems](https://github.com/pyenv/pyenv/wiki/Common-build-problems)
```
# Ubuntu/Debian:
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev gcc readline readline-devel readline-static \
openssl openssl-devel openssl-static sqlite-devel bzip2-devel bzip2-libs

# Fedora/CentOS/RHEL(aws ec2):
sudo yum install -y zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
openssl-devel xz xz-devel libffi-devel gcc readline readline-devel readline-static \
openssl openssl-devel openssl-static sqlite-devel bzip2-devel bzip2-libs

```

2.安装pyenv
```
curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
```

3.添加环境变量到.bashrc
```
cat >> ~/.bashrc << EOF
export PATH="/root/.pyenv/bin:\$PATH"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"
EOF
source ~/.bashrc
```

4.用pyenv安装并启用python
```
pyenv install 3.14
pyenv global 3.14
```

5.安装shadowsocks依赖
```
cd ShadowsocksR
pip install -r requirements.txt  --break-system-packages
```

6.生成可编辑的配置文件（userapiconfig.py / user-config.json / usermysql.json）
```
bash initcfg.sh
```
---

#### 编辑节点配置（混淆、协议、限速、IPV6）

    vi user-config.json

    protocol 协议，带 _compatible 结尾兼容 原版，直接用原版可以改为 origin
    protocol_param 协议参数，配置了的话，客户端也要一致
    obfs 混淆 tls1.2_ticket_auth 可以限制客户端数量 tls1.2_ticket_auth_compatible 兼容原版，直接用原版可以改为 plain
    obfs_param 混淆参数，当obfs为 tls1.2_ticket_auth 的时候，这个值为 1 到 256 之间，表示限制客户端数量
    speed_limit_per_con 单连接限速，单位 KB/s，0 为不限速
    speed_limit_per_user 单用户限速，单位 KB/s，0 为不限速
    （上面两个限速键可被面板 user 表的同名列覆盖，按端口下发给每个用户）
    additional_ports 单端口配置，请看wiki
    additional_ports_only 强制单端口，改为true则所有非设置的单端口都无法连接，只能用additional_ports设置的那些端口连接
    dns_ipv6 为true时，会优先走ipv6，需要节点服务器至少有一个2开头的ipv6地址（有时候会导致IPV4失效，不推荐开启，你可以自己试试）
    connect_verbose_info 为1时记录用户访问网址，推荐打开，可以清楚知道连接成功与否
    redirect 请求失败时返回信息伪造成访问配置里网址


#### 编辑数据库连接信息

    vi usermysql.json

    host 数据库地址，如果是本机就是127.0.0.1
    port 数据库连接端口
    user 数据库连接用户，不推荐使用root
    password 数据库连接密码
    db 面板所在数据库
    node_id 节点ID，对应面板里的 节点列表 最左侧的id（请先将面板搭建好，然后创建一个节点，就有节点ID了）
    transfer_mul 节点流量计算比例，默认1.0，填1也可以，1表示：用了100M算100M，10表示用了100M算1000M，0.1表示用了100M算10M。

#### 运行、关闭、看日志

    sh logrun.sh
    sh stop.sh
    sh tail.sh

#### 其他

数据库机的 iptables、firewall 得对本节点IP开放
数据库机的 mysql 的对本节点进行授权（不推荐使用root账号）

## 版本上下线

V3.2.2 是上游 SSRR 的基线 tag（2018-07-15）。本版按 semver 进主版本到 **V4.0.0**：抬高 Python 下限并移除了若干旧路径，属破坏性变更。

| 日期 | 状态 | 项 |
| --- | --- | --- |
| 2018-07-15 | 上线（基线） | 上游 SSRR `V3.2.2`，协议 / 混淆 / 加密注册表承自至此 |
| 2020-12-27 | 上线 | ProxyPanel 2.6.x 数据库对接：`node`、`user`、`user_traffic_log`、`node_online_log`、`node_heartbeat` |
| 2024-11-17 | 上线 | Python 3 运行路径 |
| 2025-06-04 | 上线 | 限速：`speed_limit_per_con` / `speed_limit_per_user`（单位 KB/s，可被面板 `user` 表同名列覆盖） |
| 2026-10-14 | 上线 | Python 3.13 为最低要求、3.14 为推荐部署版本；`pyproject.toml` 打包、ruff lint + format、GitHub Actions CI、pytest 单测 |
| 2026-10-14 | 下线 | Python 2 兼容路径（`six`、`__future__`、py2 分支遗留写法） |
| 2026-10-14 | 下线 | MUDB 口令库与 `mujson_mgr.py` 管理脚本（`mudb.json`、`initmudbjson.sh`）。`additional_ports` 单端口多用户不受影响 |
| 2026-10-14 | 下线 | `asyncmgr.py` 异步管理入口 |
| 2026-10-14 | 下线 | `setup.py` 与 `debian/` 打包、`MANIFEST.in`、`Pipfile` |
| 2026-10-14 | 下线 | `crypto/ctypes_openssl.py`、`crypto/ctypes_libsodium.py` 两份旧后端，统一到 `crypto/openssl.py` + `crypto/sodium.py` |
| 2026-10-14 | 下线 | Travis（`.travis.yml`，由 GitHub Actions 取代）、`script/deploy_ssh.sh`、`script/bbr_mod.sh`、`shadowsocks/` 内重复的 `run/logrun/stop/tail.sh` |

## 开发

```bash
pip install -r requirements.txt ruff pytest
ruff check . && ruff format --check .   # 风格判据
pytest -q                               # 单测：不需要 MySQL，也不需要先跑 initcfg.sh
bash initcfg.sh && bash tests/run_tests.sh   # 功能回归：需要 Linux、nginx 与一个大文件
```

