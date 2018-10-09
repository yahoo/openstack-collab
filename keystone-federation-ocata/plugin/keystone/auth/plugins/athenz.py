# Copyright 2018, Oath Inc
# Licensed under the terms of the Apache 2.0 license. See LICENSE file for terms.

import ast
import keystone.conf
import six
import sys
import uuid

from keystone.auth.plugins import base
from keystone.common import dependency
from keystone.common import driver_hints
from keystone import exception
from keystone.i18n import _
from oslo_log import log
from yahoo.contrib.ocata_openstack_yahoo_plugins.keystone.auth.plugins.athenz_token import AthenzToken   # noqa
from yahoo.contrib.ocata_openstack_yahoo_plugins.keystone.auth.plugins.athenz_token import is_athenz_role_token  # noqa


LOG = log.getLogger(__name__)
KEYSTONE_CONF = keystone.conf.CONF
METHOD_NAME = 'athenz_token'


class AthenzUserAuthInfo(object):

    @classmethod
    def create(cls, auth_payload, method_name):
        user_auth_info = cls()
        user_auth_info._validate_and_normalize_auth_data(auth_payload)
        user_auth_info.METHOD_NAME = method_name
        return user_auth_info

    def __init__(self):
        self.user_name = None
        self.athenz_token = None
        self.domain_id = None
        self.domain_name = None
        self.project_name = None

    def _validate_and_normalize_auth_data(self, auth_payload):
        if 'user' not in auth_payload:
            raise exception.ValidationError(attribute='user',
                                            target=self.METHOD_NAME)
        user_info = auth_payload['user']
        user_id = user_info.get('id')
        self.user_name = user_info.get('name')
        self.project_name = user_info.get('project_name')
        if not user_id and not self.user_name:
            raise exception.ValidationError(attribute='id or name',
                                            target='user')
        if not self.project_name:
            raise exception.ValidationError(attribute='project name',
                                            target='user')

        if self.user_name:
            if 'domain' not in user_info:
                raise exception.ValidationError(attribute='domain',
                                                target='user')
        self.domain_id = user_info['domain'].get('id')
        self.domain_name = user_info['domain'].get('name')
        if not self.domain_id and not self.domain_name:
            raise exception.ValidationError(attribute='domain id or name',
                                            target='user')

        if 'athenz_token' not in user_info:
            LOG.error("athenz_token not found in user object: %s", user_info)
            raise exception.ValidationError(attribute='athenz_token',
                                            target='user')
        athenz_token = ast.literal_eval(user_info['athenz_token'])['token']
        self.athenz_token = athenz_token


@dependency.requires('identity_api', 'resource_api', 'role_api',
                     'assignment_api')
class AthenzAuthPlugin(base.AuthMethodHandler):

    def generate_consistent_id(self, string):
        """Given string generate a consistent hash"""
        return uuid.uuid3(uuid.NAMESPACE_OID, str(string)).hex

    def _lookup_domain(self, domain_id):
        try:
            self.resource_api.assert_domain_enabled(domain_id)
        except exception.DomainNotFound as e:
            LOG.error("Domain not found: %s", domain_id)
            LOG.warning(six.text_type(e))
            raise exception.Unauthorized(e)

        except AssertionError as e:
            LOG.error("Domain is not enabled: %s", domain_id)
            log.warning(six.text_type(e))
            six.reraise(exception.Unauthorized, exception.Unauthorized(e),
                        sys.exc_info()[2])

    def _create_project(self, request, tenant_ref):
        try:
            return self.resource_api.create_project(tenant_ref['id'],
                                                    tenant_ref,
                                                    request.audit_initiator)
        except (exception.DomainNotFound, exception.ProjectNotFound) as e:
            raise exception.ValidationError(e)

    def _lookup_and_create_project(self, request, project_name, domain_id):
        try:
            return self.resource_api.get_project_by_name(project_name,
                                                         domain_id)
        except exception.ProjectNotFound:
            project_ref = {'id': self.generate_consistent_id(project_name),
                           'name': project_name,
                           'enabled': True,
                           'domain_id': domain_id,
                           'is_domain': False,
                           'parent_id': domain_id,
                           'description': 'Project created by athenz plugin',
                           }
            return self._create_project(request, project_ref)

    def _lookup_and_create_user(self, request, domain_id, uname):
        try:
            return self.identity_api.get_user_by_name(uname, domain_id)
        except exception.UserNotFound:
            user_ref = {'id': self.generate_consistent_id(uname),
                        'name': uname,
                        'enabled': True,
                        'domain_id': domain_id,
                        'description': 'User created by athenz plugin'
                        }
            return self.identity_api.create_user(user_ref,
                                                 request.audit_initiator)

    def _lookup_and_create_role(self, request, role_name, domain_id):
        hints = driver_hints.Hints()
        hints.add_filter("name", role_name, case_sensitive=True)
        found_roles = self.role_api.list_roles(hints)
        LOG.info("Found roles:", found_roles)

        if not found_roles:
            # Create the role
            role_id = self.generate_consistent_id(role_name)
            role_ref = {'id': role_id,
                        'name': role_name
                        }
            return self.role_api.create_role(role_ref['id'],
                                             role_ref,
                                             initiator=request.audit_initiator)
        elif len(found_roles) == 1:
            return self.role_api.get_role(found_roles[0]['id'])

        else:
            raise exception.AmbiguityError(resource='role',
                                           name=role_name)

    def _create_project_and_assign_roles(self,
                                         request,
                                         atoken,
                                         requested_project_name,
                                         user_ref, domain_id):
        """ If requested project has a role in athenz, then create the
        requested project and role if necessary. Assign said role to user
        on the created project

        request: The request object
        atoken: Athenz token object
        requested_project_name: project_name from the request (OS_PROJECTNAME)
        user_ref: User object
        domain_id: ID of the domain
        """
        created = False
        for role, projects in atoken.projects.items():
            # check requested_project_name is part of one of the roles
            if requested_project_name.lower() in projects:
                if not created:
                    project_ref = self._lookup_and_create_project(request,
                                                                  requested_project_name,  # noqa
                                                                  domain_id)
                    created = True

                role_ref = self._lookup_and_create_role(request,
                                                        role,
                                                        domain_id)
                # Do grants
                self.assignment_api.create_grant(role_ref['id'],
                                                 user_id=user_ref['id'],
                                                 project_id=project_ref['id'])

    def authenticate(self, request, auth_payload):
        """Autenticate the athenz token

        Validate the athenz token create projects/users if needed
        """
        response_data = {}
        user_info = AthenzUserAuthInfo.create(auth_payload, METHOD_NAME)
        if not is_athenz_role_token(user_info.athenz_token):
            LOG.error("Not a valid athenz role token")
            raise exception.Unauthorized(_('Not a valid athenz role token'))

        atoken = AthenzToken(user_info.athenz_token)
        if atoken.validate(user_info.user_name) and atoken.user:
            # We got a valid athenz token
            LOG.debug("Athenz token is valid")
            # Get domain ID from name if it is not part of the request
            domain_id = user_info.domain_id
            if not user_info.domain_id:
                domain_ref = self.resource_api.get_domain_by_name(
                        user_info.domain_name)
                domain_id = domain_ref['id']

            # Assert domain isn't disabled
            self._lookup_domain(domain_id)

            # Create the user specified in athenz token if necessary
            user_ref = self._lookup_and_create_user(request,
                                                    domain_id,
                                                    atoken.user)
            # Create keystone project specified by the user in the request
            # (user_info.project_name) after validating athenz role token has
            # the same project name in its roles.
            self._create_project_and_assign_roles(request,
                                                  atoken,
                                                  user_info.project_name,
                                                  user_ref,
                                                  domain_id)
            response_data['user_id'] = user_ref['id']
            response_data['athenz_token'] = user_info.athenz_token

            return base.AuthHandlerResponse(status=True, response_body=None,
                                            response_data=response_data)
        msg = _('Invalid athenz token')
        raise exception.Unauthorized(msg)
