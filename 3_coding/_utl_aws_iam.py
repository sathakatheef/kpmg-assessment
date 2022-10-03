import boto3
import sys
import re
import json
import os
from datetime import datetime

def iam_policy_document_categoriser(json_document, aws_service):
    """ 
    Categorises permissions that policy document grants for an aws_service. 
    returns [ { "permission": <category>, "resource": <ARN or wildcarded ARN> } ]
    Currently SNS and SQS are implemented only. 
    """

    service_permissions = []

    # Bail if we have a bad policy JSON doc
    if not ("PolicyDocument" in json_document.keys() and "Statement" in json_document["PolicyDocument"]):
        print ("Bad JSON!")
        return []
    

    if aws_service == "sns":
        sns_categories = {
            0: "none",
            1: "readonly",
            2: "publisher",
            3: "subscriber",
            4: "creator"
        }
        #  4 - creator - full access: "*", "sns:*", "sns:CreateTopic"
        #  3 - subscriber - can create subscription - "sns:Subscribe"
        #  2 - publisher - can publish on topic - "sns:Publish"
        #  1 - readonly - can get/list topic - "sns:List*", "sns:Get*"
        # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonsns.html

        # convert statement to list
        if isinstance(json_document["PolicyDocument"]["Statement"], dict):
            statements = [ json_document["PolicyDocument"]["Statement"] ]
        else:
            statements = json_document["PolicyDocument"]["Statement"]

        for statement in statements:
            sns_top_category = 0
            if statement["Effect"] == "Allow":
                # convert to list
                if isinstance(statement["Action"], str):
                    actions = [statement["Action"]]
                else:
                    actions = statement["Action"]

                for action in actions:
                    if (sns_top_category < 4 and 
                        (re.match("^\*$", action) or 
                        re.match("^sns:\*$", action) or 
                        re.match("^sns:CreateTopic$", action) 
                        )):
                        sns_top_category = 4
                    elif (sns_top_category < 3 and 
                        (re.match("^sns:Subscribe$", action))):
                        sns_top_category = 3
                    elif (sns_top_category < 2 and 
                        (re.match("^sns:Publish$", action))):
                        sns_top_category = 2                       
                    elif (sns_top_category < 1 and 
                        (re.match("^sns:List.*$", action) or 
                        re.match("^sns:Get.*$", action) 
                        )):
                        sns_top_category = 1                        
                    else:
                        pass

                # search resources only if we have any SNS permissions
                if sns_top_category > 0:
                    # convert to list
                    if isinstance(statement["Resource"], str):
                        resources = [statement["Resource"]]
                    else:
                        resources = statement["Resource"] 

                    append = lambda a, b, c : a.append({ "permission": b, "resource": c})

                    # we have smth that matches policy 
                    for resource in resources:
                        if (re.match("^\*$", resource) or 
                            re.match("^arn:aws:sns:", resource)):
                            append(service_permissions, sns_categories[sns_top_category], resource)


    elif aws_service == "sqs":
        sqs_categories = {
            0: "none",
            1: "readonly",
            2: "sender",
            3: "consumer",
            4: "creator"
        }
        #  4 - creator - full access: "*", "sqs:*", "sqs:CreateQueue", "sqs:SetQueueAttributes"
        #  3 - consumer - can read, receave and delete messages - "sqs:Receive*", "sqs:Delete*", "sqs:Change*"
        #  2 - sender - can send on topic - "sqs:Send*"
        #  1 - readonly - can get/list topic - "sqs:List*", "sqs:Get*"
        # https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonsqs.html

        if isinstance(json_document["PolicyDocument"]["Statement"], dict):
            statements = [ json_document["PolicyDocument"]["Statement"] ]
        else:
            statements = json_document["PolicyDocument"]["Statement"]

        for statement in statements:
            sqs_top_category = 0
            # note - we disregard any Deny statements in this implementation.
            if statement["Effect"] == "Allow":
                # convert to list
                if isinstance(statement["Action"], str):
                    actions = [statement["Action"]]
                else:
                    actions = statement["Action"]

                for action in actions:
                    if (sqs_top_category < 4 and 
                        (re.match("^\*$", action) or 
                        re.match("^sqs:\*$", action) or 
                        re.match("^sqs:CreateQueue$", action) or 
                        re.match("^sqs:SetQueueAttributes$", action)
                        )):
                        sqs_top_category = 4
                    elif (sqs_top_category < 3 and 
                        (re.match("^sqs:Receive.*$", action) or 
                        re.match("^sqs:Delete.*$", action) or 
                        re.match("^sqs:Change.*$", action)
                        )):
                        sqs_top_category = 3
                    elif (sqs_top_category < 2 and 
                        (re.match("^sqs:Send.*$", action))):
                        sqs_top_category = 2                       
                    elif (sqs_top_category < 1 and 
                        (re.match("^sqs:List.*$", action) or 
                        re.match("^sqs:Get.*$", action) 
                        )):
                        sqs_top_category = 1                        
                    else:
                        pass

                # search resources only if we have any SNS permissions
                if sqs_top_category > 0:
                    # convert to list
                    if isinstance(statement["Resource"], str):
                        resources = [statement["Resource"]]
                    else:
                        resources = statement["Resource"] 

                    append = lambda a, b, c : a.append({ "permission": b, "resource": c})

                    # we have smth that matches policy 
                    for resource in resources:
                        if (re.match("^\*$", resource) or 
                            re.match("^arn:aws:sqs:", resource)):
                            append(service_permissions, sqs_categories[sqs_top_category], resource)

    return service_permissions



def list_policy_assumable_roles(json_document):
    """ 
    Checks if policy JSON document allow to sts:AssumeRole
    Returns the list of roleArns that can be assumed.
    """

    assumable_roles = []

    # Bail if we have a bad policy JSON doc
    if not ("Document" in json_document.keys() and "Statement" in json_document["Document"]):
        print ("Bad JSON!")
        return []

    # convert statement to list
    if isinstance(json_document["Document"]["Statement"], dict):
        statements = [ json_document["Document"]["Statement"] ]
    else:
        statements = json_document["Document"]["Statement"]

    for statement in statements:
        
        if statement["Effect"] == "Allow":
            # convert to list
            if isinstance(statement["Action"], str):
                actions = [statement["Action"]]
            else:
                actions = statement["Action"]

            assume_action = False

            for action in actions:
                assume_action = assume_action or re.match("^sts:AssumeRole$", action) 

            # search resources only if we have sts:AssumeRole action
            if assume_action:
                # convert to list
                if isinstance(statement["Resource"], str):
                    resources = [statement["Resource"]]
                else:
                    resources = statement["Resource"] 

                # we have smth that matches policy 
                for resource in resources:
                    if re.match("^arn:aws:iam:", resource):
                        assumable_roles.append(resource)

    return(assumable_roles)


def get_caller_identity_by_access_key(access_key, secret_key):
    """ Return calling identity ARN and 12-digit AWS account
    """
    client = boto3.client('sts',
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key)

    try:
        response = client.get_caller_identity()
        return (response["Arn"], response["Account"])
    except:
        print("Invalid credentials!")
        return ("", "")
    