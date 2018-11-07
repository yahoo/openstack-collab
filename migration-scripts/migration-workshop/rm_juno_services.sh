#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

source /home/vagrant/venv/bin/activate
source /home/vagrant/kolla/openrc
for SERVICE_USER in keystone heat glance neutron nova; do keystone user-delete $SERVICE_USER; done
docker stop $(docker ps --format '{{.ID}} {{.Names}}' | grep -v maria | awk '{print $1}')
