===============================================
Affinity/Anti Affinity of instances in a groups
===============================================

This task can be divided into two separate parts. First is a change of behavior
of host aggregates, to be able to include ironic nodes. Second, involves
changes to the scheduler to support spreading instances across various groups.

Questions
---------

There are several ways that aggregate (anti)affinity could be defined
expressed.

#. Pass through hints, both information about server group and condition for
   server placement against host aggregates:

   .. code:: shell-session

      openstack aggregate-create rack1
      openstack aggregate-create rack2
      openstack aggregate-set-metadata rack1 rack=1
      openstack aggregate-set-metadata rack2 rack=1
      openstack aggregate-add-host rack1 <UUID of Ironic node A>
      openstack aggregate-add-host rack2 <UUID of Ironic node B>
      openstack server-group-create not-same-rack anti-affinity
      openstack server create --image=IMAGE_ID --flavor=1 \
          --hint group=not-same-rack --hint property=rack

#. Implement own policies to set on instance groups, like
   ``rack_antiaffinity``, ``pz_antiaffinity`` etc, and than during boot time
   just pass a server group name. For instance:

   .. code:: shell-session

      openstack aggregate-create rack1
      openstack aggregate-create rack2
      openstack aggregate-set-metadata rack1 rack=1
      openstack aggregate-set-metadata rack2 rack=1
      openstack aggregate-add-host rack1 <UUID of Ironic node A>
      openstack aggregate-add-host rack2 <UUID of Ironic node B>
      openstack server-group-create not-same-rack rack-anti-affinity
      openstack server create --image=IMAGE_ID --flavor=1 \
          --hint group=not-same-rack

#. Hardcode policy into the server group name, but this requires from users, to
   be very strict about naming of server groups:

   .. code:: shell-session

      openstack aggregate-create rack1
      openstack aggregate-create rack2
      openstack aggregate-set-metadata rack1 rack=1
      openstack aggregate-set-metadata rack2 rack=1
      openstack aggregate-add-host rack1 <UUID of Ironic node A>
      openstack aggregate-add-host rack2 <UUID of Ironic node B>
      openstack server-group-create rack-<unique-name> anti-affinity
      openstack server create --image=IMAGE_ID --flavor=1 \
          --hint group=rack-<unique-name>

Which solution should we take?
