<#
 	.DISCLAIMER
    MIT License

    Copyright (c) 2020 Rodrigo Santos

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>
clear-host

################################################################################################
# 1 - Connecting to the environment
#
    write-host "***************************************************************************************************************************"
    write-host "**                                                                                                                       **"
    write-host " This Script will recreate User Assigned Managed Identity, re-enable System Assigned Managed Identity to VMs, recreate     "
    write-host " Custom RBAC Roles Definitions, and then will finally re-apply RBAC Assignment to Users, Groups and UserManagedIdentities  "
    write-host " in the Management Group (in case using the same names), Subscription, Resource Groups, Resources, and Storage Account     "
    write-host " Blob Containers.                                                                                                          "
    write-host "                                                                                                                           "
    write-host " ------------ IMPORTANT ------------                                                                                       "
    write-host " This script assumes that you already migrated the Subscription to the new Tenant, recreated all necessary Users and Groups"
    write-host " and in case using a different Login Account on the new Tenant, that you already copied the reports folder from the old    "
    write-host " Clouddrive to your new one.                                                                                               " 
    Write-host "                                                                                                                           "

    $MySubscriptionID = Read-Host "Please enter your SubscriptionID "

    Set-AzContext -SubscriptionId $MySubscriptionID
    Select-AzSubscription -Subscription $MySubscriptionID
    $AzSubscription = Get-AzSubscription -subscriptionid $MySubscriptionID
    $mysubid = $AzSubscription.id

    # Folder where the script will save CSV and TXT files
    Set-Location -path ($home + "\clouddrive")
    if($True -ne (test-path -Path "$mysubid")){
        write-host "Reports Folder could not be found in your CloudDrive. Please make sure you have executed the 'export-RBAC.ps1' script and/or copied the reports folder to your CloudDrive"
        exit
    }

    # Installing/Importing required PowerShell modules
    if($null -eq (get-module  -name Az.ManagedServiceIdentity)){
        install-module -name Az.ManagedServiceIdentity -force -repository "PSGallery" -ErrorAction SilentlyContinue
    }
    if($null -eq (get-module  -name Az.AzureAD)){
        install-module -name AzureAD -force -repository "PSGallery" -ErrorAction SilentlyContinue
    }
    import-module -name Az.ManagedServiceIdentity -force -ErrorAction SilentlyContinue
    Import-Module -name AzureAD -Force -ErrorAction SilentlyContinue

################################################################################################
# 2 - Defining functions to recreate/reassign RBAC config. They all read the exported CSV files to recreate the objects/RBAC 
#

# 2.1 - Function to recreate User Assigned Identity
function Import-InvAzUserAssignedIdentity () {
    $path = "$mysubid\6_Inv_UserAssignedIdentity.csv"
    $InvAzUserAssignedIdentity = Import-Csv $path
    foreach ($uai in $InvAzUserAssignedIdentity) {
        New-AzUserAssignedIdentity -ResourceGroupName $uai.ResourceGroupName -Name $uai.Name -Location $uai.Location
    }
}

# 2.2 - Function to reenable System and/or User Assigned Identity
function Enable-InvAzSystemUserAssignedIdentity ($mysubid) {
    $path = "$mysubid\4_Inv_AzAllResources.csv"
    $InvAzSystemUserAssignedIdentity = Import-Csv $path
    foreach ($suai in $InvAzSystemUserAssignedIdentity) {
        if(($suai.Identity_Type -eq "SystemAssignedUserAssigned") -and ($suai.ResourceType -eq "Microsoft.Compute/virtualMachines")){
            $vm = Get-AzVM -ResourceGroupName $suai.ResourceGroupName -Name $suai.Name
            Update-AzVM -ResourceGroupName $suai.ResourceGroupName -VM $vm -AssignIdentity:$SystemAssigned
            $usids = [System.Collections.ArrayList]$suai.Identity_UserAssignedIdentities.Split(',')
            $usids.RemoveAt($usids.Count - 1)
            foreach ($usid in $usids) {
                Update-AzVM -ResourceGroupName $suai.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityID ($usid.trim())
            }
        }elseif(($suai.Identity_Type -eq "UserAssigned") -and ($suai.ResourceType -eq "Microsoft.Compute/virtualMachines")){
            $vm = Get-AzVM -ResourceGroupName $suai.ResourceGroupName -Name $suai.Name
            $usids = [System.Collections.ArrayList]$suai.Identity_UserAssignedIdentities.Split(',')
            $usids.RemoveAt($usids.Count - 1)
            foreach ($usid in $usids) {
                Update-AzVM -ResourceGroupName $suai.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityID ($usid.trim())
            }
        }elseif(($suai.Identity_Type -eq "SystemAssigned") -and ($suai.ResourceType -eq "Microsoft.Compute/virtualMachines")){
            $vm = Get-AzVM -ResourceGroupName $suai.ResourceGroupName -Name $suai.Name
            Update-AzVM -ResourceGroupName $suai.ResourceGroupName -VM $vm -AssignIdentity:$SystemAssigned
        }
    }
}

# 2.3 - Function to recreate all Custom RBAC Roles Definition
function Import-InvAzRoleDefinition ($mysubid) {
    $path = "$mysubid\1_Inv_AzADRoleDefinition.csv"
    $InvAzRoleDefinition = Import-Csv $path

    foreach ($rl in $InvAzRoleDefinition) {
        if($null -eq (Get-AzRoleDefinition -Name $rl.Name)){
            $role = Get-AzRoleDefinition "Virtual Machine Contributor"
            $role.Id = $null
            $role.Actions.RemoveRange(0, $role.Actions.Count)
            $role.DataActions.RemoveRange(0, $role.DataActions.Count)
            $role.NotActions.RemoveRange(0, $role.NotActions.Count)
            $role.NotDataActions.RemoveRange(0, $role.NotDataActions.Count)
            $role.Name = $rl.Name
            $role.Description = $rl.Description
            $role.AssignableScopes.Clear()

            if ($rl.actions.count -lt 2) {
                $rlactions = [System.Collections.ArrayList]$rl.actions.Split(',')
                $rlactions.RemoveAt($rlactions.Count - 1)
                foreach ($act in $rlactions) {
                    $role.Actions.Add($act)
                }
            }

            if ($rl.DataActions.count -lt 2) {
                $rldataactions = [System.Collections.ArrayList]$rl.DataActions.Split(',')
                $rldataactions.RemoveAt($rldataactions.Count - 1)
                foreach ($dataact in $rldataactions) {
                    $role.DataActions.Add($dataact.trim())
                }
            }

            if ($rl.NotActions.count -lt 2) {
                $Notrlactions = [System.Collections.ArrayList]$rl.NotActions.Split(',')
                $Notrlactions.RemoveAt($Notrlactions.Count - 1)
                foreach ($NotAct in $Notrlactions) {
                    $role.NotActions.Add($NotAct.trim())
                }
            }

            if ($rl.NotDataActions.count -lt 2) {
                $Notrldataactions = [System.Collections.ArrayList]$rl.NotDataActions.Split(',')
                $Notrldataactions.RemoveAt($Notrldataactions.Count - 1)
                foreach ($NotDataact in $Notrldataactions) {
                    $role.NotDataActions.Add($NotDataact.trim())
                }
            }

            if ($rl.AssignableScopes.count -lt 2) {
                $AsgScopes = [System.Collections.ArrayList]$rl.AssignableScopes.Split(',')
                $AsgScopes.RemoveAt($AsgScopes.Count - 1)
                foreach ($asc in $AsgScopes) {
                    $role.AssignableScopes.Add($asc.trim())
                }
            }
            New-AzRoleDefinition -Role $role
        }else{
            write-host "The following RBAC Definition already exists: " $rl.Name
        }
    }
}

# 2.4 - Function to Re-assign RBAC
# This function uses:
    # the 'MAIL' attribute to determine the 'User'
    # the 'DisplayName' to determine the 'Groups' (If you have created the Groups with different names, the script will fail to reassign the RBAC to them, you can update the CSV files manually to reflect the new names)
    # the 'DisplayName' + 'ResourceGroupName' to determine the 'UserManagedIdentity' (Since the UserManagedIdentity are created insite an RG, there should be no issues with this resource) 
function Import-InvAzRoleAssignment ($mysubid) {
    $path = "$mysubid\5_Inv_RBAC.csv"
    $InvAzRoleAssignment = Import-Csv $path
    foreach ($RoleAssignment in $InvAzRoleAssignment) {
        if ($RoleAssignment.ObjectType -eq "User") {
            $userId = Get-AzADUser -Mail $RoleAssignment.Mail
            New-AzRoleAssignment -SignInName $userId.SignInName -RoleDefinitionName $RoleAssignment.RoleDefinitionName -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
        }
        elseif ($RoleAssignment.ObjectType -eq "Group") {
            $groupId = Get-AzADGroup -SearchString $RoleAssignment.DisplayName
            New-AzRoleAssignment -ObjectId $groupId.id -RoleDefinitionName $RoleAssignment.RoleDefinitionName -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
        }
        elseif (($RoleAssignment.ObjectType -eq "ServicePrincipal") -and ($RoleAssignment.ServicePrincipalType -eq "ManagedIdentity")) {
            $servicePrincipal = Get-AzADServicePrincipal -SearchString $RoleAssignment.DisplayName
            New-AzRoleAssignment -RoleDefinitionName $RoleAssignment.RoleDefinitionName -ApplicationId $servicePrincipal.ApplicationId -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

################################################################################################
# 3 - Starting Functions
#
write-host ""
write-host "************************************ RECONFIGURING SUBSCRIPTION AND RESOURCES ************************************ "
write-host ""
write-host "Subscription: "  $AzSubscription.Name
write-host ""

    # 3.1 - Recreating User Assigned Managed Identity"
    write-host "1 - Recreating User Assigned Managed Identity"
    Import-InvAzUserAssignedIdentity -mysubid $mysubid

    # 3.2 - Reenabling System Managed Identity and/or reassigning User Assigned Identity"
    write-host "2 - Reenabling System Managed Identity and/or reassigning User Assigned Identity"
    Enable-InvAzSystemUserAssignedIdentity -mysubid $mysubid

    # 3.3 - Recreating RBAC Custom Role Definition"
    write-host "3 - Recreating RBAC Custom Role Definition"
    Import-InvAzRoleDefinition -mysubid $mysubid
    
    write-host "Waiting 30 seconds to replicate the RBAC Definition"
    Start-Sleep -s 30
    
    # 3.4 - Reapplying RBAC Aassignment to Users, Groups and UserManagedIdentities in all Scopes (Data and Management Plans)"
    write-host "4 - Reapplying RBAC Aassignment to Users, Groups and UserManagedIdentities in all Scopes (Data and Management Plans)"
    Import-InvAzRoleAssignment -mysubid $mysubid


    write-host ""
    write-host "****************** CONFIGURATION SUCCESSFULLY APPLIED TO THE  SUBSCRIPTION  ******************"
    Write-host ""
    write-host "****************** RECOMMENDED NEXT STEPS ******************"
    Write-host "1 - Run the 'Export-RBAC.ps1' Script again and compare the CSVs"
    Write-host "2 - Validate if some VMs have their respective System or User assigned Identity"
    Write-host "3 - Validate if Storage Account Containers received the RBAC correctly"
    Write-host "4 - Follow the next steps of your Migration Playbook"
    Write-host ""

################################################################################################