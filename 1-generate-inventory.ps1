<#
 	.DISCLAIMER
    This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  
    We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object
    code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software
    product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the
    Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims
    or lawsuits, including attorneys� fees, that arise or result from the use or distribution of the Sample Code.
    Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained
    within the Premier Customer Services Description.
#>
clear-host

################################################################################################
# 1 - Connecting to the environment and Exporting Subscription List
#
    $AzSubscriptionID = Get-AzSubscription -subscriptionid "d366243b-2b38-46f1-ac64-c6df9e1a929a"
    $mysubid = $AzSubscriptionID.id
    
    # Folder where the script will save the CSV and TXT files for each Tenant and Subscription
    Set-Location -path ($home + "/clouddrive")
    New-Item -Path "$mysubid" -Type Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Set-Location -path $mysubid

################################################################################################
# 2 - Defining functions to collect the data
#
    # This function receives and process commands collecting multiple data (Subscriptions, Resources, Groups, Users, Service Principals, Applications, RBAC Definition, etc)
    function Get_Inv_AzData () {
    [CmdletBinding()]
    param(
        [string]$datasource,
        [string]$cmd

    )
        $cmdn = $cmd
        if($datasource -eq "AAD"){
            $cmdn = $cmd + " -top " + [int]500  # use this option to collect Top 50 objects
            #$cmdn = $cmd + " -all " + 1       # use this option to collect ALL objects. As reference, it takes around 9:00minutes to collect 1000.
        }
        $AzureData = Invoke-Expression $cmdn
        $DataProperties = $AzureData[0] | Get-Member -MemberType Property
        foreach ($AzureDataEntry in $AzureData) {
            $obj = New-Object -TypeName PSCustomObject
            Foreach ($DataProperty in $DataProperties){
                if(($DataProperty.Definition -like "System.Collections*") -or ($DataProperty.Definition -like "Microsoft.Azure*")){
                    if ($DataProperty.Name -eq "Tags"){
                        if($null -eq $AzureDataEntry.Tags) {
                            $obj | Add-Member -MemberType NoteProperty -Name Tags -Value " " -Force
                        }else {
                            $ResTag = ([string]($AzureDataEntry.Tags.GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)," }))
                            $obj | Add-Member -MemberType NoteProperty -Name Tags -Value $ResTag -Force
                        }
                    }else{
                        $obj | Add-Member -MemberType NoteProperty -Name ($DataProperty.Name) -Value ([string]($AzureDataEntry.($DataProperty.Name) | ForEach-Object { "$($_)," })) -Force
                    }
                }else{
                    $obj | Add-Member -MemberType NoteProperty -Name ($DataProperty.Name) -Value $AzureDataEntry.($DataProperty.Name) -Force
                }
            }
            if($cmd -eq "Get-AzureADGroup"){
                $obj | Add-Member -MemberType NoteProperty -Name GroupMembers -Value ([string](Get-AzureADGroupMember -ObjectId $AzureDataEntry.ObjectId | ForEach-Object { "$($_.UserPrincipalName),"})) -Force
                $obj | Add-Member -MemberType NoteProperty -Name GroupMembersDetails -Value ([string](Get-AzureADGroupMember -ObjectId $AzureDataEntry.ObjectId | ForEach-Object { "$($_.UserPrincipalName):$($_.DisplayName):$($_.ObjectId):$($_.Type),"})) -Force
            }
            $obj
        }
    }

    # Functions to collect data specifically from Key Vaults and KV AccessPolicies
    function Get_Inv_AzKeyVaultAPTxt ($kvName) {
        $keyvaultAccessPoliciesText = @()
        $keyvaultAccessPoliciesText = @((Get-AzKeyVault -VaultName $kvName).AccessPoliciesText) -split "`n" | ForEach-Object { $_.trim() }
        $i=1
        while ($i -le ($keyvaultAccessPoliciesText.Count-3)){
            $obj1 = New-Object -TypeName PSCustomObject
            $obj1 | Add-Member -MemberType NoteProperty -Name TenantID -Value ($keyvaultAccessPoliciesText[$i]).Substring(45) -Force
            $obj1 | Add-Member -MemberType NoteProperty -Name ObjectID -Value ($keyvaultAccessPoliciesText[$i+1]).Substring(45) -Force
            $obj1 | Add-Member -MemberType NoteProperty -Name ApplicationID -Value ($keyvaultAccessPoliciesText[$i+2]).Substring(44) -Force
            $obj1 | Add-Member -MemberType NoteProperty -Name DisplayName -Value ($keyvaultAccessPoliciesText[$i+3]).Substring(44) -Force
            $obj1 | Add-Member -MemberType NoteProperty -Name PermissionsToKeys -Value ($keyvaultAccessPoliciesText[$i+4]).Substring(44) -Force
            $obj1 | Add-Member -MemberType NoteProperty -Name PermissionsToSecrets -Value ($keyvaultAccessPoliciesText[$i+5]).Substring(44) -Force
            $obj1 | Add-Member -MemberType NoteProperty -Name PermissionsToCertificates  -Value ($keyvaultAccessPoliciesText[$i+6]).Substring(44) -Force
            $obj1 | Add-Member -MemberType NoteProperty -Name PermissionsToStorage  -Value ($keyvaultAccessPoliciesText[$i+7]).Substring(44) -Force
            $obj1
            $i=$i+9
        }
    }

    function Get_Inv_AzKeyVault ($currentsubId) {
        function Export_KeyVault($currentsubId){
            foreach ($keyvault in $keyvaults){
                $obj = New-Object -TypeName PSCustomObject
                $obj | Add-Member -MemberType NoteProperty -Name VaultName -Value $keyvault.VaultName -Force
                $obj | Add-Member -MemberType NoteProperty -Name ResourceGroupName -Value $keyvault.ResourceGroupName -Force
                $obj | Add-Member -MemberType NoteProperty -Name Location -Value $keyvault.Location -Force
                $obj | Add-Member -MemberType NoteProperty -Name ResourceID -Value $keyvault.ResourceID -Force
                $obj | Add-Member -MemberType NoteProperty -Name VaultURI -Value $keyvault.VaultURI -Force
                $obj | Add-Member -MemberType NoteProperty -Name SKU -Value $keyvault.SKU -Force
                $obj | Add-Member -MemberType NoteProperty -Name AccessPolicies  -Value $keyvault.AccessPolicies -Force
                $obj | Add-Member -MemberType NoteProperty -Name AccessPoliciesText  -Value "Open the file 6_Inv_AzKeyVaultAccessPolicies-$($keyvault.VaultName).csv" -Force
                $obj
            }
        }
        $keyvaults = Get-AzKeyVault
        Export_KeyVault ($currentsubId) | Export-Csv -Path "10_Inv_AzKeyVault.csv" -NoTypeInformation  -Force | Out-Null
        foreach ($keyvault in $keyvaults){
            Get_Inv_AzKeyVaultAPTxt($keyvault.VaultName) | Export-Csv -Path ("6_Inv_AzKeyVaultAccessPolicies-" + $keyvault.VaultName + ".csv") -NoTypeInformation  -Force | Out-Null
        }
    }


################################################################################################
# 3 - Starting Data Collector
#
    write-host ""
    write-host "************************************ COLLECTING DATA FROM TENANT *******************************************"
    write-host ""
    write-host "Source Tenant: " $SourceTenantID " - Subscription: " $sub.Name
    write-host ""


    # 3.1 - Collecting AAD Role Definitions
    write-host "1 - Collecting AAD Role Definitions"
    Get_Inv_AzData -datasource "Azure" -cmd "Get-AzRoleDefinition -custom" | Export-Csv -Path "1_Inv_AzADRoleDefinition.csv" -NoTypeInformation -Force | Out-Null

    # 3.2 - Collecting Management Groups
    write-host "2 - Collecting Management Groups"
    Get_Inv_AzData -datasource "Azure" -cmd "Get-AzManagementGroup" | Export-Csv -Path "2_Inv_AzManagementGroup.csv" -NoTypeInformation -Force | Out-Null

    # 3.3 - Collecting Subscription Information
    write-host "3 - Collecting Subscription Information"
    Get_Inv_AzData -datasource "Subscription" -cmd "Get-AzSubscription -SubscriptionID $mysubid" | Export-Csv -Path "3_Inv_AzSubscription.csv" -NoTypeInformation  -Force | Out-Null
            
    # 3.4 - Collecting Subscription Resources
    write-host "4 - Collecting Subscription Resources"
    Get_Inv_AzData -datasource "Subscription" -cmd "Get-AzResource" | Export-Csv -Path "4_Inv_AzAllResources.csv" -NoTypeInformation  -Force | Out-Null
            
    # 3.5 - Collecting Management Group and Subscription Role Assignment
    write-host "5 - Collecting Subscription User Role Assignment"
    Get_Inv_AzData -datasource "Subscription" -cmd "Get-AzRoleAssignment" | Export-Csv -Path "5_Inv_RBAC.csv" -NoTypeInformation  -Force | Out-Null
                    
    # 3.6- Collecting Subscription Key Vaults and Access Policies
    write-host "6 - Collecting Subscription Key Vaults and Access Policies"
    Get_Inv_AzKeyVault ($mysubid)
            
    write-host ""
    write-host "***********************************************************************"

    Disable-AzContextAutosave  | Out-Null

    write-host ""
    write-host "************************************ DATA SUCCESSFULLY COLLECTED FROM ALL SUBSCRIPTIONS AND TENANT *******************************************"
    write-host ""

################################################################################################