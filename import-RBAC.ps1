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
write-host "**************************************************************************************************************************"
write-host "**                                                                                                                      **"
write-host "This Script recreates custom RBAC Roles and reassigns RBAC                                                                "
Write-host "                                                                                                                          "
pause

$MySubscriptionID = Read-Host "Please enter your SubscriptionID: "

Set-AzContext -SubscriptionId $MySubscriptionID
Select-AzSubscription -Subscription $MySubscriptionID
$AzSubscription = Get-AzSubscription -subscriptionid $MySubscriptionID
$mysubid = $AzSubscription.id

# Folder where the script will save CSV and TXT files
Set-Location -path ($home + "\clouddrive")

################################################################################################
# 2 - Importing RBAC Assignment
#

function Import-InvAzRoleAssignment () {
    $path = "$mysubid\5_Inv_RBAC.csv"
    $InvAzRoleAssignment = Import-Csv $path
    foreach ($RoleAssignment in $InvAzRoleAssignment) {
        if ($RoleAssignment.ObjectType -eq "User") {
            New-AzRoleAssignment -SignInName $RoleAssignment.SignInName -RoleDefinitionName $RoleAssignment.RoleDefinitionName -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
        }
        elseif ($RoleAssignment.ObjectType -eq "Group") {
            $groupId = Get-AzADGroup -SearchString $RoleAssignment.DisplayName
            New-AzRoleAssignment -ObjectId $groupId.id -RoleDefinitionName $RoleAssignment.RoleDefinitionName -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
        }
        elseif ($RoleAssignment.ObjectType -eq "ServicePrincipal") {
            $servicePrincipal = Get-AzADServicePrincipal -SearchString $RoleAssignment.DisplayName
            New-AzRoleAssignment -RoleDefinitionName $RoleAssignment.RoleDefinitionName -ApplicationId $servicePrincipal.ApplicationId -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# Function to recreate all Custom RBAC Roles (it will read all Custom Roles in the CSV file and will recreate them with the same names in the new Tenant)
function Import-InvAzRoleDefinition ($mysubid) {
    $path = "$mysubid\1_Inv_AzADRoleDefinition.csv"
    $InvAzRoleDefinition = Import-Csv $path

    foreach ($rl in $InvAzRoleDefinition) {
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
    }
}
Import-InvAzRoleDefinition -mysubid $mysubid
Import-InvAzRoleAssignment -mysubid $mysubid