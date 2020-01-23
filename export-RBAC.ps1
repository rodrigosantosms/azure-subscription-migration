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
    New-Item -Path "$mysubid" -Type Directory -Force -ErrorAction SilentlyContinue | Out-Null

    # Downloading Second Script
    $file2 = "https://raw.githubusercontent.com/rodrigosantosms/azure-subscription-migration/master/import-RBAC.ps1"
    Invoke-WebRequest -Uri $file2 -outfile "import-RBAC.ps1"

    install-module -name Az.ManagedServiceIdentity -force
    install-module -name AzureAD -force
    import-module -name Az.ManagedServiceIdentity -force
    Import-Module -name AzureAD -Force

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
            if(($datasource -eq "Subscription") -and ($cmd -eq "Get-AzRoleAssignment")){
                if($AzureDataEntry.ObjectType -eq "User"){
                    $currentRBACUser = get-azureaduser -filter "ObjectId eq '$AzureDataEntry.ObjectId'"
                    $obj | Add-Member -MemberType NoteProperty -Name ("UserType") -Value  ($currentRBACUser).UserType -Force
                    $obj | Add-Member -MemberType NoteProperty -Name ("Mail") -Value ($currentRBACUser).Mail -Force
                    $obj | Add-Member -MemberType NoteProperty -Name ("DirSyncEnabled") -Value ($currentRBACUser).DirSyncEnabled -Force
                    $obj | Add-Member -MemberType NoteProperty -Name ("AccountEnabled") -Value ($currentRBACUser).AccountEnabled -Force
                    $obj | Add-Member -MemberType NoteProperty -Name ("MailNickName") -Value ($currentRBACUser).MailNickName -Force
                }elseif ($AzureDataEntry.ObjectType -eq "Group"){
                    $currentRBACGroup = get-azureadgroup -filter "ObjectId eq '$AzureDataEntry.ObjectId'"
                    $obj | Add-Member -MemberType NoteProperty -Name ("DirSyncEnabled") -Value  ($currentRBACGroup).DirSyncEnabled -Force
                    $obj | Add-Member -MemberType NoteProperty -Name ("MailNickName") -Value ($currentRBACGroup).MailNickName -Force
                }elseif($AzureDataEntry.ObjectType -eq "ServicePrincipal"){
                    $currentRBACServicePrincipal = get-azureadServicePrincipal -filter "ObjectId eq '$AzureDataEntry.ObjectId'"
                    $obj | Add-Member -MemberType NoteProperty -Name ("ServicePrincipalType") -Value  ($currentRBACServicePrincipal).ServicePrincipalType -Force
                    $obj | Add-Member -MemberType NoteProperty -Name ("AccountEnabled") -Value  ($currentRBACServicePrincipal).AccountEnabled -Force
                    $obj | Add-Member -MemberType NoteProperty -Name ("Homepage") -Value  ($currentRBACServicePrincipal).Homepage -Force
                }
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
                $obj | Add-Member -MemberType NoteProperty -Name AccessPoliciesText  -Value "Open the file 7_Inv_AzKeyVaultAccessPolicies-$($keyvault.VaultName).csv" -Force
                $obj
            }
        }
        $keyvaults = Get-AzKeyVault
        Export_KeyVault ($currentsubId) | Export-Csv -Path "$mysubid\7_Inv_AzKeyVault.csv" -NoTypeInformation  -Force | Out-Null
        foreach ($keyvault in $keyvaults){
            Get_Inv_AzKeyVaultAPTxt($keyvault.VaultName) | Export-Csv -Path ("$mysubid\7_Inv_AzKeyVaultAccessPolicies-" + $keyvault.VaultName + ".csv") -NoTypeInformation  -Force | Out-Null
        }
    }


################################################################################################
# 3 - Starting Data Collector
#
    write-host ""
    write-host "************************************ COLLECTING DATA FROM SUBSCRIPTION ************************************ "
    write-host ""
    write-host "Subscription: "  $AzSubscription.Name
    write-host ""


    # 3.1 - Collecting Custom RBAC Definitions
    write-host "1 - Collecting Custom RBAC Definitions"
    Get_Inv_AzData -datasource "Azure" -cmd "Get-AzRoleDefinition -custom" | Export-Csv -Path "$mysubid\1_Inv_AzADRoleDefinition.csv" -NoTypeInformation -Force | Out-Null

    # 3.2 - Collecting Management Groups
    write-host "2 - Collecting Management Groups"
    Get_Inv_AzData -datasource "Azure" -cmd "Get-AzManagementGroup" | Export-Csv -Path "$mysubid\2_Inv_AzManagementGroup.csv" -NoTypeInformation -Force | Out-Null

    # 3.3 - Collecting Subscription Information
    write-host "3 - Collecting Subscription Information"
    Get_Inv_AzData -datasource "Subscription" -cmd "Get-AzSubscription -SubscriptionId $mysubid" | Export-Csv -Path "$mysubid\3_Inv_AzSubscription.csv" -NoTypeInformation  -Force | Out-Null
            
    # 3.4 - Collecting Subscription Resources
    write-host "4 - Collecting Resources Details"
    Get_Inv_AzData -datasource "Subscription" -cmd "Get-AzResource" | Export-Csv -Path "$mysubid\4_Inv_AzAllResources.csv" -NoTypeInformation  -Force | Out-Null
            
    # 3.5 - Collecting RBAC from all Scopes - Management Group, Subscription, Resource Groups, Resources and DataContainers
    write-host "5 - Collecting RBAC from all Scopes - Management Group, Subscription, Resource Groups, Resources and DataContainers"
    Get_Inv_AzData -datasource "Subscription" -cmd "Get-AzRoleAssignment" | Export-Csv -Path "$mysubid\5_Inv_RBAC.csv" -NoTypeInformation  -Force | Out-Null

    # 3.6 - Collecting Users-Assigned Managed Identity
    write-host "6 - Collecting Users-Assigned Managed Identity"
    Get_Inv_AzData -datasource "Subscription" -cmd "Get-AzUserAssignedIdentity" | Export-Csv -Path "$mysubid\6_Inv_UserAssignedIdentity.csv" -NoTypeInformation  -Force | Out-Null
                
    # 3.7- Collecting Subscription Key Vaults and Access Policies
    write-host "7 - Collecting Subscription Key Vaults and Access Policies"
    Get_Inv_AzKeyVault ($mysubid)
            
    write-host ""
    write-host "***********************************************************************"

    Disable-AzContextAutosave  | Out-Null

    dir ".\$mysubid"

    Compress-Archive -Path  "$mysubid\*.*" -CompressionLevel Fastest -DestinationPath "reports-$mysubid.zip" -Force
    $zipfile = get-item -path "reports-$mysubid.zip"

    write-host ""
    write-host "****************** DATA SUCCESSFULLY COLLECTED FROM THE SUBSCRIPTION - DOWNLOAD THE REPORT ZIP FILE ******************"
    Write-host ""
    write-host "Download the inventory report from: " $zipfile.FullName
    write-host ""
    Write-host ""
    write-host "****************** RECOMMENDED NEXT STEPS ******************"
    Write-host "1 - Validate all the reports, avoid making changes in the .csv files"
    Write-host "2 - Migrate the Subscription from the Source to the Destination Azure AD Tenant"
    Write-host "3 - If you will use a different Account to access the Destination Tenant, download all files from your Cloudshell/Cloudrive, and upload to your new one"
    Write-host "4 - Execute the powershell script:   .\import-RBAC.ps1    (This script will use the .csv files saved in the SubscriptionID folder."
    Write-host ""

################################################################################################