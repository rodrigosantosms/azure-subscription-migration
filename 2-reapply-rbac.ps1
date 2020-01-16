<#
 	.DISCLAIMER
    This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  
    We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object
    code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software
    product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the
    Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims
    or lawsuits, including attorneysï¿½ fees, that arise or result from the use or distribution of the Sample Code.
    Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained
    within the Premier Customer Services Description.
#>
Clear-Host

# Update the three variables below with Source and Destination TenantIDs, and with the Path of the Working FOLDER same as defined in Script "0".
# This script will be executed against the Destination Tenant, and it will check if all Service Principals in the CSV already exist, if they do not exist, it will create them
# Validate the script before running it, and use at your own risk.

# Source Tenant ID
$SourceTenantID = " "

# Destination Tenant ID
$TargetTenantID = " "


################################################################################################
# 1 - Connecting to the environment
#
    # Login in the Azure environment
    #Login-AzAccount

    # Connecting to the Destination Tenant
    #Connect-AzureAD -TenantId $TargetTenantID

    # CSV Folder - Folder where the scripts are saving the data
    $workingfolder = Split-Path $script:MyInvocation.MyCommand.Path
    Set-Location -path $workingfolder
    $CSVExportFolder = "$workingfolder\$SourceTenantID"


################################################################################################
# 2 - ReAdding RBAC Assignment
#

function New-InvAzRoleAssignment () {
    $InvAzSubscriptions = Import-Csv "$CSVExportFolder\0_Inv_AzAllSubscriptions.csv"
    foreach($sub in $InvAzSubscriptions){
    $path = $sub.id + "$CSVExportFolder\$sub.id\9_Inv_AzRoleAssignment.csv"
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
}
New-InvAzRoleAssignment