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
    write-host "This Script generates a Subscription inventory with the following: RBAC Assignment, RBAC Custom Roles, List of Resources, "
    write-host "List of Management Groups, List of StorageAccount Blob Containers using RBAC, List of AzureSQL using RBAC for the Admin,  "
    write-host "List of Key Vaults and their Access Policies, List of Managed Identities, and much more can be esily incorporated.        "
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
# 2 - ReAdding RBAC Assignment
#

function New-InvAzRoleAssignment () {
    $path = "$mysubid\9_Inv_AzRoleAssignment.csv"
        $InvAzRoleAssignment = Import-Csv $path
        foreach ($RoleAssignment in $InvAzRoleAssignment) {
            if ($RoleAssignment.ObjectType -eq "User"){
                New-AzRoleAssignment -SignInName $RoleAssignment.SignInName -RoleDefinitionName $RoleAssignment.RoleDefinitionName -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
            }elseif ($RoleAssignment.ObjectType -eq "Group"){
                $groupId = Get-AzADGroup -SearchString $RoleAssignment.DisplayName
                New-AzRoleAssignment -ObjectId $groupId.id -RoleDefinitionName $RoleAssignment.RoleDefinitionName -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
            }elseif ($RoleAssignment.ObjectType -eq "ServicePrincipal"){
                $servicePrincipal = Get-AzADServicePrincipal -SearchString $RoleAssignment.DisplayName
                New-AzRoleAssignment -RoleDefinitionName $RoleAssignment.RoleDefinitionName -ApplicationId $servicePrincipal.ApplicationId -Scope $RoleAssignment.Scope -ErrorAction SilentlyContinue | Out-Null
            }
        }
}
New-InvAzRoleAssignment