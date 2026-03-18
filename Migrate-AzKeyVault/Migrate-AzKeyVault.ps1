# Author: Duffer
# Description: Helps migrating Key Vaults from Access Policies to Azure RBAC.
# Version: 1.0.0
# Date: 2026-03-18

#Params
[CmdletBinding()]
param (
    [Parameter(Mandatory)][string][ValidateSet("Least","Unique","Whatif")]$Target
)

#Functions
function Get-Parents {
    param([Parameter(Mandatory)][string]$Role)

    $parents = [System.Collections.Generic.HashSet[string]]::new()
    $currentRole = $Role
    while ($parentOf.ContainsKey($currentRole) -and $parentOf[$currentRole]) {
        $parentRole = $parentOf[$currentRole]
        if (-not $parents.Add($parentRole)) {break}
        $currentRole = $parentRole
    }
    return @($parents)
}

function Get-LowestRoles {
    param([Parameter(Mandatory)][string[]]$Roles)

    $inputRoles = $Roles | ForEach-Object {$_.Trim()} | Where-Object {$_} | Select-Object -Unique
    $tokeep = @()
    foreach ($role in $inputRoles) {
        $isParentOfAnother = $false
        foreach ($other in $inputRoles) {
            if ($other -ne $role) {
                $parents = Get-Parents -Role $other
                if ($parents -contains $role) {
                    $isParentOfAnother = $true
                    break
                }
            }
        }
        if (-not $isParentOfAnother) {$toKeep += $role}
    }
    return ,$toKeep
}

function Get-ParentsInclusiveList {
    param([Parameter(Mandatory)][string]$Role)

    $list = [System.Collections.Generic.HashSet[string]]::new()
    $currentRole = $Role
    while ($currentRole) {
        $list.Add($currentRole) | Out-Null
        if ($parentOf.ContainsKey($currentRole) -and $parentOf[$currentRole]) {
            $currentRole = $parentOf[$currentRole]
        }
        else {
            $currentRole = $null
        }
    }
    return ,$list
}

function Get-LowestCommonAncestor {
    param([Parameter(Mandatory)][string[]]$Roles)

    $inputRoles = $Roles | ForEach-Object {$_.Trim()} | Where-Object {$_} | Select-Object -Unique
    if ($inputRoles.Count -eq 0) {return $null}
    if ($inputRoles.Count -eq 1) {return $inputRoles[0]}

    $common = $null
    foreach ($role in $inputRoles) {
        $parents = Get-ParentsInclusiveList -Role $role
        if ($null -eq $common) {
            $common = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($parent in $parents) {$common.Add($parent) | Out-Null}
        }
        else {
            $common.IntersectWith($parents)
            if ($common.Count -eq 0) {return $null}
        }
    }
    return $(Get-LowestRoles -Roles $common)
}

function Remove-ChildrenRoles {
    param([Parameter(Mandatory)][string[]]$Roles)

    $toKeep = New-Object System.Collections.Generic.List[string]
    $inputRoles = $Roles | ForEach-Object {$_.Trim()} | Where-Object {$_} | Select-Object -Unique
    if ($inputRoles.Count -eq 0) {return $null}
    if ($inputRoles.Count -eq 1) {return $inputRoles[0]}
    if($inputRoles -contains "Key Vault Administrator") {
        return "Key Vault Administrator"
    }
    else {
        foreach ($role in $inputRoles) {
            $isparentthere = $false
            foreach ($parent In Get-Parents -Role $role) {
                if($inputRoles -contains $parent) {
                    $isparentthere = $true
                    break
                }
            }
            if(-not $isparentthere) {
                $toKeep.Add($role) | Out-Null
            }
        }
    }
    return ,$toKeep
}

#INPUT FILES
$mappingTable = $null
$mappingTable = Import-Csv -Path ./AcessPolicyRBACMapping.csv
$keyVaultroleshierarchy= $null
$keyVaultroleshierarchy = Import-Csv -Path ./keyVaultRolesHierarchy.csv

If ($null -eq $mappingTable -or $null -eq $keyVaultroleshierarchy) {
    Write-Host "Cannot load input files. Please make sure AcessPolicyRBACMapping.csv and keyVaultRolesHierarchy.csv are in the same folder as the script and not opened in another program." -ForegroundColor Red
    break
}

#CHECK CONNECTION
try {
    # Try to get a valid access token for ARM (Azure Resource Manager)
    $token = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction SilentlyContinue
    if ($token) {
    # Check expiration
        $expiry = $token.ExpiresOn.UtcDateTime
        if(-not($expiry -gt (Get-Date).ToUniversalTime())) {
            Write-Host "You need to run Connect-AzAccount first." -ForegroundColor Red
            break
        }
    }
    else {
        Write-Host "You need to run Connect-AzAccount first." -ForegroundColor Red
        break
    }
}
catch {
    Write-Host "You need to run Connect-AzAccount first." -ForegroundColor Red
    break
}

#GET KEY VAULT ROLES WITH DATA ACTIONS
$kvroles = Get-AzRoleDefinition | Where-Object {$_.Name -like "Key Vault*" -and $_.DataActions}

#BUILD ROLES HIERARCHY VARIABLES
$parentOf = @{}
$childrenOf = @{}

foreach ($role in $keyVaultroleshierarchy) {
    $rolename   = $role.Role.Trim()
    $parent = $role.Parent.Trim()

    $parentOf[$rolename] = if ($parent -and $parent -ne 'None') {$parent} else {$null}

    if ($parent -and $parent -ne 'None') {
        if (-not $childrenOf.ContainsKey($parent)) {$childrenOf[$parent] = [System.Collections.Generic.List[string]]::new()}
        $childrenOf[$parent].Add($rolename)
    }
    if (-not $childrenOf.ContainsKey($rolename)) {$childrenOf[$rolename] = [System.Collections.Generic.List[string]]::new()}
}

#GET KEY VAULTS
Write-Host "Detecting Key Vaults in subscription " -ForegroundColor Cyan -NoNewline
Write-Host "$((Get-AzContext).Subscription.Name)" -ForegroundColor Yellow

$keyVaults = Get-AzkeyVault
if ($null -eq $keyVaults) {
    Write-Host "No Key Vault detected in the subscription" -ForegroundColor Cyan
    break
}

#FILTER KEY VAULTS WITH ACCESS POLICIES AND DISPLAY THEM
$aclkeyVaults = @()
foreach ($kv in $keyVaults) {
    $detailskv = Get-AzkeyVault -VaultName $kv.VaultName
    if($detailskv.enableRbacAuthorization -eq $false) {
        $aclkeyVaults += [PSCustomObject]@{
            Id = $aclkeyVaults.count
            RG = $detailskv.ResourceGroupName
            Name = $detailskv.VaultName
            AccessPolicies = $detailskv.AccessPolicies
            ResourceId = $detailskv.ResourceId
       }
    }
}

#IF NO KEY VAULT WITH ACCESS POLICIES THEN EXIT SCRIPT, OTHERWISE DISPLAY LIST OF KEY VAULTS WITH ACCESS POLICIES
if($aclkeyVaults.count -eq 0) {
    Write-Host "No Key Vault with Access Policies detected in subscription " -ForegroundColor Cyan
    break
}

$aclkeyVaults | Format-Table -Property @{Name="Id";Expression={"[" + $($_.Id + 1) + "]"}}, @{Name="Resource Group";Expression={$_.RG}}, Name -AutoSize

#SELECT AND CHECK INPUT
$keyVault = $null
Write-Host "Select a key vault (type its Id from the list above): " -ForegroundColor Cyan -NoNewline
$keyVaultIndex = Read-Host

if([int]::TryParse($keyVaultIndex, [ref]$null)) {
    $keyVault = $aclkeyVaults[$keyVaultIndex-1]
    if(-not $keyVault) {
        Write-Host "Invalid selection. Provide Id in the following range: 1 to $($aclkeyVaults.Count)" -ForegroundColor Red
        break
    }
}
else {
    Write-Host "Select key vault: Typed key vault is not a number." -ForegroundColor Red
    break
}

$keyVaultname = $keyVault.Name
Write-Host "Inspecting Key Vault " -ForegroundColor Cyan -NoNewline
Write-Host "$keyVaultname" -ForegroundColor Yellow
Write-Host ""

#GET ACCESS POLICIES
#FILL MAPPING TABLE
$APtoRBACMap=@{}
$AllRBACDataActions=@{}
foreach ($mapping in $mappingTable) {
    $dataActionArray =($mapping.'RBAC Data Action'.ToLower()).Split(";")
    $dataActionHashTable = @{}
    foreach ($dataAction in $dataActionArray) {
        $dataActionHashTable.Item($dataAction)=""
        $AllRBACDataActions.Item($dataAction)=""
    }
    $APtoRBACMap.Item($mapping.'Access Policy Permission'.ToLower())=$dataActionHashTable
}

# LISTS SERVICE PRINCIPAL PERMISSIONS
$APPermissionsByIdentity = @{}
foreach ($accessPolicy in $($keyVault.AccessPolicies)) {
   foreach ($keysPermission in $accessPolicy.PermissionsToKeys) {
        if ($null -eq $APPermissionsByIdentity.Item($accessPolicy.ObjectId) -or -not $APPermissionsByIdentity.Item($accessPolicy.ObjectId).ContainsKey("key " + $keysPermission.ToLower())) {
            $APPermissionsByIdentity.Item($accessPolicy.ObjectId) += @{("key " + $keysPermission.ToLower())=""}
        }
    }
    foreach ($keysPermission in $accessPolicy.PermissionsToCertificates) {
        if ($null -eq $APPermissionsByIdentity.Item($accessPolicy.ObjectId) -or -not $APPermissionsByIdentity.Item($accessPolicy.ObjectId).ContainsKey("certificate " + $keysPermission.ToLower())) {
            $APPermissionsByIdentity.Item($accessPolicy.ObjectId) += @{("certificate " + $keysPermission.ToLower())=""}
        }
    }
    foreach ($keysPermission in $accessPolicy.PermissionsToSecrets) {
        if ($null -eq $APPermissionsByIdentity.Item($accessPolicy.ObjectId) -or -not $APPermissionsByIdentity.Item($accessPolicy.ObjectId).ContainsKey("secret " + $keysPermission.ToLower())) {
            $APPermissionsByIdentity.Item($accessPolicy.ObjectId) += @{("secret " + $keysPermission.ToLower())=""}
        }
    }
    foreach ($keysPermission in $accessPolicy.PermissionsToStorage) {
        if ($null -eq $APPermissionsByIdentity.Item($accessPolicy.ObjectId) -or -not $APPermissionsByIdentity.Item($accessPolicy.ObjectId).ContainsKey("storage " + $keysPermission.ToLower())) {
            $APPermissionsByIdentity.Item($accessPolicy.ObjectId) += @{("storage " + $keysPermission.ToLower())=""}
        }
    }
}

foreach ($APPermission In $APPermissionsByIdentity.GetEnumerator()) {
    $id = $APPermission.Name
    $assignments = $null
    $identityDisplayName = ($keyVault.AccessPolicies | Where-Object -Property ObjectId -eq "$id").DisplayName
    Write-Host $identityDisplayName -ForegroundColor Magenta
    #GET EXISTING ASSIGNMENTS FOR SERVICE PRINCIPAL
    try {
        $assignments = Get-AzRoleAssignment -ObjectId $id -ExpandPrincipalGroups -ErrorAction Stop | Where-Object {$keyVault.ResourceId -match $_.Scope}
    }
    catch {
        $assignments = Get-AzRoleAssignment -ObjectId $id | Where-Object {$keyVault.ResourceId -match $_.Scope}
    }

    #LISTS NEEDED ROLES TO MATCH ACCESS POLICY PERMISSIONS
    $neededkvroles = @()
    foreach ($perm in $APPermission.Value) {
        foreach ($o In $perm.Keys) {
            $dataAction = $(($mappingTable | Where-Object {$_.'Access Policy Permission' -eq $o}).'RBAC Data Action')
            $eligiblekvroles = @()
            ForEach ($kvrole in $kvroles) {
                Foreach ($RoleDataAction in $kvrole.DataActions) {
                    if($dataAction -match $RoleDataAction) {
                        if($eligiblekvroles -notcontains $kvrole) {$eligiblekvroles += $kvrole}
                    }
                }
            }

            $lowestRole = $(Get-LowestRoles -Roles $eligiblekvroles.Name)
            if($lowestRole.count -gt 1) {
                switch ($dataAction.split("/")[2]) {
                    "certificates" {$lowestRole = $lowestRole | Where-Object {$_ -like "*Certificate*"}}
                    "certificatescas" {$lowestRole = $lowestRole | Where-Object {$_ -like "*Certificate*"}}
                    "certificatescontacts" {$lowestRole = $lowestRole | Where-Object {$_ -like "*Certificate*"}}
                    "keys" {$lowestRole = $lowestRole | Where-Object {$_ -like "*Crypto*"}}
                    "keyrotationpolicies" {$lowestRole = $lowestRole | Where-Object {$_ -like "*Crypto*"}}
                    "secrets" {$lowestRole = $lowestRole | Where-Object {$_ -like "*Secret*"}}
                    Default {}
                }
            }
            if($neededkvroles -notcontains $lowestRole) {$neededkvroles += $lowestRole}
        }
    }

    if($Target -eq "WhatIf"){
        Write-Host "------------------ NEEDED ROLES TO MATCH ACLS ------------------" -ForegroundColor Blue
        $neededkvroles
        Write-Host "-------------------------- UNIQUE ROLE -------------------------" -ForegroundColor Blue
        if($neededkvroles.count -gt 1) {Get-LowestCommonAncestor -Roles $neededkvroles} else {$neededkvroles}
        Write-Host "-------------------- LEAST PRIVILEGED ROLES --------------------" -ForegroundColor Blue
        if($neededkvroles.count -gt 1) {Remove-ChildrenRoles -Roles $neededkvroles} else {$neededkvroles}
        Write-Host "----------------------------------------------------------------" -ForegroundColor Blue
        Write-Host ""
    }
    else {
        $targetroles = $null
        switch ($Target) {
            "Unique" { if($neededkvroles.count -gt 1) {$targetroles = Get-LowestCommonAncestor -Roles $neededkvroles} else {$targetroles = $neededkvroles} }
            "Least" { if($neededkvroles.count -gt 1) {$targetroles = Remove-ChildrenRoles -Roles $neededkvroles} else {$targetroles = $neededkvroles} }
            Default {}
        }

        Foreach($Role in $targetroles) {
            Write-Host "Assigning role '$Role' to '$identityDisplayName' on '$($keyVault.ResourceId)' " -ForegroundColor Green -NoNewline
            if($assignments.RoleDefinitionName -contains $Role) {
                Write-Host "(already assigned)" -ForegroundColor Yellow
            }
            else {
                New-AzRoleAssignment -RoleDefinitionName $Role -ObjectId $id -Scope $keyVault.ResourceId | Out-Null
                Write-Host "(assigned)" -ForegroundColor Green
            }
        }
        Write-Host ""
    }
}

#ENABLE RBAC ON KEY VAULT
if($target -ne "WhatIf") {
    Write-Host "Switching Key Vault $keyVaultname from access policies to Azure RBAC. Ready to proceed ? " -ForegroundColor Red -NoNewline
    while ($choice -ne "Y" -and $choice -ne "N") {
        $choice = Read-Host -Prompt "Type Y to proceed, N to exit"
    }
    if ($choice -eq "Y") {
        try {
            Update-AzkeyVault -VaultName $keyVaultname -ResourceGroupName $keyVault.RG -DisableRbacAuthorization $false -ErrorAction Stop | Out-Null
        }
        catch {
            write-Host "Error while updating Key Vault. Please check the error message below and fix the issue before running the script again." -ForegroundColor Red
            write-Host $_.Exception.Message -ForegroundColor Red
            break
        }
        Write-Host "Key Vault migrated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Exiting script without making any change." -ForegroundColor Green
        break
    }
}