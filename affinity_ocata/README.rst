Aggregate affinity
==================

This series of patches adds ability for creating aggregation of ironic nodes in
Nova. This work is based on work of `Jay Pipes series`_ back ported to Ocata,
with some additional fixes.

After applying those patches on Ocata tree nova and novaclient, it will be
possible to create aggregates which contain ironic nodes and a group with one
of two new policies:

* aggregate-affinity
* aggregate-anti-affinity

Note, that if openstackclient is used, it is needed to overwrite
``OS_COMPUTE_API_VERSION`` environment variable to value ``2.43``.

Given, that we are working on devstack, and have available four Ironic nodes
(it need to be changed in devstacks' ``local.conf`` by setting variable
``IRONIC_VM_COUNT`` to ``4``), basic flow to test it is as follows:

.. code:: shell-session

   $ export OS_COMPUTE_API_VERSION=2.43
   $ openstack aggregate create rack1
   $ openstack aggregate create rack2
   $ openstack aggregate add host rack1 $(openstack baremetal node list|grep node-0|awk '{print $2}')
   $ openstack aggregate add host rack1 $(openstack baremetal node list|grep node-1|awk '{print $2}')
   $ openstack aggregate add host rack2 $(openstack baremetal node list|grep node-2|awk '{print $2}')
   $ openstack aggregate add host rack2 $(openstack baremetal node list|grep node-3|awk '{print $2}')
   $ openstack server group create --policy aggregate-anti-affinity group1
   $ openstack server create \
         --image=$(openstack image list|grep x86_64-disk| awk '{print $2}') \
         --flavor=1 \
         --nic net-id=$(openstack network list |grep private | awk '{print $2}') \
         --hint group=$(openstack server group list | grep group1 | awk '{print $2}') \
         instance1
   $ openstack server create \
         --image=$(openstack image list|grep x86_64-disk| awk '{print $2}') \
         --flavor=1 \
         --nic net-id=$(openstack network list |grep private | awk '{print $2}') \
         --hint group=$(openstack server group list | grep group1 | awk '{print $2}') \
         instance2

this should place two ironic instances on two different *rack* aggregates. In
similar fashion it might be group created with policy ``aggregate-affinity``.


Soft aggregate affinity
=======================

This is similar feature to `soft (anti) affinity* feature`_ which was
done for compute hosts. There are two new weight introduced:

* aggregate-soft-affinity
* aggregate-soft-anti-affinity

and can be used for scattering instances between two aggregates within
an instance group with two policies - to keep instances within an
aggregate (affinity), or to spread them around on different aggregates.
If there would be not possible to put an instance together on an
aggregate (in case of affinity) or on different one (in case of
anti-affinity), it will be placed in specified group anyway.

Simple usage is as follows, using environment described above in
*aggregate-affinity* feature:

.. code:: shell-session

   $ export OS_COMPUTE_API_VERSION=2.43
   $ openstack aggregate create rack1
   $ openstack aggregate create rack2
   $ openstack aggregate add host rack1 $(openstack baremetal node list|grep node-0|awk '{print $2}')
   $ openstack aggregate add host rack1 $(openstack baremetal node list|grep node-1|awk '{print $2}')
   $ openstack aggregate add host rack2 $(openstack baremetal node list|grep node-2|awk '{print $2}')
   $ openstack aggregate add host rack2 $(openstack baremetal node list|grep node-3|awk '{print $2}')
   $ openstack server group create --policy aggregate-soft-anti-affinity group1
   $ openstack server create \
         --image=$(openstack image list|grep x86_64-disk| awk '{print $2}') \
         --flavor=1 \
         --nic net-id=$(openstack network list |grep private | awk '{print $2}') \
         --hint group=$(openstack server group list | grep group1 | awk '{print $2}') \
         instance1
   $ openstack server create \
         --image=$(openstack image list|grep x86_64-disk| awk '{print $2}') \
         --flavor=1 \
         --nic net-id=$(openstack network list |grep private | awk '{print $2}') \
         --hint group=$(openstack server group list | grep group1 | awk '{print $2}') \
         instance2
   $ openstack server create \
         --image=$(openstack image list|grep x86_64-disk| awk '{print $2}') \
         --flavor=1 \
         --nic net-id=$(openstack network list |grep private | awk '{print $2}') \
         --hint group=$(openstack server group list | grep group1 | awk '{print $2}') \
         instance3

Unlike in ``aggregate-anti-affinity`` policy, creating ``instance3`` will
pass, since regardless of not available aggregate with no group members, it
will be placed in the group anyway on one of the available host within the
group.


Configuration
-------------

As for soft aggregate (anti) affinity there is another limitation, which comes
with how weights works right now in Nova. Because of `this commit`_ change of
behaviour was introduced on how scheduler selects hosts. It's concerns all of
affinity/anti-affinity weights, not only this particular newly added for
aggregation.

That change introduce a blind selection of the host form a group of the weighed
hosts, which are originally sorted from best fitting. For affinity weight it
will always return full list of the hosts (since they are not a filters), which
is ordered from best to worst hosts. There is a high chance, that ``nova.conf``
will need to have a scheduler filter option ``host_subset_size`` set to ``1``,
like:

.. code:: ini

   [filter_scheduler]
   host_subset_size = 1


Creation of instances in a bulk
===============================

Unfortunately, creating instance in bulk isn't possible. Here is a full
explanation.

Currently, if we schedule a bulk creation for ironic instances, (or any bulk
creation of instances) filtered_scheduler will perform a filtering on each
available hosts on each requested instance.

Let's take an example, that we have 4 available ironic hosts, divided in two
groups with *aggregate-affinity* policy:

.. code:: shell-session

   ubuntu@ubuntu ~/devstack ◆ (stable/ocata) $ openstack baremetal node list
   +--------------------------------------+--------+---------------+-------------+--------------------+-------------+
   | UUID                                 | Name   | Instance UUID | Power State | Provisioning State | Maintenance |
   +--------------------------------------+--------+---------------+-------------+--------------------+-------------+
   | 959734ed-8dda-4878-9d5c-ddd9a95b65ec | node-0 | None          | power off   | available          | False       |
   | c105d862-2eca-4845-901e-cd8194a39248 | node-1 | None          | power off   | available          | False       |
   | a204e33f-6803-4d92-ad47-5b6928e3cede | node-2 | None          | power off   | available          | False       |
   | 6ee27372-884d-4db4-af27-f697fffcb7c0 | node-3 | None          | power off   | available          | False       |
   +--------------------------------------+--------+---------------+-------------+--------------------+-------------+
   ubuntu@ubuntu ~/devstack ◆ (stable/ocata) $ openstack server group list
   +--------------------------------------+--------+--------------------+
   | ID                                   | Name   | Policies           |
   +--------------------------------------+--------+--------------------+
   | 0b96ffc0-8e96-4613-b9a8-ea4e6c7ff0e8 | group1 | aggregate-affinity |
   +--------------------------------------+--------+--------------------+
   ubuntu@ubuntu ~/devstack ◆ (stable/ocata) $ openstack aggregate list
   +----+-------+-------------------+
   | ID | Name  | Availability Zone |
   +----+-------+-------------------+
   |  1 | rack1 | None              |
   |  2 | rack2 | None              |
   +----+-------+-------------------+
   ubuntu@ubuntu ~/devstack ◆ (stable/ocata) $ openstack aggregate show rack1
   +-------------------+------------------------------------------------------------------------------------+
   | Field             | Value                                                                              |
   +-------------------+------------------------------------------------------------------------------------+
   | availability_zone | None                                                                               |
   | created_at        | 2018-02-21T08:10:35.000000                                                         |
   | deleted           | False                                                                              |
   | deleted_at        | None                                                                               |
   | hosts             | [u'959734ed-8dda-4878-9d5c-ddd9a95b65ec', u'c105d862-2eca-4845-901e-cd8194a39248'] |
   | id                | 1                                                                                  |
   | name              | rack1                                                                              |
   | properties        |                                                                                    |
   | updated_at        | None                                                                               |
   | uuid              | bf7a251a-edff-4688-81d7-d6cf8b201847                                               |
   +-------------------+------------------------------------------------------------------------------------+
   ubuntu@ubuntu ~/devstack ◆ (stable/ocata) $ openstack aggregate show rack2
   +-------------------+------------------------------------------------------------------------------------+
   | Field             | Value                                                                              |
   +-------------------+------------------------------------------------------------------------------------+
   | availability_zone | None                                                                               |
   | created_at        | 2018-02-21T08:10:37.000000                                                         |
   | deleted           | False                                                                              |
   | deleted_at        | None                                                                               |
   | hosts             | [u'a204e33f-6803-4d92-ad47-5b6928e3cede', u'6ee27372-884d-4db4-af27-f697fffcb7c0'] |
   | id                | 2                                                                                  |
   | name              | rack2                                                                              |
   | properties        |                                                                                    |
   | updated_at        | None                                                                               |
   | uuid              | 7ca81b0e-2a87-4d41-af1b-b688aedc7b25                                               |
   +-------------------+------------------------------------------------------------------------------------+

Next, given that we are able to have only two nodes in each aggregare, lets
create two instances in a bulk:

.. code:: shell-session

   ubuntu@ubuntu ~/devstack ◆ (stable/ocata) $ openstack server create \
   --image=$(openstack image list|grep x86_64-disk|awk '{print $2}') \
   --flavor=1 \
   --nic net-id=$(openstack network list|grep private|awk '{print $2}') \
   --hint group=$(openstack server group list|grep group1|awk '{print $2}') \
   --min 2 --max 2 instance

which will results running a filters, like those from scheduler logs:

.. code:: shell-session
   :number-lines:

   2018-02-21 09:16:53.303 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter RetryFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.304 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter AvailabilityZoneFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.304 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter RamFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.304 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter DiskFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.305 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ComputeFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.305 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ComputeCapabilitiesFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.305 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ImagePropertiesFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.305 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ServerGroupAntiAffinityFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.306 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ServerGroupAffinityFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.306 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter SameHostFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.306 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter DifferentHostFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.306 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ServerGroupAggregateAffinityFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.307 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ServerGroupAggregateAntiAffinityFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.307 DEBUG nova.scheduler.filter_scheduler [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filtered [(ubuntu, c105d862-2eca-4845-901e-cd8194a39248) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, (ubuntu, a204e33f-6803-4d92-ad47-5b6928e3cede) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, (ubuntu, 6ee27372-884d-4db4-af27-f697fffcb7c0) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, (ubuntu, 959734ed-8dda-4878-9d5c-ddd9a95b65ec) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0] from (pid=11395) _schedule /opt/stack/nova/nova/scheduler/filter_scheduler.py:115
   2018-02-21 09:16:53.307 DEBUG nova.scheduler.filter_scheduler [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Weighed [WeighedHost [host: (ubuntu, c105d862-2eca-4845-901e-cd8194a39248) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, weight: 2.0], WeighedHost [host: (ubuntu, a204e33f-6803-4d92-ad47-5b6928e3cede) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, weight: 2.0], WeighedHost [host: (ubuntu, 6ee27372-884d-4db4-af27-f697fffcb7c0) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, weight: 2.0], WeighedHost [host: (ubuntu, 959734ed-8dda-4878-9d5c-ddd9a95b65ec) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, weight: 2.0]] from (pid=11395) _schedule /opt/stack/nova/nova/scheduler/filter_scheduler.py:120
   2018-02-21 09:16:53.308 DEBUG nova.scheduler.filter_scheduler [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Selected host: WeighedHost [host: (ubuntu, a204e33f-6803-4d92-ad47-5b6928e3cede) ram: 1280MB disk: 10240MB io_ops: 0 instances: 0, weight: 2.0] from (pid=11395) _schedule /opt/stack/nova/nova/scheduler/filter_scheduler.py:127
   2018-02-21 09:16:53.308 DEBUG oslo_concurrency.lockutils [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Lock "(u'ubuntu', u'a204e33f-6803-4d92-ad47-5b6928e3cede')" acquired by "nova.scheduler.host_manager._locked" :: waited 0.000s from (pid=11395) inner /usr/local/lib/python2.7/dist-packages/oslo_concurrency/lockutils.py:270
   2018-02-21 09:16:53.308 DEBUG oslo_concurrency.lockutils [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Lock "(u'ubuntu', u'a204e33f-6803-4d92-ad47-5b6928e3cede')" released by "nova.scheduler.host_manager._locked" :: held 0.000s from (pid=11395) inner /usr/local/lib/python2.7/dist-packages/oslo_concurrency/lockutils.py:282
   2018-02-21 09:16:53.308 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Starting with 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:70

so, for the first iteration, filters return all four nodes (new aggregate
filters are on lines 12 and 13), which can be used to fulfill the request. Next
second iteration is done:

.. code:: shell-session
   :number-lines:

   2018-02-21 09:16:53.310 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter RetryFilter returned 4 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.310 DEBUG nova.scheduler.filters.ram_filter [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] (ubuntu, a204e33f-6803-4d92-ad47-5b6928e3cede) ram: 0MB disk: 0MB io_ops: 0 instances: 0 does not have 512 MB usable ram, it only has 0.0 MB usable ram. from (pid=11395) host_passes /opt/stack/nova/nova/scheduler/filters/ram_filter.py:61
   2018-02-21 09:16:53.310 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter RamFilter returned 3 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.310 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter DiskFilter returned 3 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.310 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ServerGroupAntiAffinityFilter returned 3 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.311 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ServerGroupAffinityFilter returned 3 host(s) from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:104
   2018-02-21 09:16:53.311 DEBUG nova.scheduler.filters.affinity_filter [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] aggregate-affinity: check if set([1]) is a subset of set([]),host nodes: set([u'ubuntu']) from (pid=11395) host_passes /opt/stack/nova/nova/scheduler/filters/affinity_filter.py:213
   2018-02-21 09:16:53.311 DEBUG nova.scheduler.filters.affinity_filter [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] aggregate-affinity: check if set([2]) is a subset of set([]),host nodes: set([u'ubuntu']) from (pid=11395) host_passes /opt/stack/nova/nova/scheduler/filters/affinity_filter.py:213
   2018-02-21 09:16:53.311 DEBUG nova.scheduler.filters.affinity_filter [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] aggregate-affinity: check if set([1]) is a subset of set([]),host nodes: set([u'ubuntu']) from (pid=11395) host_passes /opt/stack/nova/nova/scheduler/filters/affinity_filter.py:213
   2018-02-21 09:16:53.312 INFO nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filter ServerGroupAggregateAffinityFilter returned 0 hosts
   2018-02-21 09:16:53.312 DEBUG nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filtering removed all hosts for the request with instance ID '9a7f787c-5074-4af3-80a2-38eaecf882a2'. Filter results: [('RetryFilter', [(u'ubuntu', u'c105d862-2eca-4845-901e-cd8194a39248'), (u'ubuntu', u'a204e33f-6803-4d92-ad47-5b6928e3cede'), (u'ubuntu', u'6ee27372-884d-4db4-af27-f697fffcb7c0'), (u'ubuntu', u'959734ed-8dda-4878-9d5c-ddd9a95b65ec')]), ('RamFilter', [(u'ubuntu', u'c105d862-2eca-4845-901e-cd8194a39248'), (u'ubuntu', u'6ee27372-884d-4db4-af27-f697fffcb7c0'), (u'ubuntu', u'959734ed-8dda-4878-9d5c-ddd9a95b65ec')]), ('DiskFilter', [(u'ubuntu', u'c105d862-2eca-4845-901e-cd8194a39248'), (u'ubuntu', u'6ee27372-884d-4db4-af27-f697fffcb7c0'), (u'ubuntu', u'959734ed-8dda-4878-9d5c-ddd9a95b65ec')]), ('ServerGroupAntiAffinityFilter', [(u'ubuntu', u'c105d862-2eca-4845-901e-cd8194a39248'), (u'ubuntu', u'6ee27372-884d-4db4-af27-f697fffcb7c0'), (u'ubuntu', u'959734ed-8dda-4878-9d5c-ddd9a95b65ec')]), ('ServerGroupAffinityFilter', [(u'ubuntu', u'c105d862-2eca-4845-901e-cd8194a39248'), (u'ubuntu', u'6ee27372-884d-4db4-af27-f697fffcb7c0'), (u'ubuntu', u'959734ed-8dda-4878-9d5c-ddd9a95b65ec')]), ('ServerGroupAggregateAffinityFilter', None)] from (pid=11395) get_filtered_objects /opt/stack/nova/nova/filters.py:129
   2018-02-21 09:16:53.312 INFO nova.filters [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Filtering removed all hosts for the request with instance ID '9a7f787c-5074-4af3-80a2-38eaecf882a2'. Filter results: ['RetryFilter: (start: 4, end: 4)', 'RamFilter: (start: 4, end: 3)', 'DiskFilter: (start: 3, end: 3)', 'ServerGroupAntiAffinityFilter: (start: 3, end: 3)', 'ServerGroupAffinityFilter: (start: 3, end: 3)', 'ServerGroupAggregateAffinityFilter: (start: 3, end: 0)']
   2018-02-21 09:16:53.312 DEBUG nova.scheduler.filter_scheduler [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] There are 1 hosts available but 2 instances requested to build. from (pid=11395) select_destinations /opt/stack/nova/nova/scheduler/filter_scheduler.py:76
   2018-02-21 09:16:53.312 DEBUG oslo_messaging.rpc.server [req-6b671371-ea58-4b1d-8657-a6376d2d1d88 admin admin] Expected exception during message handling () from (pid=11395) _process_incoming /usr/local/lib/python2.7/dist-packages/oslo_messaging/rpc/server.py:158

This time, as we can see in line 10, *ServerGroupAffinityFilter* returns 0
hosts. A log lines 7-9 gives us a hint, that none of the candidates fulfill
requirement, which looks like this (I've removed some comments and non
interesting parts for readability):

.. code:: python
   :number-lines:

    def host_passes(self, host_state, spec_obj):
        # ...
        host_aggs = set(agg.id for agg in host_state.aggregates)

        if not host_aggs:
            return self.REVERSE_CHECK

        # Take all hypervisors nodenames and hostnames
        host_nodes = set(spec_obj.instance_group.nodes +
                         spec_obj.instance_group.hosts)

        if not host_nodes:
            # There are no members of the server group yet
            return True

        # Grab all aggregates for all hosts in the server group and ensure we
        # have an intersection with this host's aggregates
        group_aggs = set()
        for node in host_nodes:
            group_aggs |= self.host_manager.host_aggregates_map[node]

        LOG.debug(...)

        if self.REVERSE_CHECK:
            return host_aggs.isdisjoint(group_aggs)
        return host_aggs.issubset(group_aggs

In this filter first we check if host belongs to any aggregate and store it as
a set. If there is an empty set, it means that node either cannot satisfy
aggregate affinity constraint in case of *aggregate-affinity* policy or it's
does satisfy the constraint in case of *aggregate-anti-affinity*.

Next, there is a check for ``instance_group`` hosts and nodes (``nodes`` field
is added for Ironic case, otherwise we don't have Ironic nodes hostnames other
than… hostname which origin from compute service). In case there is no instance
yet created, that means we can pass current host, since there is no hosts in
the group yet.

If we have some nodenames/hostnames in the set, we trying to match host
aggregates with the each nodenames/hostnames (line 20). And here is the issue.
``instance_group`` provided by request spec object (``spec_obj``) have
``hosts`` field filled out during scheduling, but ``nodes`` field not, until
**there is an instance created**, so this is the reason why we can create
instances one by one, but not in the bulk.


.. _Jay Pipes series: https://review.openstack.org/#/q/topic:bp/aggregate-affinity
.. _this commit: https://review.openstack.org/#/c/19823/
.. _soft (anti) affinity* feature: http://specs.openstack.org/openstack/nova-specs/specs/kilo/approved/soft-affinity-for-server-group.html
