#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

set -e
set -x
ROOT_DIR=/vagrant/ocata

yum remove -y docker-ce || :
rm -f /etc/yum.repos.d/docker-ce.repo || :
umount /var/lib/docker/devicemapper/ || :
rm -rf /var/lib/docker/ || :
yum install -y epel-release
yum install -y python-pip python-devel libffi-devel gcc openssl-devel libselinux-python git
pip install -U pip
[ -e ${ROOT_DIR}/kolla-ansible ] || git clone https://github.com/openstack/kolla-ansible.git ${ROOT_DIR}/kolla-ansible -b stable/ocata
pip install ${ROOT_DIR}/kolla-ansible
pip install "ansible>=2,<2.4" virtualenv

[ -e /etc/ansible ] || mkdir /etc/ansible
cp ${ROOT_DIR}/ansible.cfg /etc/ansible/
[ -e /etc/kolla ] || cp -r ${ROOT_DIR}/kolla-ansible/etc/kolla /etc/
kolla-genpwd
mkdir -p /etc/kolla/config/nova/
cat > /etc/kolla/config/nova/nova-compute.conf <<EOF
[libvirt]
virt_type = qemu
cpu_mode = none
EOF

cp ${ROOT_DIR}/kolla-ansible/ansible/inventory/all-in-one ${ROOT_DIR}
kolla-ansible -i ${ROOT_DIR}/all-in-one --extra @${ROOT_DIR}/extra.yaml bootstrap-servers
kolla-ansible -i ${ROOT_DIR}/all-in-one --extra @${ROOT_DIR}/extra.yaml prechecks
kolla-ansible -i ${ROOT_DIR}/all-in-one --extra @${ROOT_DIR}/extra.yaml pull
kolla-ansible -i ${ROOT_DIR}/all-in-one --extra @${ROOT_DIR}/extra.yaml deploy
docker exec openvswitch_db ovs-vsctl set interface eth1 type=internal

kolla-ansible --extra @${ROOT_DIR}/extra.yaml post-deploy
cp /etc/kolla/admin-openrc.sh /home/vagrant
