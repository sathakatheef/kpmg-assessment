#!/usr/bin/env python
"""
Inventories CloudFormation stacks in the accounts to list down resources created by each stack.
This script iterates AWS_PROFILE over list defined in "profiles". It is expected that credentials for the profile are set and valid (not-expired).
Boto3 and urllib3 module should be pre-installed. 
To execute: python3 ./cloudformation-resources-inventory.py
"""

import boto3
import json
import os
import sys
import socket
from datetime import datetime
import re
import traceback
from _utl_aws_iam import *
from _utl import _utl_print_list_csv
import urllib3

def main():

    profiles = [ 
        ## List of profile names
    ]

    ## Suppress Warnings
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    cfn_list = []
    
    # discover CloudFormation Stacks
    print("Discovering CloudFormation Stacks...")
    for profile in profiles:

        print(profile)
        
        session = boto3.Session(profile_name=profile)
        cfn = session.client('cloudformation', verify=False)

        paginator = cfn.get_paginator('list_stacks')
        status_filter = ['CREATE_FAILED', 'CREATE_COMPLETE', 'ROLLBACK_FAILED', 'ROLLBACK_COMPLETE', 'DELETE_FAILED', 'UPDATE_COMPLETE', 'UPDATE_FAILED', 'UPDATE_ROLLBACK_FAILED', 'UPDATE_ROLLBACK_COMPLETE']
        response_iterator = paginator.paginate(
            StackStatusFilter=status_filter
        )

        stacks = []
        for response in response_iterator:
            stacks += [stack['StackName'] for stack in response['StackSummaries']]

        print("[%s] CloudFormation Stacks found: %d" % (datetime.now().strftime("%H:%M:%S"), len(stacks)))

        # Start Gathering AWS resources provisioned byecach CFN stack
        for stack in stacks:
            resources = cfn.list_stack_resources(StackName=stack)
            for resource in resources['StackResourceSummaries']:
                cfn_list.append( {
                    "account": profile,
                    "stack_name": stack,
                    "logical_id": resource['LogicalResourceId'] if 'LogicalResourceId' in resource.keys() else "",
                    "physical_id": resource['PhysicalResourceId'] if 'PhysicalResourceId' in resource.keys() else "",
                    "resource_type": resource['ResourceType'] if 'ResourceType' in resource.keys() else "",
                    "last_updated_time": resource['LastUpdatedTimestamp'] if 'LastUpdatedTimestamp' in resource.keys() else "",
                    "resource_status": resource['ResourceStatus'] if 'ResourceStatus' in resource.keys() else ""
                })

    # create artifacts dir if it doesn't exist
    if not os.path.exists(os.path.dirname(sys.argv[0])+"/../artifacts"):
        os.makedirs(os.path.dirname(sys.argv[0])+"/../artifacts")

    print("Savings topics data into %s/cloudformation_stacks_inventory.csv" % os.path.dirname(sys.argv[0]))
    _utl_print_list_csv(list = cfn_list, file = os.path.dirname(sys.argv[0])+"/cloudformation_stacks_inventory.csv", use_stdout=False)


if __name__ == "__main__":
    main()
