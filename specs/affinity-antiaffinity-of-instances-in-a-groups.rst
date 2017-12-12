..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===============================================
Affinity/Anti Affinity of instances in a groups
===============================================

https://blueprints.launchpad.net/nova/+spec/tbd

This BP proposes a way for creating affinity and anti-affinity for ironic nodes.

Problem description
===================

Currently there is no way to create aggregation for Ironic nodes, instead
aggregates works only for compute nodes, so it is impossible for creating
affinity/anti-affinity rules for such nodes

Use Cases
---------

As a system administrator I want to be able to define aggregation of the Ironic
nodes in Nova, so that I can apply affinity or anti-affinity policy to the
server group.

As a system administrator I want to be able to define aggregation of the Ironic
nodes in Nova, so that I can define logical division of my data center.

Proposed change
===============

This task can be divided into two separate parts. First is a change of behavior
of host aggregates, to be able to include ironic nodes.

Second, involves changes to the scheduler to support spreading instances across
various groups.

Example session, which present the change, could be as follows:

.. code:: shell-session

   openstack aggregate create rack1
   openstack aggregate create rack2
   openstack aggregate set --property rack=1 rack1
   openstack aggregate set --property rack=1 rack2
   openstack aggregate add host rack1 <UUID of Ironic node A>
   openstack aggregate add host rack2 <UUID of Ironic node B>
   openstack server group create --policy rack-anti-affinity not-same-rack
   openstack server create --image=IMAGE_ID --flavor=1 \
       --hint group=not-same-rack server1

First, we create two aggregates which would represent the rack, next we append
a rack metadata set to 1, so it indicate that this aggregate is ``rack`` based,
next we add ironic nodes by their UUID. Next, we create server group, with
desired policy, and finally spin the instance.

Alternatives
------------

None

Data model impact
-----------------

None

REST API impact
---------------

Introduce new microversion for adding new policies for node
(soft)(anti)affinity

Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

None

Performance Impact
------------------

Potentially, there could be performance impact on accessing aggregation
information.

Other deployer impact
---------------------

None

Developer impact
----------------

None

Upgrade impact
--------------

None

Implementation
==============

Assignee(s)
-----------

Primary assignee:
  <launchpad-id or None>

Other contributors:
  <launchpad-id or None>

Work Items
----------

* Allow ironic nodes to be associated with host aggregation
* Add policy for affinity/anti-affinity/soft-affinity/soft-anti-affinity for
  nodes, instead of hypervisors
* Implement scheduler filter for be able to use those policies

Dependencies
============

None

Testing
=======

TBD

Documentation Impact
====================

Documentation of behaviour of creating/removing aggregation should be amended.

References
==========

None

History
=======

.. list-table:: Revisions
   :header-rows: 1

   * - Release Name
     - Description
   * - Rocky
     - Introduced
