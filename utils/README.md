Useful Tools
===========

两个模块都是后端启动路径上的依赖，不是独立可执行工具。

json_util.py
------------

`JsonUtil.json_loads` / `json_dumps`：容忍 `//` 行注释的 JSON 读写，
`configloader` 用它解析 `usermysql.json`（与 `shadowsocks.shell` 里
`remove_comment` 处理 `user-config.json` 的方式对应）。

net_util.py
-----------

`from_map_ipv6_get_ipv4(address)`：把双栈监听上报的
`::ffff:x.x.x.x` / `0:0:0:0:0:ffff:x.x.x.x` 还原成裸 IPv4，其余地址原样返回。
`db_transfer` 在写 `node_online_ip` 前逐条过它。
