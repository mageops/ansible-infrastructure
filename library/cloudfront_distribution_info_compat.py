#!/usr/bin/python
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
from __future__ import absolute_import, division, print_function

__metaclass__ = type

DOCUMENTATION = r'''
---
module: cloudfront_distribution_info_compat
short_description: Retrieve CloudFront distribution information (compat module)
description:
  - Lightweight replacement for cloudfront distribution info gathering.
  - Intended to avoid collection incompatibilities between community.aws and amazon.aws.
requirements:
  - boto3
  - botocore
options:
  region:
    description:
      - AWS region to use when creating the CloudFront client.
      - CloudFront is global, but region can still be provided for credential/session consistency.
    type: str
  summary:
    description:
      - Return summary of distributions with tags.
    type: bool
    default: false
  distribution:
    description:
      - Return details for a specific distribution.
    type: bool
    default: false
  distribution_id:
    description:
      - Distribution ID used when C(distribution=true).
    type: str
  profile:
    description:
      - AWS credential profile name.
    type: str
  aws_access_key:
    description:
      - AWS access key ID.
    aliases: [aws_access_key_id]
    type: str
  aws_secret_key:
    description:
      - AWS secret access key.
    aliases: [aws_secret_access_key]
    type: str
  aws_session_token:
    description:
      - AWS session token.
    aliases: [security_token]
    type: str
  endpoint_url:
    description:
      - Alternate CloudFront endpoint URL.
    aliases: [aws_endpoint_url, ec2_url]
    type: str
  validate_certs:
    description:
      - Toggle TLS certificate validation.
    type: bool
    default: true
  aws_ca_bundle:
    description:
      - CA bundle path for TLS verification.
    type: path
author:
  - MageOps
'''

EXAMPLES = r'''
- name: Get CloudFront distributions summary
  cloudfront_distribution_info_compat:
    summary: true
  register: cloudfront_info

- name: Get a specific CloudFront distribution
  cloudfront_distribution_info_compat:
    distribution: true
    distribution_id: E1234567890
  register: cloudfront_distribution
'''

RETURN = r'''
cloudfront:
  description: CloudFront info compatible with existing role usage.
  returned: always
  type: dict
'''

from ansible.module_utils.basic import AnsibleModule


def build_cloudfront_client(module):
    try:
        import boto3
    except ImportError:
        module.fail_json(msg='boto3 is required for cloudfront_distribution_info_compat')

    session_kwargs = {}
    profile = module.params.get('profile')
    access_key = module.params.get('aws_access_key')
    secret_key = module.params.get('aws_secret_key')
    session_token = module.params.get('aws_session_token')

    if profile:
        session_kwargs['profile_name'] = profile
    if access_key:
        session_kwargs['aws_access_key_id'] = access_key
    if secret_key:
        session_kwargs['aws_secret_access_key'] = secret_key
    if session_token:
        session_kwargs['aws_session_token'] = session_token

    session = boto3.session.Session(**session_kwargs)

    client_kwargs = {}
    region = module.params.get('region')
    endpoint_url = module.params.get('endpoint_url')
    validate_certs = module.params.get('validate_certs')
    aws_ca_bundle = module.params.get('aws_ca_bundle')

    if region:
        client_kwargs['region_name'] = region
    if endpoint_url:
        client_kwargs['endpoint_url'] = endpoint_url
    if aws_ca_bundle:
        client_kwargs['verify'] = aws_ca_bundle
    elif not validate_certs:
        client_kwargs['verify'] = False

    return session.client('cloudfront', **client_kwargs)


def list_distributions_with_tags(module, client):
    distributions = []
    paginator = client.get_paginator('list_distributions')

    for page in paginator.paginate():
        page_items = page.get('DistributionList', {}).get('Items', [])
        for dist in page_items:
            # Keep AWS payload shape, but normalize aliases and append tag dict as expected by role filtering.
            distribution = dict(dist)
            aliases = distribution.get('Aliases', {})
            if isinstance(aliases, dict):
                distribution['Aliases'] = list(aliases.get('Items', []))

            tags = {}
            arn = distribution.get('ARN')
            if arn:
                tags_response = client.list_tags_for_resource(Resource=arn)
                tag_items = tags_response.get('Tags', {}).get('Items', [])
                for tag in tag_items:
                    key = tag.get('Key')
                    if key is not None:
                        tags[key] = tag.get('Value')
            distribution['Tags'] = tags
            distributions.append(distribution)

    return distributions


def main():
    argument_spec = dict(
        region=dict(type='str', required=False),
        summary=dict(type='bool', default=False),
        distribution=dict(type='bool', default=False),
        distribution_id=dict(type='str', required=False),
        profile=dict(type='str', required=False),
        aws_access_key=dict(type='str', required=False, aliases=['aws_access_key_id']),
        aws_secret_key=dict(type='str', required=False, aliases=['aws_secret_access_key'], no_log=True),
        aws_session_token=dict(type='str', required=False, aliases=['security_token'], no_log=True),
        endpoint_url=dict(type='str', required=False, aliases=['aws_endpoint_url', 'ec2_url']),
        validate_certs=dict(type='bool', default=True),
        aws_ca_bundle=dict(type='path', required=False),
    )

    module = AnsibleModule(argument_spec=argument_spec, supports_check_mode=True)

    summary = module.params.get('summary')
    distribution = module.params.get('distribution')
    distribution_id = module.params.get('distribution_id')

    # Match community.aws behavior: summary if no selection provided.
    if not summary and not distribution:
        summary = True

    if distribution and not distribution_id:
        module.fail_json(msg='distribution_id is required when distribution=true')

    try:
        client = build_cloudfront_client(module)
    except Exception as exc:
        module.fail_json(msg='Failed to initialize CloudFront client: {0}'.format(exc))

    result = dict(changed=False, msg='Retrieved CloudFront info.', cloudfront={})

    try:
        if summary:
            result['cloudfront']['summary'] = dict(
                distributions=list_distributions_with_tags(module, client),
            )

        if distribution:
            dist = client.get_distribution(Id=distribution_id)
            # Preserve convenient access path used by existing role code.
            result['cloudfront']['result'] = dist
            result['cloudfront'][distribution_id] = dist
    except Exception as exc:
        module.fail_json(msg='Failed to gather CloudFront info: {0}'.format(exc))

    module.exit_json(**result)


if __name__ == '__main__':
    main()
