#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

set -e
set -x
ROOT_DIR=/vagrant/ocata

docker rm -f $(docker ps -aq)
kolla-ansible -i ${ROOT_DIR}/all-in-one --extra @${ROOT_DIR}/extra.yaml bootstrap-servers
kolla-ansible -i ${ROOT_DIR}/all-in-one --extra @${ROOT_DIR}/extra.yaml deploy
