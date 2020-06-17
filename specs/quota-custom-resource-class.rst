..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===============================
Quota per custom resource class
===============================

https://blueprints.launchpad.net/nova/+spec/tbd

With this blueprint we introduce a way to define and use quotas per custom
resources classes, so that operator can limit how DC resources are utilized.

Problem description
===================

Currently, quotas in Nova are restricted only for selected resources like CPU
cores, ram, floating IPs, and for non-resource things: number of instances,
metadata items, key pairs, server groups and so on. Introducing `custom
resource classes`_ within placement service, allows operator to create
resources, which are unknown to the quota mechanism.

Use Cases
---------

As an operator I’d like to define quota for custom resource classes, so that
amount of such resources can be limited per project and/or per user.

Proposed change
===============

We propose to add ability for dynamically adding custom resource classes to
resources which ``QuotaEngine`` can handle, and track the usage like all the
other resources.

Alternatives
------------

As an alternative, we could leverage Quota Classes to be used instead of
affecting QuotaEngine, although it will require slightly more effort in
implementation, since there is no tracking of resources within that model, and,
what's more important, quota classes are used for setting/changing defaults
which comes from configuration.

We could also make a custom scheduler filter, which would count the resources
usage and limits for anything operator needs, however this will have
performance impact, since originally limits are checked during API call, and
scheduler filters are executed on scheduling phase.

Data model impact
-----------------

New attribute ``uuid`` will be added to the ``Quotas`` object.

REST API impact
---------------

New API methods will be introduced to list/add/delete/modify to the
``os-quota-sets`` for a project and optionally user.

Optionally, ``GET /os-quota-sets/{tenant_id}`` will provide a list of custom
resources in under ``quota_set["custom_resources"]`` key in JSON response.

* Getting the list of defined custom resources in limits:

  .. code::

     GET /os-quota-sets/{tenant_id}/custom_resource

     200 OK
     Content-Type: application/json

     {
         "custom_resources": [
             {
                 "name": "name of custom resource class",
                 "UUID": "uuid of custom resource class from resource provider",
                 "limit": 0
             },
              ...
         ]
     }

* Getting a definition of the particular custom resources in limits:

  .. code::

     GET /os-quota-sets/{tenant_id}/custom_resource/{resource_uuid}

     200 OK
     Content-Type: application/json

     {
         "name": "name of custom resource class",
         "UUID": "uuid of custom resource class from resource provider",
         "limit": 0
     }

* Adding custom resource to quotas:

  .. code::

     POST /os-quota-sets/{tenant_id}/custom_resource

  with a payload:

  .. code::

     Content-Type: application/json

     {
         "name": "name of custom resource class",
         "UUID": "uuid of custom resource class from resource provider",
         "limit": 0
     }

  Response body is empty. Response code will be ``201 Created`` on success, or
  ``409 Conflict`` if there is resource with such UUID already created.

  * ``200 OK`` on success.
  * ``400 Bad Request`` for bad or invalid syntax.
  * ``409 Conflict`` if there is resource with such UUID already created.

* Updating limit value for the custom resource:

  .. code::

     PUT /os-quota-sets/{tenant_id}/custom_resource/{resource_uuid}

  with a payload:

  .. code::

     Content-Type: application/json

     {
         "limit": 10
     }

  Response body is empty. Response code will be:

  * ``200 OK`` on success.
  * ``400 Bad Request`` for bad or invalid syntax.
  * ``404 Not Found`` on undefined custom resource.

* Removing the custom resource from limits:

  .. code::

     DELETE /os-quota-sets/{tenant_id}/custom_resource/{resource_uuid}

  Request body is empty. Response body is empty. Response code will be:

  * ``200 OK`` on success.
  * ``404 Not Found`` on undefined custom resource.


Security impact
---------------

None

Notifications impact
--------------------

None

Other end user impact
---------------------

Nova-client and/or openstack client should be updated to be able to provide
custom resource class as an argument for ``quota*`` subcommands.

Performance Impact
------------------

None

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

* DB changes
* Hook to register custom resource class in ``QuotaEngine._resources`` dict
* API implementation

Dependencies
============

None

Testing
=======

Unit test have to be provided.

Documentation Impact
====================

Documentation of additional API calls have to be updated.

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

.. _custom resource classes: https://specs.openstack.org/openstack/nova-specs/specs/ocata/implemented/custom-resource-classes.html
