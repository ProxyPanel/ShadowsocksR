#!/usr/bin/env python3
import importlib


def load(name):
    try:
        obj = importlib.import_module(name)
        return importlib.reload(obj)
    except Exception:
        return None


def loads(namelist):
    for name in namelist:
        obj = load(name)
        if obj is not None:
            return obj
