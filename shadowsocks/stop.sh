#!/bin/bash

eval $(ps -ef | grep "[0-9] python3 server\\.py a" | awk '{print "kill "$2}')

