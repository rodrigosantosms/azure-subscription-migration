# Directory change for Azure Subscription

## Who must read this document
Any organization or individual planning to migrate an Azure Subscription between Azure AD Tenants.

## Background
Changing an Azure Subscription between Tenants can be very complex and critical task, and must be executed with caution.
This project focuses on exporting an inventory of resources, configurations, settings, and RBAC configuration for backup and report purposes. 
Because resource types in Azure are constantly evolving and new are added on a fast pace, the project cannot catch all and everything.
However we are doing our best to update content based on real customer experiences.
([official documentation](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-subscriptions-associated-directory))

## Project structure
In order to simplify requirements, this project is inteted to be run in a CloudShell (PowerShell) in the context of a user 
who has permissions Owner or Contributor roles in the Source Tenant and SUbscription. There are a lot of benefits of using the Azure CloudShell - including that all prerequisits and modules are already installed and the user is signed-in.

The project is structed as follows:

```
 + project root
 |--export-RBAC.ps1
 |--import-RBAC.ps1
 |--readme.md
 ```

## What each script will do

**export-RBAC.ps1**
- It will collect and export to .csv files the following:
  * Custom RBAC Definitions
  * Management Groups
  * Subscription Information
  * Subscription Resources
  * ALL RBAC Assignment (including Management Groups, Subscriptions, Resource Groups, Resources, Storage Account Containers, etc)
  * Users-Assigned Managed Identity

**import-RBAC.ps1**
- It will reassign all RBAC after migrating your Subscription to the Target Tenant.


## How to use these scripts?

## Step 1 - Exporting the current RBAC configuration and full inventory 

All that you have to do is:

1 - Open the Azure Portal, open the Cloud Shell and Select "PowerShell" mode
2 - Execute the following commands:

```
cd $home/clouddrive
$file1 = "https://aka.ms/azsubmig"
Invoke-WebRequest -Uri $file1 -outfile "export-RBAC.ps1"
./export-RBAC.ps1
```

### Where the script will save the data?
All data is saved in .csv format in a folder in your $home/CloudDrive folder. Folder name is your SubscriptionID. 


## Step2 - Restoring RBAC permissions

After you have exported the RBAC state and full inventory, and migrated your subscription to the target Tenant, it is time to restore the RBAC assignments.

1 - Open the Azure Portal, open the Cloud Shell and Select "PowerShell" mode
2 - Execute the following commands:
```
cd $home/clouddrive
$file1 = "https://aka.ms/azsubmig"
Invoke-WebRequest -Uri $file1 -outfile "export-RBAC.ps1"
./export-RBAC.ps1
```
