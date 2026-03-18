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
- Azure Subscription(s)
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

todo


## Contributing
Pretty sure there is room for many improvements so please help yourself !
