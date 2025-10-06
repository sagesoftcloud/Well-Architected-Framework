# Project 1: Basic - AWS Account Setup & IAM Foundation

## Overview
**Duration**: 90 minutes  
**Difficulty**: Beginner  
**Pillar Focus**: Security Foundation

## Objectives
- Establish secure AWS account foundation
- Implement IAM best practices
- Set up audit logging and cost monitoring
- Create secure access patterns

## What You'll Build
```
AWS Account
├── IAM Users & Groups
│   ├── Developers (PowerUser access)
│   ├── Operations (SystemAdmin access)  
│   └── ReadOnly (ReadOnly access)
├── MFA Enforcement
├── CloudTrail Logging
└── Cost Budgets & Alerts
```

## Prerequisites
- AWS account with admin access
- AWS CLI installed and configured
- Basic understanding of IAM concepts

## Lab Steps

### Step 1: IAM Groups and Policies (20 minutes)

#### 1.1 Create IAM Groups
```bash
# Create developer group
aws iam create-group --group-name Developers

# Create operations group  
aws iam create-group --group-name Operations

# Create read-only group
aws iam create-group --group-name ReadOnly
```

#### 1.2 Attach Managed Policies
```bash
# Attach PowerUser policy to Developers
aws iam attach-group-policy \
  --group-name Developers \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Attach SystemAdministrator policy to Operations
aws iam attach-group-policy \
  --group-name Operations \
  --policy-arn arn:aws:iam::aws:policy/job-function/SystemAdministrator

# Attach ReadOnly policy to ReadOnly group
aws iam attach-group-policy \
  --group-name ReadOnly \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

#### 1.3 Create Custom Policy for Developers (Deny IAM)
```bash
# Create policy document
cat > deny-iam-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Action": [
                "iam:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create and attach policy
aws iam create-policy \
  --policy-name DenyIAMAccess \
  --policy-document file://deny-iam-policy.json

aws iam attach-group-policy \
  --group-name Developers \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/DenyIAMAccess
```

### Step 2: Create IAM Users (15 minutes)

#### 2.1 Create Users
```bash
# Create developer user
aws iam create-user --user-name developer-1

# Create operations user
aws iam create-user --user-name ops-admin-1

# Create read-only user
aws iam create-user --user-name readonly-1
```

#### 2.2 Add Users to Groups
```bash
# Add users to respective groups
aws iam add-user-to-group --group-name Developers --user-name developer-1
aws iam add-user-to-group --group-name Operations --user-name ops-admin-1
aws iam add-user-to-group --group-name ReadOnly --user-name readonly-1
```

#### 2.3 Create Console Access
```bash
# Create login profiles (console access)
aws iam create-login-profile \
  --user-name developer-1 \
  --password TempPassword123! \
  --password-reset-required

aws iam create-login-profile \
  --user-name ops-admin-1 \
  --password TempPassword123! \
  --password-reset-required

aws iam create-login-profile \
  --user-name readonly-1 \
  --password TempPassword123! \
  --password-reset-required
```

### Step 3: Enforce MFA (20 minutes)

#### 3.1 Create MFA Enforcement Policy
```bash
cat > enforce-mfa-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowViewAccountInfo",
            "Effect": "Allow",
            "Action": [
                "iam:GetAccountPasswordPolicy",
                "iam:ListVirtualMFADevices"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowManageOwnPasswords",
            "Effect": "Allow",
            "Action": [
                "iam:ChangePassword",
                "iam:GetUser"
            ],
            "Resource": "arn:aws:iam::*:user/${aws:username}"
        },
        {
            "Sid": "AllowManageOwnMFA",
            "Effect": "Allow",
            "Action": [
                "iam:CreateVirtualMFADevice",
                "iam:DeleteVirtualMFADevice",
                "iam:EnableMFADevice",
                "iam:ListMFADevices",
                "iam:ResyncMFADevice"
            ],
            "Resource": [
                "arn:aws:iam::*:mfa/${aws:username}",
                "arn:aws:iam::*:user/${aws:username}"
            ]
        },
        {
            "Sid": "DenyAllExceptUnlessSignedInWithMFA",
            "Effect": "Deny",
            "NotAction": [
                "iam:CreateVirtualMFADevice",
                "iam:EnableMFADevice",
                "iam:GetUser",
                "iam:ListMFADevices",
                "iam:ListVirtualMFADevices",
                "iam:ResyncMFADevice",
                "sts:GetSessionToken"
            ],
            "Resource": "*",
            "Condition": {
                "BoolIfExists": {
                    "aws:MultiFactorAuthPresent": "false"
                }
            }
        }
    ]
}
EOF

# Create and attach MFA policy
aws iam create-policy \
  --policy-name EnforceMFA \
  --policy-document file://enforce-mfa-policy.json

# Attach to all groups
for group in Developers Operations ReadOnly; do
  aws iam attach-group-policy \
    --group-name $group \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/EnforceMFA
done
```

### Step 4: Set Up CloudTrail (20 minutes)

#### 4.1 Create S3 Bucket for CloudTrail
```bash
# Create unique bucket name
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="cloudtrail-logs-${ACCOUNT_ID}-$(date +%s)"

# Create bucket
aws s3 mb s3://$BUCKET_NAME

# Create bucket policy
cat > cloudtrail-bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::$BUCKET_NAME"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
EOF

# Apply bucket policy
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://cloudtrail-bucket-policy.json
```

#### 4.2 Create CloudTrail
```bash
# Create CloudTrail
aws cloudtrail create-trail \
  --name well-architected-audit-trail \
  --s3-bucket-name $BUCKET_NAME \
  --include-global-service-events \
  --is-multi-region-trail \
  --enable-log-file-validation

# Start logging
aws cloudtrail start-logging --name well-architected-audit-trail
```

### Step 5: Set Up Cost Budgets (15 minutes)

#### 5.1 Create Monthly Budget
```bash
cat > monthly-budget.json << 'EOF'
{
    "BudgetName": "Monthly-AWS-Budget",
    "BudgetLimit": {
        "Amount": "100",
        "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {}
}
EOF

cat > budget-notifications.json << 'EOF'
[
    {
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "admin@example.com"
            }
        ]
    },
    {
        "Notification": {
            "NotificationType": "FORECASTED",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 100
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "admin@example.com"
            }
        ]
    }
]
EOF

# Create budget
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://monthly-budget.json \
  --notifications-with-subscribers file://budget-notifications.json
```

## Verification Steps

### 1. Test IAM Access
```bash
# Verify groups exist
aws iam list-groups

# Verify users are in correct groups
aws iam get-groups-for-user --user-name developer-1
```

### 2. Test MFA Enforcement
- Log in to AWS Console with one of the created users
- Try to access services (should be denied)
- Set up MFA device
- Verify access works after MFA setup

### 3. Verify CloudTrail
```bash
# Check trail status
aws cloudtrail get-trail-status --name well-architected-audit-trail

# List recent events
aws logs describe-log-groups --log-group-name-prefix CloudTrail
```

### 4. Check Budget
```bash
# List budgets
aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text)
```

## Success Criteria
- [ ] Three IAM groups created with appropriate policies
- [ ] Three IAM users created and assigned to groups
- [ ] MFA enforcement policy applied and tested
- [ ] CloudTrail logging all API calls
- [ ] Cost budget created with email notifications
- [ ] All users can access console only after MFA setup

## Troubleshooting

### Common Issues
1. **MFA policy too restrictive**: Ensure users can still manage their own MFA devices
2. **CloudTrail permissions**: Verify S3 bucket policy allows CloudTrail access
3. **Budget notifications**: Update email address to receive actual notifications

### Cleanup Commands
```bash
# Delete users (remove from groups first)
aws iam remove-user-from-group --group-name Developers --user-name developer-1
aws iam delete-login-profile --user-name developer-1
aws iam delete-user --user-name developer-1

# Delete CloudTrail and S3 bucket
aws cloudtrail delete-trail --name well-architected-audit-trail
aws s3 rb s3://$BUCKET_NAME --force

# Delete budget
aws budgets delete-budget --account-id $(aws sts get-caller-identity --query Account --output text) --budget-name Monthly-AWS-Budget
```

## Next Steps
Proceed to Project 2 to build the network foundation that will support your Well-Architected applications.
