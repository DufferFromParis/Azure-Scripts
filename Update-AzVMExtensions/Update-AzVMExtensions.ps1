# Author: Duffer
# Description: Updates extensions for all VMs in the given subscription. It checks the current version of each extension against the latest available version and updates it if necessary. Use the -update switch to perform the update.
# Version: 1.0.0
# Date: 2026-03-23

param (
    [Parameter(Mandatory=$true)][string]$tenant,
    [Parameter(Mandatory=$true)][string]$subscription,
    [Parameter(Mandatory=$false)][switch]$update
)



# CONNECT TO AZURE
try
{
    if($null -eq $con)
    {
        $con = Connect-AzAccount -Tenant $tenant -Subscription $subscription -WarningAction SilentlyContinue
    }
}
catch
{
    write-host -ForegroundColor Red -Object $_.Exception.Message
    break
}

# GET ALL VMS IN THE SUBSCRIPTION
try
{
    $VMs = Get-AzVM -Status -ErrorAction Stop | Sort-Object Name
}
catch
{
    Write-Host -ForegroundColor Red -Object "Cannot retrieve VMs information in subscription $subscription"
    break
}

$latestversionsdict = @{}
foreach($VM in $VMs)
{
    if($VM.PowerState -eq "VM Running")
    {
        # GET ALL EXTENSIONS FOR THE VM EXCEPT VMappextension WHICH GENERRATES ERRORS WHEN TRYING TO GET ITS STATUS (to be investigated)
        Write-Host -ForegroundColor White -Object $VM.Name
        $VMExtensions = $VM | Get-AzVMExtension | Where-Object {$_.Name -ne "VMappextension"}
        foreach ($VMExtension in $VMExtensions)
        {
            try
            {
                # GET THE CURRENT VERSION OF THE EXTENSION
                $extension = Get-AzVMExtension -ResourceGroupName $VM.ResourceGroupName -VMName $VM.Name -Name $VMExtension.Name -Status -ErrorAction Stop
                $version = $extension.instanceView.typeHandlerVersion

                # CHECK IF THE LATEST VERSION OF THE EXTENSION IS ALREADY CACHED IN THE DICTIONARY, ELSE RETRIEVE IT AND ADD IT TO THE DICTIONARY
                if($latestversionsdict.ContainsKey($VMExtension.Name))
                {
                    $latestversion = $latestversionsdict[$VMExtension.Name]
                }
                else
                {
                    $extensionimage = Get-AzVMExtensionImage -Location $VMExtension.Location -PublisherName $VMExtension.Publisher -Type $VMExtension.ExtensionType
                    $latestversion = ($extensionimage.Version  | Sort-Object {[version] $_})[$extensionimage.length - 1]
                    $latestversionsdict.Add($VMExtension.Name,$latestversion)
                }

                # COMPARE THE CURRENT VERSION WITH THE LATEST VERSION
                if($version -eq $latestversion)
                {
                    Write-Host -ForegroundColor Green -Object $("    " + $VMExtension.Name + " " + $version + " " + $latestversion)
                }
                else
                {
                    # UPDATE THE EXTENSION IF THE -UPDATE SWITCH IS PROVIDED
                    If($update)
                    {
                        Write-Host -ForegroundColor Yellow -Object $("    " + $VMExtension.Name + " " + $version + " " + $latestversion) -NoNewline
                        $URL = "$($VMExtension.Id)?api-version=2024-07-01"
                        $get = Invoke-AZRestMethod -Path $URL -Method GET
                        $patch = Invoke-AZRestMethod -Path $URL -Method PATCH -Payload $get.Content
                        Write-Host -ForegroundColor Green "  updating..."
                    }
                    Else
                    {
                        Write-Host -ForegroundColor Yellow -Object $("    " + $VMExtension.Name + " " + $version + " " + $latestversion)
                    }
                }
            }
            catch
            {
                Write-Host -ForegroundColor Red -Object $("    " + $VMExtension.Name + " Unknown version")
            }
        }
    }
    else
    {
        Write-Host -ForegroundColor Red -Object $($VM.Name + " is not running")
    }
}