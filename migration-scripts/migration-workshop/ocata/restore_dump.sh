#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

mysql -h192.168.33.10 -uroot -pkolla -e "show databases" | grep -v Database | grep -v mysql| grep -v information_schema| gawk '{print "drop database " $1 ";select sleep(0.1);"}' | mysql -h192.168.33.10 -uroot -pkolla
mysql -h192.168.33.10 -uroot -pkolla < ocata_db_dump.sql
cp -r instances/ /var/lib/docker/volumes/nova_compute/_data
cp -r images/ /var/lib/docker/volumes/glance/_data
chown --reference=/var/lib/docker/volumes/nova_compute/_data -R /var/lib/docker/volumes/nova_compute/_data
chown --reference=/var/lib/docker/volumes/glance/_data -R /var/lib/docker/volumes/glance/_data
