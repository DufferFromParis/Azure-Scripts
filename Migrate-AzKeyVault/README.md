# Key Vault Access Policy to RBAC Migration Script
Powershell script I wrote to help migrating Key Vaults from the access policy model to RBAC. Based my script on Microsoft's [Access Policy to Azure RBAC Comparison Tool](https://github.com/Azure/KeyVault-AccessPolicyToRBAC-CompareTool)

## Table of contents

- [Prerequisites](#prerequisites)
- [Input Files](#input-files)
- [Script](#script)
- [Contributing](#contributing)

## Prerequisites

- Place the script and both csv files in the same directory
- Use latest AZ Modules especially the latest AZ.KeyVault module as some change as been done on the Update-AzKeyVault cmdlet replacing the EnableRbacAuthorization parameter by DisableRbacAuthorization.
- Azure Subscription(s) obviously
- Permissions (to be detailled someday but you need to be able to read key vaults resources in your sub, contributor on the key vault you'll select for migration and also some Entra permissions to be able to resolve Service Principals' Id.)
- Use Connect-AZAccount prior lauching the script to put yourself in the right context. Might add connection management in the script in a future release.

## Input Files

**AccessPolicyRBACMapping.csv**: Picked from the compare tool. Useful file to map ACLs to RBAC Permissions.

**KeyVaultRolesHierarchy.csv**: File I made to represent the hierarchy of Key Vaults Data Plane RBAC Roles, focused on DataActions capabilities of each roles. Here is the hierarchy I worked with:

- Key Vault Administrator
  - Key Vault Secrets Officer
    - Key Vault Secrets User
  - Key Vault Certificates Officer
    - Key Vault Certificate User
  - Key Vault Crypto Officer
    - Key Vault Crypto User
      - Key Vault Crypto Service Encryption User
      - Key Vault Crypto Service Release User
  - Key Vault Reader

## Script

The script has 3 modes, Whatif, Unique and Least.

**Whatif** : This mode is here to help you make the right choice, it will display for each of the ACL the needed RBAC roles, the role that would be applied if you chose the **Unique** mode and the role(s) that would be applied if you select the **Least** mode

**Unique** : This mode will convert each ACL to a unique RBAC Role Assignment. For example if your ACL contains permissions to read secrets and to have full control on Keys then the unique role that does both is Key Vault Administrator. It is not at all optimized for least privileges scenarios but for least amount of role assignments.

**Least** : This mode will convert each ACL to a set of RBAC Role Assignment. If we take the same example as above then the target roles in the Lease mode would be Key Vault Secret Reader and Key Vault Crypto Officer.

Here is the script sequence:
- Read input files
- Check if user is connected to Azure
- List key vaults that still use ACLs and let you pick one
- Get ACLs for the selected key vault
- Lists needed roles to match the permissions ofr each ACL
- if you selected Whatif mode then the script just displays informations
- if you selected Unique or Least modes then the script will applied the Role Assignments equivalent to each ACL then convert the Key Vault to RBAC Authentication.

## Contributing
There is room for many improvements so please help yourself and report issues if you encounter any bug !
