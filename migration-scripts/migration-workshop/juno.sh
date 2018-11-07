#!/bin/bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

set -Eexo pipefail

setenforce permissive
yum install -y epel-release
yum install -y python-pip python-devel libffi-devel gcc openssl-devel libselinux-python git curl mysql
pip install virtualenv
[ -e venv ] || virtualenv venv
source venv/bin/activate

curl -L https://github.com/docker/compose/releases/download/1.8.1/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

curl -o/etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce
systemctl start docker

curl https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=kilo-eol | grep -v '^aioeventlet' | grep -v '^cryptography=' | grep -v '^pyOpenSSL=' | grep -v '^cffi=' | grep -v 'SQLAlchemy' | grep -v 'MySQL-python' | grep -v 'PyMySQL' | grep -v 'alembic' > up_cons_file
echo "aioeventlet===0.5.2" >> up_cons_file
grep -v 'oslo.i18n' up_cons_file | grep -v 'oslo.db' | grep -v '^kombu' > up_cons_file-BAK
echo "oslo.i18n===1.7.0" >> up_cons_file-BAK
echo "oslo.db===1.7.0" >> up_cons_file-BAK
echo "kombu===3.0.30" >> up_cons_file-BAK
mv up_cons_file-BAK up_cons_file
pip install python-keystoneclient==1.6.0 python-glanceclient==0.19.0 python-novaclient==2.26.0 python-heatclient==0.6.0 python-neutronclient==2.6.0 -c up_cons_file
rm up_cons_file

[ -e kolla ] || git clone https://github.com/openstack/kolla.git
cd kolla
git checkout tags/juno-eol
cp /vagrant/genenv ./tools/genenv
./tools/genenv

cd compose
for f in *.yml ; do grep -v 'name:' $f > tmp.yml && mv tmp.yml $f ; done
cd ..

export COMPOSE_API_VERSION=1.18
echo 'NOVA_CONSOLEAUTH_LOG_FILE=/var/log/nova/nova-consoleauth.log' >> compose/openstack.env
echo 'NOVA_NOVNCPROXY_LOG_FILE=/var/log/nova/nova-vncproxy.log' >> compose/openstack.env

./tools/kolla start
source openrc

MY_IP=192.168.33.10
mysql -h${MY_IP} -uroot -pkolla -e 'DROP DATABASE heat;'
docker stop compose_heatapi_1 compose_heatengine_1 compose_horizon_1

./tools/init-runonce
[ -e ~/.ssh/id_rsa ] || ssh-keygen -t rsa -f ~/.ssh/id_rsa
nova keypair-add --pub-key ~/.ssh/id_rsa.pub demo-keypair
neutron subnet-update demo-subnet --enable_dhcp false
nova boot --flavor m1.tiny --image cirros --key-name demo-keypair --nic net-id=$(neutron net-list -f value -F id) demo1
