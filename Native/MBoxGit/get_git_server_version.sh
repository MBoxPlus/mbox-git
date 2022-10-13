#!/bin/sh

GIT_TRACE_PACKET=true git ls-remote -q --tags "$1" 2>&1 | grep "< agent="
