#!/usr/bin/env python
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.
"""
Usage:
./remove_deleted_instances.py <db_host> <db_user> <db_pass>
"""

import mysql.connector
import sys

def tuple_to_dict(cur, tup):
    return dict(zip(cur.column_names, tup))

uuids = []

cnx = mysql.connector.connect(host=sys.argv[1], user=sys.argv[2],  passwd=sys.argv[3], db="nova")
cur1 = cnx.cursor()
cur = cnx.cursor()
cur.execute("SELECT * FROM  `instances` WHERE  `deleted_at` IS NOT NULL")
for row in cur.fetchall():
    row = tuple_to_dict(cur, row)
    uuids.append(row['uuid']);

if len(uuids) <= 1:
    sys.exit(0)

cur1.execute("SET FOREIGN_KEY_CHECKS = 0;")

uuids = tuple(str(u) for u in uuids)
cur.execute("DELETE FROM instance_id_mappings where uuid IN {}".format(uuids))
cur.execute("DELETE FROM instance_info_caches where instance_uuid IN {}".format(uuids))
cur.execute("DELETE FROM instance_system_metadata where instance_uuid IN {}".format(uuids))
cur.execute("DELETE FROM security_group_instance_association where instance_uuid IN {}".format(uuids))
cur.execute("DELETE FROM instances where uuid IN {}".format(uuids))
cnx.commit()

cur1.execute("SET FOREIGN_KEY_CHECKS = 1;")
cnx.close()
