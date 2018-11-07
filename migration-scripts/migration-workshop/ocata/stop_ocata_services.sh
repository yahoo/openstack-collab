#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

docker stop $(docker ps --format '{{.ID}} {{.Names}}' | grep -v maria | awk '{print $1}')
