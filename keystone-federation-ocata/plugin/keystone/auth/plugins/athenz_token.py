# Copyright 2018, Oath Inc
# Licensed under the terms of the Apache 2.0 license. See LICENSE file in for terms.

import base64
import json
import time
import re
from collections import defaultdict

import asn1
import M2Crypto.m2 as m2
import M2Crypto.EVP as EVP
import M2Crypto.RSA as RSA
import M2Crypto.EC as EC
import M2Crypto.BIO as BIO
from oslo_log import log

ATHENZ_CONF = {}
# gap in seconds, to determine whether given token is about to expire
STALE_TOKEN_DURATION = 300
OWS_ATHENZ_DOMAIN = 'ows.projects'
OID_ALGORITHMS = {
    "1.2.840.113549.1.1.1": RSA,
    "1.2.840.10045.2.1": EC
}
LOG = log.getLogger(__name__)


def get_athenz_conf():
    """Return dict of Athenz public keys."""
    if not ATHENZ_CONF:
        with open('/etc/athenz/athenz.conf') as conf_file:
            ATHENZ_CONF.update(json.load(conf_file))
        ATHENZ_CONF['zmsPublicKeys'] = {x['id']: x['key'] for x in ATHENZ_CONF['zmsPublicKeys']}
        ATHENZ_CONF['ztsPublicKeys'] = {x['id']: x['key'] for x in ATHENZ_CONF['ztsPublicKeys']}
    return ATHENZ_CONF


def get_key_algorithm(public_key):
    """Given a public key, return the algorithm type it uses.
    Currently only supports EC and RSA."""
    key_data = '\n'.join(public_key.split('\n')[1:-1])
    key_bytes = base64.b64decode(key_data)
    decoder = asn1.Decoder()
    decoder.start(key_bytes)
    tag = decoder.peek()
    while tag.nr != asn1.Numbers.ObjectIdentifier:
        decoder.enter()
        tag = decoder.peek()
    _, oid = decoder.read()
    return OID_ALGORITHMS[oid]


def decode_y64(b64_data):
    """Decode Yahoo's version of base64 and return result."""
    return str(base64.b64decode(b64_data.replace('-', '=').replace('.', '+').replace('_', '/')))


def is_athenz_role_token(token):
    """Return True IFF token is a role token. Else False."""
    return token.startswith('v=Z1;')


class YahooPKey(EVP.PKey):

    def assign_key(self, key):
        if hasattr(key, 'ec'):
            self.assign_ec(key)
        else:
            self.assign_rsa(key)

    def assign_ec(self, ec):
        ret = m2.pkey_assign_ec(self.pkey, ec.ec)
        if ret:
            ec._pyfree = 0
        return ret


class AthenzToken(object):
    """Wrapper around an Athenz Role Token."""

    ROLE_PROJECT_REGEX = re.compile('^(.+?)\\.([^.]+?)$')

    def __init__(self, token):
        if not is_athenz_role_token(token):
            raise ValueError("Must provide valid role token.")

        self.raw_token = token
        self.attrs = dict(a.split('=') for a in token.split(';'))
        self._projects = defaultdict(set)

    @property
    def expire_time(self):
        """Returns int of the UTC Unix Time when the token will expire."""
        return int(self.attrs['e'])

    @property
    def user(self):
        """Return the username if the principal is a user. Else return None."""
        if self.attrs['p'].startswith('user.'):
            return self.attrs['p'].split('.')[1]
        else:
            return self.attrs['p']

    @property
    def domain(self):
        """Return the Athenz Domain of the token."""
        return self.attrs['d']

    @property
    def roles(self):
        """Return a list of Athenz Roles in this token."""
        return self.attrs['r'].split(',')

    @property
    def signature(self):
        """Returns un-encoded signature of the token."""
        return decode_y64(self.attrs['s'])

    @property
    def key_id(self):
        """Key ID for the athenz_config public key."""
        return self.attrs['k']

    @property
    def projects(self):
        """Returns a defaultdict of type
        `keystone role`->`set of keystone projects`."""
        if not self._projects:
            for role in self.roles:
                matches = re.search(AthenzToken.ROLE_PROJECT_REGEX, role)
                if matches:
                    keystone_project = matches.groups()[0]
                    keystone_role = matches.groups()[1]
                    self._projects[keystone_role].add(keystone_project)
        return self._projects

    @property
    def unsigned_raw_token(self):
        """Return the raw unsigned athenz token."""
        return str(self.raw_token[:self.raw_token.index(';s=')])

    def validate(self, username):
        """Return True IFF this token has been signed by Athenz,
        has not expired, and the given username matches. Else return False."""
        # Ensure token hasn't expired
        # We pad STALE_TOKEN_DURATION to the current time because we want to
        # make  sure that the token won't expire in the foreseable future
        if self.expire_time < time.time() + STALE_TOKEN_DURATION:
            return False

        # Validate username matches
        if self.user != username:
            return False

        # Only accept tokens in the ows.projects Athenz domain
        if self.domain != OWS_ATHENZ_DOMAIN:
            return False

        # Retrieve proper pub key from athenz_config package
        pub_keys = get_athenz_conf()
        public_key = decode_y64(pub_keys['ztsPublicKeys'][self.key_id])
        algorithm = get_key_algorithm(public_key)
        loaded_pub_key = algorithm.load_pub_key_bio(BIO.MemoryBuffer(public_key))

        # Verify cryptographic signature
        unsigned_token = self.unsigned_raw_token
        verifier = YahooPKey(md='sha256')
        verifier.assign_key(loaded_pub_key)
        verifier.verify_init()
        verifier.verify_update(unsigned_token)
        result = verifier.verify_final(self.signature)
        return result == 1
