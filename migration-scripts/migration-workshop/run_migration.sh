#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

MY_IP=192.168.33.10
mysql -h${MY_IP} -uroot -pkolla -e 'UPDATE nova.compute_nodes SET host_ip="192.168.33.10";'
./do_migration.sh ${MY_IP} 3306 root kolla rabbit://guest:guest@${MY_IP}:5672 mysql+pymysql://nova:nova@${MY_IP}:3306
mysql -h${MY_IP} -uroot -pkolla -e 'UPDATE nova_api.cell_mappings SET database_connection="mysql+pymysql://nova:nova@192.168.33.25:3306/nova" WHERE id=2;'
# Only use this if on a very small disk
#mysql -h${MY_IP} -uroot -pkolla -e 'UPDATE nova.compute_nodes SET disk_available_least=free_disk_gb;';
for DIR in $(find /var/lib/docker/volumes/ -type d -name images); do if [ $(ls $DIR/.. | wc -l) -eq "1" ] ; then cp -r $DIR . ; fi ; done
cp -r $(find /var/lib/docker/volumes/ -type d -name instances) .
