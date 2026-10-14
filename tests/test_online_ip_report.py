#!/usr/bin/env python3
"""在线 IP 上报与流量写入的单测：依赖全部用替身，不需要 MySQL，也不需要先跑 initcfg.sh。"""

import contextlib
import importlib
import sys
import types

import pytest

# db_transfer 在 import 阶段就会读 usermysql.json 并建 peewee 连接池，
# 所以这几个模块必须先落成替身再导入被测模块
STUBBED_MODULES = ("peewee", "pymysql", "configloader", "database", "server_pool")


class Recorder:
    def __init__(self):
        self.batches = []
        self.statements = []


def _make_stub_modules(recorder):
    peewee = types.ModuleType("peewee")
    for name in ("CharField", "IntegerField", "Model", "MySQLDatabase", "SQL", "TextField"):
        setattr(peewee, name, object)

    pymysql = types.ModuleType("pymysql")
    pymysql.connect = lambda **kwargs: pytest.fail("单测不应建立真实数据库连接")

    configloader = types.ModuleType("configloader")
    configloader.load_config = lambda: None
    configloader.get_config = lambda: types.SimpleNamespace(UPDATE_TIME=60, MYSQL_CONFIG="usermysql.json")
    configloader.get_mysql_config = lambda: {}

    database = types.ModuleType("database")
    database.connect_args = {}

    @contextlib.contextmanager
    def atomic():
        yield

    db = types.SimpleNamespace(atomic=atomic)

    class _Insert:
        def __init__(self, rows):
            self._rows = rows

        def execute(self):
            recorder.batches.append([dict(r) for r in self._rows])

    database.SsNodeIp = types.SimpleNamespace(insert_many=lambda rows: _Insert(rows))
    database.database = db

    server_pool = types.ModuleType("server_pool")
    server_pool.ServerPool = types.SimpleNamespace(get_instance=lambda: None)

    return {
        "peewee": peewee,
        "pymysql": pymysql,
        "configloader": configloader,
        "database": database,
        "server_pool": server_pool,
    }


@pytest.fixture
def db_transfer(monkeypatch, recorder):
    saved = {name: sys.modules.get(name) for name in STUBBED_MODULES}
    for name, module in _make_stub_modules(recorder).items():
        sys.modules[name] = module
    sys.modules.pop("db_transfer", None)
    try:
        module = importlib.import_module("db_transfer")
    finally:
        for name, original in saved.items():
            if original is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = original
    # 被测方法只通过 ServerPool.get_instance() 取端口池
    pool = types.SimpleNamespace(tcp_servers_pool={}, udp_servers_pool={}, tcp_ipv6_servers_pool={}, udp_ipv6_servers_pool={})
    monkeypatch.setattr(module, "ServerPool", types.SimpleNamespace(get_instance=lambda: pool))
    monkeypatch.setattr(module.shell, "get_config", lambda is_local: {})
    module._test_pool = pool
    yield module


@pytest.fixture
def recorder():
    return Recorder()


def _transfer(module):
    obj = module.DbTransfer.__new__(module.DbTransfer)
    obj.cfg = {"node_id": 5}
    return obj


def _push(module, tcp, udp):
    pool = module._test_pool
    pool.tcp_servers_pool = {port: {"one_minute_ips": ips} for port, ips in tcp.items()}
    pool.udp_servers_pool = {port: {"one_minute_ips": ips} for port, ips in udp.items()}
    _transfer(module).push_all_port_and_connect()


class TestPushAllPortAndConnect:
    def test_reports_tcp_only_activity(self, db_transfer, recorder):
        """只有 TCP 活动、这一分钟没有任何 UDP 会话时，仍然必须上报"""
        _push(db_transfer, {8388: {"1.1.1.1"}, 8389: {"2.2.2.2"}}, {})

        assert len(recorder.batches) == 1
        assert sorted(row["port"] for row in recorder.batches[0]) == [8388, 8389]
        assert {row["type"] for row in recorder.batches[0]} == {"tcp"}

    def test_writes_exactly_one_batch_per_cycle(self, db_transfer, recorder):
        """多个 UDP 端口不能把累加中的结果集反复写入"""
        _push(
            db_transfer,
            {8388: {"1.1.1.1"}, 8389: {"2.2.2.2"}},
            {8388: {"3.3.3.3"}, 8389: {"4.4.4.4"}, 8390: {"5.5.5.5"}},
        )

        assert len(recorder.batches) == 1
        rows = recorder.batches[0]
        assert len(rows) == 5
        assert len({(row["port"], row["type"]) for row in rows}) == 5

    def test_strips_ipv4_mapped_prefix(self, db_transfer, recorder):
        _push(db_transfer, {8388: {"::ffff:1.1.1.1", "0:0:0:0:0:ffff:2.2.2.2"}}, {})

        # one_minute_ips 是 set，逗号串的次序不固定
        assert sorted(recorder.batches[0][0]["ip"].split(",")) == ["1.1.1.1", "2.2.2.2"]

    def test_keeps_plain_ipv4_and_ipv6(self, db_transfer, recorder):
        """IPv4 监听下对端就是裸地址，非映射形态必须原样上报而不是变成 None"""
        _push(db_transfer, {8388: {"1.1.1.1", "2001:db8::1"}}, {})

        assert sorted(recorder.batches[0][0]["ip"].split(",")) == ["1.1.1.1", "2001:db8::1"]

    def test_no_activity_writes_nothing(self, db_transfer, recorder):
        _push(db_transfer, {8388: set()}, {8388: set()})

        assert recorder.batches == []


class _FakeCursor:
    def __init__(self, recorder):
        self._recorder = recorder

    def execute(self, sql, args=None):
        self._recorder.statements.append((sql, args))

    def close(self):
        pass


class _FakeConn:
    def __init__(self, recorder):
        self._recorder = recorder

    def autocommit(self, value):
        pass

    def cursor(self):
        return _FakeCursor(self._recorder)

    def commit(self):
        pass

    def close(self):
        pass


def _v3_transfer(module, recorder):
    obj = module.Dbv3Transfer.__new__(module.Dbv3Transfer)
    obj.cfg = {"node_id": 5, "transfer_mul": 1.0}
    obj.user_pass = {}
    obj.onlineuser_cache = {8388: 100}
    obj.port_uid_table = {8388: 1234}
    obj.start_time = 0
    obj.ss_node_info_name = "node_heartbeat"
    return obj


class TestUpdateAllUser:
    @pytest.fixture
    def statements(self, db_transfer, recorder, monkeypatch):
        monkeypatch.setattr(db_transfer, "_connect_db", lambda: _FakeConn(recorder))
        _v3_transfer(db_transfer, recorder).update_all_user({8388: [1048576, 2097152]})
        return recorder.statements

    def test_values_are_bound_not_inlined(self, statements):
        inserts = [(sql, args) for sql, args in statements if sql.startswith("INSERT")]
        assert len(inserts) == 3

        for sql, args in inserts:
            assert sql.count("%s") == len(args)
            for value in args:
                assert "'%s'" % value not in sql

    def test_traffic_increment_is_applied(self, statements):
        update = [sql for sql, args in statements if sql.startswith("UPDATE")]
        assert len(update) == 1
        assert "WHEN 8388 THEN u+1048576" in update[0]
        assert "WHEN 8388 THEN d+2097152" in update[0]
        assert "WHERE port IN (8388)" in update[0]

    def test_heartbeat_reports_three_load_fields(self, statements):
        heartbeat = [(sql, args) for sql, args in statements if "node_heartbeat" in sql]
        assert len(heartbeat) == 1

        load = heartbeat[0][1][2]
        assert len(load.split()) == 3
        assert all(len(part.split(".")) == 2 for part in load.split())
