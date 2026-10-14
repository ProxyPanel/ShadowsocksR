#!/usr/bin/env python3
# @Time    : 2018-10-27 14:28
# @Author  : Sakura
# @Site    :
# @File    : __init__.py.py
# @Software: PyCharm

from peewee import CharField, IntegerField, Model, MySQLDatabase, SQL, TextField

from configloader import mysql_config

def pymysql_ssl_config(cfg):
    """ssl_enable=1 就必须走 TLS：没配 ca 时按不校验证书握手，配了 ca 才校验"""
    ssl_config = {"check_hostname": False, "verify_mode": False}
    if cfg["ssl_ca"]:
        ssl_config["ca"] = cfg["ssl_ca"]
        ssl_config["verify_mode"] = True
    if cfg["ssl_cert"]:
        ssl_config["cert"] = cfg["ssl_cert"]
    if cfg["ssl_key"]:
        ssl_config["key"] = cfg["ssl_key"]
    return ssl_config


connect_args = {
    "host": mysql_config["host"],
    "port": int(mysql_config["port"]),
    "user": mysql_config["user"],
    "password": mysql_config["password"],
    "charset": "utf8mb4",
}
if mysql_config['ssl_enable'] == 1:
    connect_args["ssl"] = pymysql_ssl_config(mysql_config)

database = MySQLDatabase(mysql_config["db"], **connect_args)


class BaseModel(Model):
    class Meta:
        database = database


class SsNodeIp(BaseModel):
    created_at = IntegerField(constraints=[SQL("DEFAULT 0")])
    ip = TextField(null=True)
    node = IntegerField(column_name='node_id',
                        constraints=[SQL("DEFAULT NULL")])
    port = IntegerField(constraints=[SQL("DEFAULT 0")])
    type = CharField(constraints=[SQL("DEFAULT 'tcp'")])

    class Meta:
        table_name = 'node_online_ip'
