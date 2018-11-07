#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

MY_IP=192.168.33.10
mysqldump -u root --password=kolla -h $MY_IP --all-databases --result-file=ocata_db_dump.sql
docker stop $(docker ps -q)
