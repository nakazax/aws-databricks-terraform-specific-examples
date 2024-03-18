# data_mesh_example - Introduction
The artifacts in this directory represent a sample Terraform implementation for managing multiple Databricks workspaces in accordance with the data mesh concept. This document provides a brief explanation. For a Japanese explanation, please refer to the following Qiita post:

[「Databricksによるデータメッシュ実現のためのTerraformサンプル実装の解説」を編集 - Qiita](https://qiita.com/nakazax/items/4808d95ac82c1c05b22e)

Please note that this sample implementation is a compilation of personal ideas and does not represent the views of any company.

## Prerequisites
- This Terraform sample implementation and this article are targeted at Databricks on AWS.
- The following versions of Terraform and providers were used for verification:

```bash:Terraform version
% terraform -v

Terraform v1.6.5

on darwin_arm64

+ provider registry.terraform.io/databricks/databricks v1.38.0
+ provider registry.terraform.io/hashicorp/aws v5.40.0
+ provider registry.terraform.io/hashicorp/random v3.6.0
+ provider registry.terraform.io/hashicorp/time v0.11.1
```

# Roles and Purposes of Each Directory
First, let's describe the roles and purposes of each directory. The names and structure are just examples, so when you actually use them, it is recommended to modify them to suit your organization's data mesh design.

Directory | Role/Purpose
--- | ---
`domains` | Base directory for data domains. Subdirectories for each domain are stored here.
`domains/domain1` | Directory for the `domain1` data domain. <br>When actually using it, it is better to change it to a more understandable name representing the domain. <br>If there are other domains, create another directory under `domains`.
`domains/modules` | Modules to be used across multiple data domains.
`platform` | Base directory for the platform. Files related to common functions and infrastructure for the entire data mesh are stored here.
`platform/01_workspace_setup` | Files for creating and managing all Databricks workspaces and their AWS infrastructure for data domains.
`platform/02_workspace_config` | Files for managing settings and policies to be applied commonly to Databricks workspaces created in `01_workspace_setup`.

[!NOTE]
In this sample, we manage the files for data domains and platforms in one repository, but in actual usage scenarios, it may be easier to manage repositories separately for each data domain, so please consider this carefully.

# Detailed Explanation of Terraform Files
Now that you understand the roles and purposes of each directory, let's discuss the order of executing `terraform apply` (for convenience, we'll refer to this as *Terraform execution*) and explain each file.

## Execution Order
The Databricks account administrators should execute `terraform apply` in the following order:

1. `platform/01_workspace_setup`: Create multiple Databricks workspaces and their AWS infrastructure.
2. `platform/02_workspace_config`: Apply common settings and policies to multiple Databricks workspaces (in this sample implementation, grant permissions such as `CREATE_CATALOG` to workspace administrators).

After the above steps are successful, the Databricks workspaces for each data domain will be ready. From then on, it is assumed that the Databricks workspace administrators for each data domain will perform any necessary management tasks.

As an example of domain-specific management tasks, the `domains/domain1` directory in the sample implementation includes Terraform files for creating and managing a Unity Catalog catalog and related resources for data management specific to the domain.

The following sections provide details about each Terraform file.

# `platform/01_workspace_setup`
This module creates and manages multiple Databricks workspaces and their AWS infrastructure. The main files are explained below.

## Providers (`providers.tf`)
The AWS and Databricks providers are used.

```terraform:providers.tf
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    databricks = {
      source = "databricks/databricks"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
```

### AWS
#### Required Permissions and Authentication Method
- It is assumed that the execution principal has the [AdministratorAccess](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_job-functions.html#jf_administrator) permission in AWS IAM.
- There are multiple methods for AWS authentication, so you can use any method you prefer. Instead of hardcoding access keys or secret keys, it is recommended to use the authentication information file created by running `aws configure` in the AWS CLI or environment variables (for more details on authentication methods, refer to the following link):

https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

### Databricks
#### Required Permissions and Authentication Method
- It is assumed that the authentication is done using the `client_id` and `client_secret` of a service principal at the account level, not the workspace level. Additionally, it is assumed that the service principal has administrator privileges for the account.
    - For information on how to create an account-level service principal, refer to the following link:
    - [Manage Service Principals | Databricks on AWS](https://docs.databricks.com/administration-guide/users-groups/service-principals.html#manage-service-principals-in-your-account)
- The `account_id` can be found by clicking on your email address in the top-right corner of the account console.

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/4a806a24-9379-23ce-b4a4-49a0093100f1.png)

## Main (`main.tf`)
The explanation is divided into meaningful sections.

### Creating the Account Admin Group
An account-level administrator group is created, and the specified principals (users, groups, or service principals) are added to the group as arguments (variables). Furthermore, the `account_admin` role is granted to the account admin group.

```terraform:main.tf - Creating the Account Admin Group
resource "databricks_group" "account_admin" {
  provider     = databricks.mws
  display_name = var.databricks_account_admin_group_name
}

resource "databricks_group_member" "account_admin" {
  provider  = databricks.mws
  for_each  = var.databricks_account_admin_principal_ids
  group_id  = databricks_group.account_admin.id
  member_id = each.value
}

resource "databricks_group_role" "account_admin" {
  provider = databricks.mws
  group_id = databricks_group.account_admin.id
  role     = "account_admin"
}
```

### Creating the Unity Catalog Metastore
If you want to associate an existing Unity Catalog metastore with the Databricks workspace, specify the metastore ID as an argument. If the metastore ID is not specified, a new metastore with the name "primary" is created, and the account admin group is set as the owner. The `count` meta-argument is used to control resource creation based on the presence or absence of the argument.

```terraform:main.tf - Creating the Unity Catalog Metastore
resource "databricks_metastore" "this" {
  count         = var.databricks_metastore_id == "" ? 1 : 0
  provider      = databricks.mws
  name          = "primary"
  owner         = databricks_group.account_admin.display_name
  region        = var.region
  force_destroy = true
}
```

### Creating Databricks Workspaces and AWS Infrastructure
The `aws_databricks_mws` module is called to create Databricks workspaces and their AWS infrastructure. Multiple Databricks workspaces can be specified as arguments.

```terraform:main.tf - Creating Databricks Workspaces
locals {
  metastore_id = var.databricks_metastore_id == "" ? databricks_metastore.this[0].id : var.databricks_metastore_id
}

module "aws_databricks_mws" {
  source = "./modules/aws_databricks_mws"
  providers = {
    aws        = aws
    databricks = databricks.mws
  }

  for_each = var.databricks_workspaces

  # Common variables for all workspaces
  region                  = var.region
  databricks_account_id   = var.databricks_account_id
  databricks_metastore_id = local.metastore_id

  # Workspace specific variables
  prefix                     = each.value.prefix
  vpc_cidr                   = each.value.vpc_cidr
  public_subnets_cidr        = each.value.public_subnets_cidr
  private_subnet_pair        = each.value.private_subnet_pair
  tags                       = each.value.tags
  workspace_admin_group_name = each.value.workspace_admin_group_name
  workspace_admin_user_ids   = each.value.workspace_admin_user_ids
}
```

#### Module `aws_databricks_mws/main.tf`
This module creates and manages the following resources related to the Databricks workspace:

- AWS infrastructure for the workspace (VPC-related resources, S3 bucket, IAM role, IAM policy)
- Workspace and its related resources (storage configuration, network configuration)
- Assignment of the workspace to the metastore
- Workspace admin group, admin permissions, and association with principals

The full text is available on GitHub at `main.tf`, as it is quite long.

https://github.com/nakazax/aws-databricks-terraform-specific-examples/blob/main/examples/data_mesh_example/platform/01_workspace_setup/modules/aws_databricks_mws/main.tf

This module is based on and simplified from the following sample:

https://registry.terraform.io/modules/databricks/examples/databricks/latest/examples/aws-databricks-modular-privatelink

#### Tip: Creating a Workspace-Level `token`
As a tip, a `token` is specified during workspace creation. This creates a token for the service principal that executed this Terraform in the workspace. By using this token, which is output in the parent `outputs.tf`, you can automate subsequent workspace-level processes easily and securely.

```terraform: aws_databricks_mws/main.tf - Creating Databricks Workspaces
resource "databricks_mws_workspaces" "this" {
  account_id     = var.databricks_account_id
  workspace_name = local.prefix
  aws_region     = var.region

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

  token {}
}
```

## Outputs (`outputs.tf`)
This file outputs the metastore ID, the name of the created workspace admin group, the workspace name, the service principal token, and the workspace URL. This information is used as arguments for the subsequent `platform/02_workspace_config`.

```terraform: outputs.tf
output "databricks_metastore_id" {
  value = local.metastore_id
}

output "databricks_workspaces_details" {
  value = [for key, ws in module.aws_databricks_mws : {
    databricks_workspace_admin_group_name = ws.databricks_workspace_admin_group_name
    databricks_workspace_name             = ws.databricks_workspace_name
    databricks_workspace_token            = ws.databricks_workspace_token
    databricks_workspace_url              = ws.databricks_workspace_url
  }]
  sensitive = true
}
```

## Arguments
Following the Terraform best practices, argument files are not version-controlled on GitHub. Specifically, `*.tfvars` files are excluded in the `.gitignore` file.

While you can specify arguments interactively during the `terraform apply` execution, it is easier to create a file named `terraform.tfvars` in the `01_workspace_setup` directory containing the following arguments. The content is just an example (all IDs are dummy values), so please modify it according to your needs.

```terraform: 01_workspace_setup/terraform.tfvars
region = "ap-northeast-1"
databricks_account_id = "1234567a-304d-4e66-8c03-11b10d68ba23"
databricks_client_id     = "1234567b-304d-4e66-8c03-11b10d68ba23"
databricks_client_secret = "1234567c-304d-4e66-8c03-11b10d68ba23"

databricks_account_admin_group_name = "account admins"
databricks_account_admin_principal_ids = [
  "1234567890123456",
  "6543210987654321"
]

databricks_workspaces = {
  workspace1 = {
    # Specify a globally unique prefix to avoid resource name conflicts
    prefix                     = "random-prefix-domain1"
    vpc_cidr                   = "10.109.0.0/16"
    public_subnets_cidr        = ["10.109.2.0/23"]
    private_subnet_pair        = ["10.109.4.0/23", "10.109.6.0/23"]
    tags                       = {}
    workspace_admin_group_name = "domain1-admin-group"
    workspace_admin_user_ids = [
      "1234567890123456",
      "6543210987654321"
    ]
  },
  workspace2 = {
    prefix                     = "random-prefix-domain2"
    vpc_cidr                   = "10.110.0.0/16"
    public_subnets_cidr        = ["10.110.2.0/23"]
    private_subnet_pair        = ["10.110.4.0/23", "10.110.6.0/23"]
    tags                       = {}
    workspace_admin_group_name = "domain2-admin-group"
    workspace_admin_user_ids = [
      "1234567890123456",
      "6543210987654321"
    ]
  }
}
```

## Executing Terraform
The file explanation is now complete. Let's go over the actual execution process.

### Preparation
Install the AWS CLI and prepare the access key for an IAM user to use the AWS CLI. Please refer to the "Preparation" section in the following Qiita article and complete the necessary setup.

https://qiita.com/Chanmoro/items/55bf0da3aaf37dc26f73#%E4%BA%8B%E5%89%8D%E6%BA%96%E5%82%99

### Execution
Clone the repository locally and navigate to the target directory.

```bash:Preparing for Terraform Execution
$ git clone https://github.com/nakazax/aws-databricks-terraform-specific-examples
$ cd aws-databricks-terraform-specific-examples/examples/data_mesh_example/platform/01_workspace_setup
```

Next, initialize Terraform.

```bash:Terraform Initialization
$ terraform init

Initializing the backend...
Initializing modules...
- aws_databricks_mws in modules/aws_databricks_mws
- aws_databricks_mws.aws_infra in modules/aws_databricks_mws/modules/aws_infra

Initializing provider plugins...
- Reusing previous version of hashicorp/time from the dependency lock file
- Reusing previous version of databricks/databricks from the dependency lock file
- Reusing previous version of hashicorp/random from the dependency lock file
- Reusing previous version of hashicorp/aws from the dependency lock file
- Installing hashicorp/time v0.11.1...
- Installed hashicorp/time v0.11.1 (signed by HashiCorp)
- Installing databricks/databricks v1.38.0...
- Installed databricks/databricks v1.38.0 (self-signed, key ID 92A95A66446BCE3F)
- Installing hashicorp/random v3.6.0...
- Installed hashicorp/random v3.6.0 (signed by HashiCorp)
- Installing hashicorp/aws v5.40.0...
- Installed hashicorp/aws v5.40.0 (signed by HashiCorp)

Partner and community providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://www.terraform.io/docs/cli/plugins/signing.html

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

As a precaution, use `terraform plan` to simulate and verify that there are no issues with the resources to be created or updated.

```bash:terraform plan
$ terraform plan

(omitted)

Plan: 67 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + databricks_metastore_id       = (known after apply)
  + databricks_workspaces_details = (sensitive value)
```

The following Warning message will appear, but this is an expected behavior.

```
╷
│ Warning: Argument is deprecated
│ 
│   with module.aws_databricks_mws.module.aws_infra.aws_eip.nat_gateway_elastic_ips,
│   on modules/aws_databricks_mws/modules/aws_infra/main.tf line 37, in resource "aws_eip" "nat_gateway_elastic_ips":
│   37:   vpc   = true
│ 
│ use domain attribute instead
│ 
│ (and 2 more similar warnings elsewhere)
```

If there are no issues, run `terraform apply`. You will be prompted to confirm the changes, so enter `yes` and press Enter.

```bash:terraform apply
Plan: 67 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + databricks_metastore_id       = (known after apply)
  + databricks_workspaces_details = (sensitive value)
╷
│ Warning: Argument is deprecated
│ 
│   with module.aws_databricks_mws.module.aws_infra.aws_eip.nat_gateway_elastic_ips,
│   on modules/aws_databricks_mws/modules/aws_infra/main.tf line 37, in resource "aws_eip" "nat_gateway_elastic_ips":
│   37:   vpc   = true
│ 
│ use domain attribute instead
│ 
│ (and 2 more similar warnings elsewhere)
╵

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

After the above execution, wait for 3-4 minutes, and if you see `Apply complete!` as shown below, the process has completed successfully.

```bash:Terraform Apply Result
(omitted)
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table_association.private_route_table_associations[1]: Creation complete after 1s [id=rtbassoc-0ea195aef64c0e05c]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table_association.private_route_table_associations[0]: Creation complete after 1s [id=rtbassoc-09550156d7158df9d]
╷
│ Warning: Argument is deprecated
│ 
│   with module.aws_databricks_mws["workspace2"].module.aws_infra.aws_eip.nat_gateway_elastic_ips[0],
│   on modules/aws_databricks_mws/modules/aws_infra/main.tf line 37, in resource "aws_eip" "nat_gateway_elastic_ips":
│   37:   vpc   = true
│ 
│ use domain attribute instead
│ 
│ (and one more similar warning elsewhere)
╵

Apply complete! Resources: 67 added, 0 changed, 0 destroyed.

Outputs:

databricks_metastore_id = "1234567d-304d-4e66-8c03-11b10d68ba23"
databricks_workspaces_details = <sensitive>
```

## Verifying the Execution Results
You can verify the created resources using the `terraform state list` command. If you executed `terraform apply` with the sample arguments provided in the previous section, two workspaces and their related resources will be created.

```bash:terraform state list
$ terraform state list

databricks_group.account_admin
databricks_group_member.account_admin["1234567890123456"]
databricks_group_member.account_admin["6543210987654321"]
databricks_group_role.account_admin
databricks_metastore.this[0]
module.aws_databricks_mws["workspace1"].databricks_group.workspace_admin
module.aws_databricks_mws["workspace1"].databricks_group_member.admin_user["5222559431330616"]
module.aws_databricks_mws["workspace1"].databricks_group_member.admin_user["7422702450545826"]
module.aws_databricks_mws["workspace1"].databricks_metastore_assignment.this
module.aws_databricks_mws["workspace1"].databricks_mws_credentials.this
module.aws_databricks_mws["workspace1"].databricks_mws_networks.this
module.aws_databricks_mws["workspace1"].databricks_mws_permission_assignment.workspace_admin
module.aws_databricks_mws["workspace1"].databricks_mws_storage_configurations.this
module.aws_databricks_mws["workspace1"].databricks_mws_workspaces.this
module.aws_databricks_mws["workspace1"].random_string.naming
module.aws_databricks_mws["workspace1"].time_sleep.wait_iam_role
module.aws_databricks_mws["workspace1"].time_sleep.wait_metastore_assignment
module.aws_databricks_mws["workspace2"].databricks_group.workspace_admin
module.aws_databricks_mws["workspace2"].databricks_group_member.admin_user["5222559431330616"]
module.aws_databricks_mws["workspace2"].databricks_group_member.admin_user["7422702450545826"]
module.aws_databricks_mws["workspace2"].databricks_metastore_assignment.this
module.aws_databricks_mws["workspace2"].databricks_mws_credentials.this
module.aws_databricks_mws["workspace2"].databricks_mws_networks.this
module.aws_databricks_mws["workspace2"].databricks_mws_permission_assignment.workspace_admin
module.aws_databricks_mws["workspace2"].databricks_mws_storage_configurations.this
module.aws_databricks_mws["workspace2"].databricks_mws_workspaces.this
module.aws_databricks_mws["workspace2"].random_string.naming
module.aws_databricks_mws["workspace2"].time_sleep.wait_iam_role
module.aws_databricks_mws["workspace2"].time_sleep.wait_metastore_assignment
module.aws_databricks_mws["workspace1"].module.aws_infra.data.aws_availability_zones.available
module.aws_databricks_mws["workspace1"].module.aws_infra.data.databricks_aws_assume_role_policy.this
module.aws_databricks_mws["workspace1"].module.aws_infra.data.databricks_aws_bucket_policy.this
module.aws_databricks_mws["workspace1"].module.aws_infra.data.databricks_aws_crossaccount_policy.this
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_eip.nat_gateway_elastic_ips[0]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_iam_role.cross_account_role
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_iam_role_policy.this
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_internet_gateway.igw
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_nat_gateway.nat_gateways[0]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_route_table.private_route_tables[0]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_route_table.private_route_tables[1]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_route_table.public_route_table
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_route_table_association.private_route_table_associations[0]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_route_table_association.private_route_table_associations[1]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_route_table_association.public_route_table_associations[0]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_s3_bucket.root_storage_bucket
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_s3_bucket_policy.root_bucket_policy
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_s3_bucket_public_access_block.root_storage_bucket
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_security_group.test_sg
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_subnet.private_subnets[0]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_subnet.private_subnets[1]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_subnet.public_subnets[0]
module.aws_databricks_mws["workspace1"].module.aws_infra.aws_vpc.main_vpc
module.aws_databricks_mws["workspace2"].module.aws_infra.data.aws_availability_zones.available
module.aws_databricks_mws["workspace2"].module.aws_infra.data.databricks_aws_assume_role_policy.this
module.aws_databricks_mws["workspace2"].module.aws_infra.data.databricks_aws_bucket_policy.this
module.aws_databricks_mws["workspace2"].module.aws_infra.data.databricks_aws_crossaccount_policy.this
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_eip.nat_gateway_elastic_ips[0]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_iam_role.cross_account_role
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_iam_role_policy.this
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_internet_gateway.igw
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_nat_gateway.nat_gateways[0]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table.private_route_tables[0]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table.private_route_tables[1]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table.public_route_table
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table_association.private_route_table_associations[0]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table_association.private_route_table_associations[1]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_route_table_association.public_route_table_associations[0]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_s3_bucket.root_storage_bucket
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_s3_bucket_policy.root_bucket_policy
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_s3_bucket_public_access_block.root_storage_bucket
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_security_group.test_sg
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_subnet.private_subnets[0]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_subnet.private_subnets[1]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_subnet.public_subnets[0]
module.aws_databricks_mws["workspace2"].module.aws_infra.aws_vpc.main_vpc
```

You're right, the Databricks account console shows that multiple workspaces have been created.

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/a9e6de10-e016-4e7d-535c-7b4a480898dc.png)

The configuration screens for the created workspaces look like this:

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/2fbf3c7d-45ef-84ef-0258-5edc6dcab839.png)

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/9a8488bb-7936-0746-5ecb-e885c260d758.png)

## Verifying Outputs
You can view the information defined in the outputs using the `terraform output -json` command. Make a note of this as it will be used as input for `platform/02_workspace_config`.

```bash:terraform output -json
$ terraform output -json
{
  "databricks_metastore_id": {
    "sensitive": false,
    "type": "string",
    "value": "1234567d-304d-4e66-8c03-11b10d68ba23"
  },
  "databricks_workspaces_details": {
    "sensitive": true,
    "type": [
      "tuple",
      [
        [
          "object",
          {
            "databricks_workspace_admin_group_name": "string",
            "databricks_workspace_name": "string",
            "databricks_workspace_token": "string",
            "databricks_workspace_url": "string"
          }
        ],
        [
          "object",
          {
            "databricks_workspace_admin_group_name": "string",
            "databricks_workspace_name": "string",
            "databricks_workspace_token": "string",
            "databricks_workspace_url": "string"
          }
        ]
      ]
    ],
    "value": [
      {
        "databricks_workspace_admin_group_name": "domain1-admin-group",
        "databricks_workspace_name": "hinak-dbc-ws-apne1-domain1",
        "databricks_workspace_token": "1234567d-304d-4e66-8c03-11b10d68ba23",
        "databricks_workspace_url": "https://dbc-e29e9444-3722.cloud.databricks.com"
      },
      {
        "databricks_workspace_admin_group_name": "domain2-admin-group",
        "databricks_workspace_name": "hinak-dbc-ws-apne1-domain2",
        "databricks_workspace_token": "1234567e-304d-4e66-8c03-11b10d68ba23",
        "databricks_workspace_url": "https://dbc-3d5a5b8d-8350.cloud.databricks.com"
      }
    ]
  }
}
```

## (Optional) Deleting Terraform Resources
You can delete all resources using the `terraform destroy` command.

# `platform/02_workspace_config`
In this section, we apply common settings and policies to the Databricks workspaces created earlier. In this sample implementation, we grant permissions such as `CREATE_CATALOG` to the workspace administrators.

## Providers (`providers.tf`)
In this sample implementation, we define providers for two Databricks workspaces. If you create more workspaces, you can increase the number of providers by copy and pasting. It would be smooth to use the outputs from `platform/01_workspace_setup` for the `url` and `token` values.

```terraform: providers.tf
terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {
  alias = "domain1"
  host  = var.domain1.url
  token = var.domain1.token
}

provider "databricks" {
  alias = "domain2"
  host  = var.domain2.url
  token = var.domain2.token
}
```

> [!WARNING]
>
> **Dynamic Definition of Terraform Providers**
> In Terraform, it is not possible to dynamically define providers using `for_each` or similar constructs. Therefore, you need to statically define all providers as shown above.

## Main (`main.tf`)
For each workspace admin group, we grant the necessary privileges for creating catalogs. If you have more workspaces, copy and paste the resource section to increase the number of resources.

```terraform: main.tf
resource "databricks_grant" "domain1" {
  provider   = databricks.domain1
  metastore  = var.databricks_metastore_id
  principal  = var.domain1.admin_group_name
  privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
}

resource "databricks_grant" "domain2" {
  provider   = databricks.domain2
  metastore  = var.databricks_metastore_id
  principal  = var.domain2.admin_group_name
  privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
}
```

> [!WARNING]
>
> **Important Notes on Metastore-Level Operations**
>
> - Granting privileges like `CREATE_CATALOG` is a metastore-level operation.
> - Metastore-level operations can be performed by Metastore Admins.
> - In `platform/01_workspace_setup`, we set the account admin group (account admins) as the Metastore Admin. Therefore, if the principal executing Terraform is part of the account admin group, there should be no issues.
> - If you are using an existing metastore, ensure that the principal executing Terraform is a member of the Metastore Admins. If not, you will need to make the necessary changes.

## Arguments
Here is an example of the arguments. It is easy to copy and paste the outputs from `platform/01_workspace_setup`.

```terraform: terraform.tfvars
databricks_metastore_id = "1234567d-304d-4e66-8c03-11b10d68ba23"

domain1 = {
  admin_group_name = "domain1-admin-group"
  token            = "1234567d-304d-4e66-8c03-11b10d68ba23"
  url              = "https://dbc-210868cc-1c64.cloud.databricks.com"
}

domain2 = {
  admin_group_name = "domain2-admin-group"
  token            = "1234567e-304d-4e66-8c03-11b10d68ba23"
  url              = "https://dbc-08e13b97-9770.cloud.databricks.com"
}
```

## Executing Terraform
You can execute Terraform in the same way as `platform/01_workspace_setup`.

```bash:Terraform Execution
$ cd aws-databricks-terraform-specific-examples/examples/data_mesh_example/platform/02_workspace_config
$ terraform init
$ terraform plan
$ terraform apply
```

## Execution Results
Access the workspace, and from the Catalog Explorer, you can see that permissions like `CREATE CATALOG` have been granted to the workspace admin group for the metastore, as shown below.

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/4a4d95f5-4a3a-8ea5-8c53-e264a8da1c55.png)

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/2357a506-e0c3-7475-7c0f-55f6a2bc86fa.png)

# `domains/domain1`
From this point onwards, the workspace administrators of each data domain will create and manage resources as needed for their domain's requirements.

In this sample implementation, the `domains/domain1` directory includes Terraform files for creating and managing a Unity Catalog catalog and related resources for data management specific to the domain. A brief explanation is provided below.

## Providers (`providers.tf`)
The Databricks workspace for the domain is used as the provider.

```terraform: providers.tf
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "databricks" {
  alias = "domain1"
  host  = var.domain1.url
  token = var.domain1.token
}
```

## Main (`main.tf`)
A module is called to create and manage the Unity Catalog and related resources for data management specific to the domain.

```terraform: main.tf
module "workspace_catalog1" {
  source = "../modules/workspace_catalog"
  providers = {
    aws        = aws
    databricks = databricks.domain1
  }
  prefix           = var.domain1.prefix
  catalog_name     = var.domain1.catalog_name
  admin_group_name = var.domain1.admin_group_name
}
```

## Module (`modules/workspace_catalog/main.tf`)
This module is almost a direct reuse of the sample implementation from the following link, with minor modifications:

https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/unity-catalog

The following resources are created and managed, all at the workspace level:

- Unity Catalog storage credential
- S3 bucket for the catalog
- IAM role and IAM policy used by Databricks control plane to access S3
- Unity Catalog external location
- Unity Catalog catalog
- Granting `ALL_PRIVILEGES` on the storage credential, external location, and catalog to the workspace admin group

The full code can be found on GitHub as it is quite long:

https://github.com/nakazax/aws-databricks-terraform-specific-examples/blob/main/examples/data_mesh_example/domains/modules/workspace_catalog/main.tf

## Arguments
```terraform: terraform.tfvars
region = "ap-northeast-1"

domain1 = {
  admin_group_name = "domain1-admin-group"
  catalog_name     = "domain1_main"
  prefix           = "random-prefix-domain1"
  token            = "1234567d-304d-4e66-8c03-11b10d68ba23"
  url              = "https://dbc-210868cc-1c64.cloud.databricks.com"
}
```

## Executing Terraform
You can execute Terraform in the same way as `platform/01_workspace_setup`.

```bash:Terraform Execution
$ cd aws-databricks-terraform-specific-examples/examples/data_mesh_example/domains/domain1
$ terraform init
$ terraform plan
$ terraform apply
```

## Execution Results
From the workspace's Web UI, you can access the Catalog Explorer and confirm that the storage credential, external location, and catalog have been created.

### Storage Credential
![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/0c43258f-d0d4-1d89-ca5b-18447cb2b3e0.png)

### External Location
![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/fc03bef3-5a3c-5fcd-2447-645623e170d7.png)

### Catalog
![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/68f46f68-0d40-6c5e-f9c9-d4adf8524a67.png)

Since we specified `ISOLATED` when creating the catalog, only the `domain` workspace can access this catalog.

![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/284925/9b1ee01d-c80e-3e2c-7583-ada51ef7803c.png)
