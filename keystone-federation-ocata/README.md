# Keystone Federation
> Oath's approach to Keystone federation

This repository contains a patch and plugin that adds a new
auth\_method to keystone called "athenz\_token." This auth method uses the Athenz plugin to authenticate users based on the Athenz token the OpenStack client passes.

Once the plugin validates and authenticates the token, the users, projects
and roles are created with consistent UUIDs using the following hash function
`uuid.uuid3(uuid.NAMESPACE_OID, str(string)).hex`. This results in the UUIDs being consistent
across the clusters that use this plugin, enabling the federation of other services like Glance. 

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [License](#license)

## Background

One of the discussions that occurred during the Edge Working Group meetings at the [OpenStack PTG in Denver](https://www.openstack.org/ptg/)related to keystone federation in
edge environments. Oath has used an external RBAC and integrated it into keystone
to federate various EDGE clusters. This repository has the plugin that integrates Athenz,
our external Role-Based Authorization (RBAC) system, with keystone.

## Install

To use this plugin, you will first need to install [Athenz](http://www.athenz.io/). Apply the patch to Keystone (stable/ocata) and include the plugin in the keystone source tree. Edit `/etc/keystone/keystone.conf` to add `athenz_token` as an auth\_method under [auth] section.

## Usage
### athenz\_token.py
This is a helper module that the plugin uses to validate the athenz\_token.
This script cryptographically validates and parses the athenz\_token to be used by the
plugin.

### athenz.py
This is the main plugin that implements the athenz\_token auth method. It validates the athenz\_token (from external IDP) and uses the attributes in the Athenz token to create users, projects and roles with consistent UUIDs if they don't already exist in Keystone. Finally, it proceeds to generate
the configured keystone token.


## License
This project is licensed under the terms of the [Apache 2.0](LICENSE-Apache-2.0) open source license. Please refer to [LICENSE](LICENSE) for the full terms.
