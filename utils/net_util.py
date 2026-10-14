#!/usr/bin/env python3


def from_map_ipv6_get_ipv4(address):
    # 双栈监听下对端是 ::ffff:x.x.x.x 形态，纯 IPv4 监听下就是原始地址，两种都要能落库
    if address.startswith("::ffff:"):
        return address[7:]
    if address.startswith("0:0:0:0:0:ffff:"):
        return address[15:]
    return address
