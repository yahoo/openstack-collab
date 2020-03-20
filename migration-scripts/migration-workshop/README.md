DB migration workshop and demo resources - Open Infra Summit Berlin 2018
===

Database Migration Workshop Instructions

```bash
# Install libvirt and its plugin for vagrant.
# You may need to do something different but this
# is a way that works on CentOS 7.
sudo yum install -y qemu libvirt libvirt-devel ruby-devel gcc qemu-kvm dkms make qt libgomp patch kernel-headers kernel-devel binutils glibc-headers glibc-devel font-forge
sudo yum install -y https://releases.hashicorp.com/vagrant/1.9.6/vagrant_1.9.6_x86_64.rpm
sudo vagrant plugin install vagrant-libvirt
# Create and ssh to the Vagrant VM
sudo vagrant up
sudo vagrant ssh
# Become root user
sudo su
# Deploy Juno and boot a VM
/vagrant/juno.sh
# Manually check to see the VM is there
source kolla/openrc
source venv/bin/activate
nova list
ps aux | grep qemu
# Deactivate the venv, this is important for later steps
deactivate
# Shut down all Openstack services except DB
/vagrant/rm_juno_services.sh
# Clone down the DB migration scripts
git clone https://github.com/yahoo/openstack-collab.git
cd openstack-collab/migration-scripts/scripts/
# Create a venv for each version of each component to be migrated
./clone.sh
tar xf build.tar.gz
# Run the actual DB migration
/vagrant/run_migration.sh
# Take a copy of the now Ocata DB
/vagrant/take_db_dump.sh
# Destroy all old docker data, deploy a fresh Ocata cluster
/vagrant/ocata/ocata.sh
# Actually we only need the DB right now, so stop everything but that.
/vagrant/ocata/stop_ocata_services.sh
# Put the migrated DB dump into MariaDB
/vagrant/ocata/restore_dump.sh
# Redeploy with kolla-ansible again so service users and endpoints are re-made.
/vagrant/ocata/redeploy.sh
# Get the openstack client
cd /home/vagrant
virtualenv ocata-venv
source ocata-venv/bin/activate
pip install python-openstackclient
source admin-openrc.sh
# As you can see the old server you booted is still there
openstack server list
# However it's not actually running if you check ps.
ps aux | grep qemu
# This can simply be fixed with a stop/start.
openstack server stop demo1
openstack server start demo1
ps aux | grep qemu
# Let's boot up another server to make sure that works
openstack server create --flavor m1.tiny --image cirros --key-name demo-keypair --nic net-id=$(openstack network list -f value -c ID) demo2
openstack server list
ps aux | grep qemu
```
