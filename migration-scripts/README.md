# Migration-Scripts

> Scripts and tools to migrate to the OpenStack Ocata release.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [Contribute](#contribute)
- [License](#license)

## Background

We needed to update Oath's OpenStack deployment from Juno to the Ocata release, and we realized there weren't any good resources for doing this. So, we wrote our own. If you're using OpenStack Juno and need to upgrade to Ocata (this can also be adapted for other releases), these scripts might be what you need.

## Install

No installation is necessary, the main script will install Python and all other necessary packages for the migration.

## Usage

Available scripts include:
* clone.sh - Used to clone all repositories that are required for the DB migration.
* cp_build.sh - Copies build.tar.gz to all db hosts.
* do_migration.sh - Migrates hosts to Ocata.
* remove_deleted_instances.py - Remove instances that are deleted in the process.

Each of these scripts can be run with the -h flag for more details.

Here's an example of the DB migration command:

```
./do_migration.sh <RW_HOSTNAME> 3306 root `sudo keydbgetkey mysqlroot` "rabbit://ostk_rabbit_user:<PASSWORD>@<MQ1HOST>:5672/ostk_rabbit_vhost" mysql+pymysql://nova:<NOVA_PASSWORD>@<RW_HOSTNAME>:3306
```

## Contribute

Please refer to [the contributing.md file](Contributing.md) for information about how to get involved. We welcome issues, questions, and pull requests. Pull Requests are welcome.

## License

This project is licensed under the terms of the MIT open source license. Please refer to [LICENSE](LICENSE) for the full terms.
