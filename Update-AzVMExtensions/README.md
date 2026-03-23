# VM Extensions Update Script
Powershell script I wrote to speed up the process of VM Extensions auto updates and to update extensions not covered by auto updates.

## Table of contents

- [Prerequisites](#prerequisites)
- [Script](#script)
- [Contributing](#contributing)

## Prerequisites

- Use latest AZ Modules.
- Azure Subscription(s) obviously
- Permissions (to be detailled someday but globally you need to be Reader to be able to list VMs and Virtual Machine Contributor to update VM Extensions)

## Script

To launch the script to check if updates are available:

`.\Update-AzVMExtensions.ps1 -tenant <tenant name> -subscription <subscription name>`


To launch the script to apply updates simply add the update switch:

`.\Update-AzVMExtensions.ps1 -tenant <tenant name> -subscription <subscription name> -update`


Here is the script sequence:
- Check if user is connected to Azure
- List all VMs in subscription
- List all extensions versions and the latest version available
- if -update is specified then extensions are updated to the latest version

## Contributing
There is room for many improvements so please help yourself and report issues if you encounter any bug !
