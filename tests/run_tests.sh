#!/usr/bin/env bash
# 测试入口：静态检查 + 用例矩阵，本机与 CI 共用
# 前置条件：curl 可用、http://localhost/ 有页面、http://127.0.0.1/file 有一个大文件
# CI 里的准备步骤见 .github/workflows/ci.yml

set -u

cd "$(dirname "$0")/.." || exit 1

PYTHON="${PYTHON:-python3}"
LARGE_FILE_URL="${LARGE_FILE_URL:-http://127.0.0.1/file}"
DNS_URL="${DNS_URL:-https://clients1.google.com/generate_204}"
result=0

run_test() {
    printf '\e[0;36m'
    echo "running test: $*"
    printf '\e[0m'

    "$@"
    status=$?
    if [ $status -ne 0 ]; then
        printf '\e[0;31m'
        echo "test failed: $* (exit $status)"
        printf '\e[0m'
        echo
        result=1
    else
        printf '\e[0;32m'
        echo OK
        printf '\e[0m'
        echo
    fi
    return 0
}

check_env() {
    command -v curl > /dev/null 2>&1 || {
        echo "missing dependency: curl"
        exit 1
    }
    curl -sf -o /dev/null http://localhost/ || {
        echo "tests/test.py needs a page on http://localhost/ , e.g.:"
        echo "  apt-get install -y nginx && service nginx restart"
        exit 1
    }
    curl -sfI -o /dev/null "$LARGE_FILE_URL" || {
        echo "tests/test_large_file.sh needs $LARGE_FILE_URL to exist, e.g.:"
        echo "  dd if=/dev/urandom of=/var/www/html/file bs=1M count=10"
        exit 1
    }
}

mkdir -p tmp

run_test "$PYTHON" -m compileall -q shadowsocks tests *.py

if command -v ruff > /dev/null 2>&1; then
    run_test ruff check .
else
    echo "ruff not found, run: pip install ruff"
fi

check_env

# 每个方法跑一遍 TCP 链路：服务端、客户端、经 socks5h 的 curl
for conf in aes aes-ctr aes-cfb1 aes-cfb8 chacha20 salsa20 table; do
    run_test "$PYTHON" tests/test.py --tcp-only -c "tests/$conf.json"
done

run_test "$PYTHON" tests/test.py --tcp-only -c tests/server-multi-ports.json
run_test "$PYTHON" tests/test.py --tcp-only -s tests/aes.json -c tests/client-multi-server-ip.json
run_test "$PYTHON" tests/test.py --tcp-only -s tests/server-multi-passwd.json \
    -c tests/server-multi-passwd-client-side.json
run_test "$PYTHON" tests/test.py --tcp-only -c tests/workers.json

# 命令行参数模式，同时覆盖 workers 与 verbose 开关
run_test "$PYTHON" tests/test.py --tcp-only \
    -b "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 --workers 1" \
    -a "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 -l 1081 -t 30 -qq -b 127.0.0.1"

# forbidden-ip 三种形态：显式列表拒绝、默认列表拒绝、空列表放行
run_test "$PYTHON" tests/test.py --tcp-only --should-fail --url="http://127.0.0.1/" \
    -b "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 --forbidden-ip=127.0.0.1,::1,8.8.8.8" \
    -a "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 -l 1081 -t 30 -b 127.0.0.1"
run_test "$PYTHON" tests/test.py --tcp-only --should-fail --url="http://127.0.0.1/" \
    -b "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388" \
    -a "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 -l 1081 -t 30 -b 127.0.0.1"
run_test "$PYTHON" tests/test.py --tcp-only --url="http://127.0.0.1/" \
    -b "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 --forbidden-ip=" \
    -a "-m aes-256-cfb -k testrc4 -s 127.0.0.1 -p 8388 -l 1081 -t 30 -b 127.0.0.1"

# 域名解析交给远端 DNS：socks5h 下由服务端解析外网域名
run_test "$PYTHON" tests/test.py --tcp-only -c tests/aes.json --url="$DNS_URL"

run_test bash tests/test_command.sh
run_test bash tests/test_daemon.sh
run_test bash tests/test_large_file.sh

rm -rf tmp

exit $result
