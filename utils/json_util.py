#!/usr/bin/env python3
# @Time    : 2018/10/27 13:59
# @Author  : Sakura
# @Site    :
# @File    : net_util.py
# @Software: PyCharm
from json import dumps, loads, JSONEncoder


class PythonObjectEncoder(JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (list, dict, str, int, float, bool, type(None))):
            return JSONEncoder.default(self, obj)
        if isinstance(obj, set):
            return list(obj)


class JsonUtil(object):
    @classmethod
    def dumps(cls, obj):
        """
        序列化python对象到json字符串
        :param obj:
        :return:
        """
        return dumps(obj, cls=PythonObjectEncoder)

    @classmethod
    def json_loads(cls, str):
        """
        反序列化json字符串到python对象
        :param str:
        :return:
        """
        return loads(str)

