..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

==========================================
IP quota per Subnet
==========================================

Neutron doesn't provide a way to specify IP quota per subnet per tenant. This
is really crucial in environments with many shared subnets (e.g. each rack has
its own subnet) and administrators want to forbid draining all IPs by one
tenant.

This spec describes how to extend neutron IPAM to add IP quota per subnet.


Problem Description
===================

Currently Neutron isn't able to limit use of IPs per tenant except:

* a) Fixed-ips quota - Number of fixed IP addresses allowed per tenant. This
  number must be equal to or greater than the number of allowed instances.

* b) Subnet pools quota - with IPv4, the ``default-quota`` can be set to the
  number of absolute addresses any given project is allowed to consume from
  the pool. With IPv6 it is a little different. It is not practical to count
  individual addresses. To avoid ridiculously large numbers, the quota is
  expressed in the number of /64 subnets which can be allocated. [1]_

Subnet pool quota is not flexible enough because in environments with many
subnets, administrators have to create a new subnet pool per subnet to limit
IPs usage per subnet.


Proposed Change
===============

Overview
________

With this spec we propose to implement IP quota per subnet per tenant mechanism
similar to subnet pool quota [1]_.

The feature consist of:

* IP quota per subnet is the number of absolute addresses any given project is
  allowed to consume from the subnet (similar as in subnet pools)

* Operator is able to set/change/remove/view quota via API or OpenStack client


Solution proposed
_________________

Adding new attribute ``default-quota`` to ``Subnet`` resource to represent the
number of IPs that each tenant can use. The default value `-1` means unlimited
quota.

Adding IP quota per subnet check in ``generate_ip`` method [2]_in case of
exceeding quota the ``SubnetPoolQuotaExceeded`` exception will be thrown.


Data Model Impact
_________________

A new attribute will be added to the ``Subnet`` object.

+--------------+----+--------------+
|Attribute name|Type|Default Value |
+==============+====+==============+
|default-quota |int |-1            |
+--------------+----+--------------+


Command Line Client Impact
__________________________

Create subnet:

.. code-block:: shell-session

   $ openstack subnet create [--default-quota <number_of_ips>] <subnet>

Update attribute of subnet:

.. code-block:: shell-session

   $ openstack subnet set [--default-quota <number_of_ips>] <subnet>

Argument ``--default-quota`` is optional.


References
==========

.. [1] `Subnet pools quota <https://docs.openstack.org/ocata/networking-guide/config-subnet-pools.html#quotas>`
.. [2] `generate_ip method <https://github.com/openstack/neutron/blob/stable/ocata/neutron/ipam/drivers/neutrondb_ipam/driver.py#L154>`
