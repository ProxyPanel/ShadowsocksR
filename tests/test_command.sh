#!/usr/bin/env bash
# 命令行契约测试：--version 文案、check_config 的告警与致命错误。
# 起进程 RUN_SECONDS 秒后杀掉再抓日志，因此不依赖 daemon 模式（Linux 与 CI 通用）。

cd "$(dirname "$0")/.." || exit 1

# 不统计耗时，避免依赖 bc
export INVARIANT=1

. tests/assert.sh

PYTHON="${PYTHON:-python3}"
LOCAL="$PYTHON shadowsocks/local.py"
SERVER="$PYTHON shadowsocks/server.py"
RUN_SECONDS="${RUN_SECONDS:-3}"

# probe <正则> <命令...>：取匹配片段，去重后按字典序拼成一行
probe() {
    local pattern="$1"
    shift
    timeout "$RUN_SECONDS" "$@" 2>&1 \
        | grep -o -E "$pattern" \
        | sort -u \
        | paste -sd '|' -
}

VERSION='ShadowsocksR SSRR [0-9.]+ [0-9-]+'
# --version 取 shell.__version()：git clone 部署没有分发元数据，因此落回 version.py 的字符串；
# 用 pip 安装过本包时同一条命令打印的是分发版本号
WARN='warning: [^|]*'
CIDR='Not a valid CIDR notation: [^|]*'
PW='DEFAULT PASSWORD! Please change it in your config.json!'
BASE="-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 -t 300"
LISTEN="warning: server set to listen on 127.0.0.1:8388, are you sure?"
STAMP="ShadowsocksR SSRR 3.2.2 2018-05-22"

assert "probe '$VERSION' $LOCAL --version" "$STAMP"
assert "probe '$VERSION' $SERVER --version" "$STAMP"

assert "probe '$WARN' $SERVER $BASE" "$LISTEN"
assert "probe '$WARN' $SERVER $BASE -t 10" "$LISTEN|warning: your timeout 10 seems too short"
assert "probe '$WARN' $SERVER $BASE -t 1000" "$LISTEN|warning: your timeout 1000 seems too long"
assert "probe '$WARN' $LOCAL $BASE -l 1081" "$LISTEN"

assert "probe '$CIDR' $SERVER $BASE --forbidden-ip 127.0.0.1/4a" \
    "Not a valid CIDR notation: 127.0.0.1/4a"

# 默认口令是致命判据：命令行 -k 与配置文件两条路都必须退出码 1
mkdir -p tmp
cat > tmp/default_password.json <<'JSON'
{"server":"127.0.0.1","server_port":8388,"password":"mypassword",
 "method":"aes-256-cfb","timeout":300}
JSON
assert "probe '$PW' $SERVER -c tmp/default_password.json" \
    "DEFAULT PASSWORD! Please change it in your config.json!"
assert_raises "$SERVER $BASE -k mypassword" 1
assert "probe '$PW' $SERVER $BASE -k mypassword" \
    "DEFAULT PASSWORD! Please change it in your config.json!"
assert_raises "$SERVER -c tmp/default_password.json" 1
rm -rf tmp

# local 监听 0.0.0.0 的告警：命令行与配置文件取的是同一个 str 判据
assert "probe '$WARN' $LOCAL $BASE -l 1081 -b 0.0.0.0" \
    "warning: local set to listen on 0.0.0.0, it's not safe|$LISTEN"

assert_end command
