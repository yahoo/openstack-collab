..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

=============================================
Quota Check Based on Placement Resource Class
=============================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/nova/+spec/example

This spec proposes a way to count the quota based on the placement resource
class.

Problem description
===================

There are two problems need to be resolved for the current quota system in
Nova:

* Nova only supports very few built-in resources quota checks. But actually,
  Nova isn't limited to manage just those few build-in resources. Currently,
  Nova also supports GPU, PCI/SRIOV. With placement service, the user also can
  define a custom resource, but also expected to be count by the quota system.
  Just like the Baremetal users, the operator wants to limit the usages for a
  specific kind of Baremetal node.

Use Cases
---------

* The bare-metal operator wants to count the quota of specific kind of BM node.
* The operator wants to count the quota for a custom resources which is
  traced by the placement.

Proposed change
===============

The proposal is going to:
* Keep the existed built-in quota works as before.
* Re-use the existed Quota REST API and DB table to store the quota limit.
* Count the usages by the Placement API.
* When booting the instance, the resource classes in the flavor extra spec
  will be count by the quota system.

In this proposal, there is nothing change for the existed build-in quotas, it
will works as before and basically same code path.

Reuse the existed `/os-quota-sets` API to query and update the quota limit,
the API schema for `PUT /os-quota-sets/{project_id}?user_id={user_id}` will be
allowed to specific a quota limit for a specific placement resource class.

Using the Placement `GET /usages` API to implement the quota
usage count.

For a specific user and project's resource usage, which is traced by the
placement, can be queried by::

  GET /usages?project_id=<project_id>&user_id=<user_id>

  Responses:

  {
    "usages": {
        "CUSTOM_RC_BAREMETAL_GOLD": 2,
        "DISK_GB": 2,
        "MEMORY_MB": 256,
        "VCPU": 2
    }
  }

This API is already supported in Pike release with placement microversion 1.10.

When booting an instance, if there is any resource class specified by the
flavor extra spec, and there is quota limit for that resource class, then the
quota limit will be checked for this resource class.

Alternatives
------------

N/A

Data model impact
-----------------

N/A

REST API impact
---------------

This spec proposes to change the API schema of
`PUT /os-quota-sets/{project_id}` to accept extra properties than the built-in
quotas.

To create/update a quota limit for a resource class, the request is as below::

  PUT /os-quota-sets/{project_id}
  
  {
     'CUSTOM_RC_BAREMETAL_GOLD': 10
  }

Then you can query the quota and the usages by the API `GET /quotas` and
`GET /quotas/detail``.

Security impact
---------------

N/A

Notifications impact
--------------------

N/A

Other end user impact
---------------------

N/A

Performance Impact
------------------

When checking the quota for a resource class, there is REST API call to the
placement API to get the usages. All the resource classes` usage can be
done that single API call. The performance should be ok.

Other deployer impact
---------------------

* The existed quotas still work as before, so there is nothing change.
* To check quota for a resource class, the deployer needs to ensure the
  flavor consume for that resource class, and there is quota limit in the
  system for that resource class.

Developer impact
----------------

N/A

Implementation
==============

Assignee(s)
-----------

Who is leading the writing of the code? Or is this a blueprint where you're
throwing it out there to see who picks it up?

If more than one person is working on the implementation, please designate the
primary author and contact.

Primary assignee:
  <launchpad-id or None>

Other contributors:
  <launchpad-id or None>

Work Items
----------

* Add PlacementCountableResource to the quota system
* Enable os-quota-sets API to accept resource class
* Count the quota for the resource class in the flavor
* Enable python-novacilent work with API change.

Dependencies
============

N/A

Testing
=======

Add related unit tests and functional tests.

Documentation Impact
====================

N/A

References
==========

N/A

History
=======

Optional section intended to be used each time the spec is updated to describe
new design, API or any database schema updated. Useful to let reader understand
what's happened along the time.

.. list-table:: Revisions
   :header-rows: 1

   * - Release Name
     - Description
   * - Pike
     - Introduced
