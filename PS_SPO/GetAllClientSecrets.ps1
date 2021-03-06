<# 
Code Example Disclaimer:
Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment. 
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED 'AS IS'-This is intended as a sample of how code might be written 
for a similar purpose and you will need to make changes to fit to your requirements. 
-This code has not been tested. This code is also not to be considered best practices or prescriptive guidance.
-No debugging or error handling has been implemented.
-It is highly recommended that you FULLY understand what this code is doing  and use this code at your own risk.

Need Azure Active Directory Powershell Module
https://support.office.com/en-us/article/Connect-PowerShell-to-Office-365-services-06a743bb-ceb6-49a9-a61d-db4ffdf54fa6
Also Need Online Sign in assistant
https://www.microsoft.com/en-us/download/details.aspx?id=39267

Use Case:  Low Trust Provider Hosted Apps or Add-ins require Client Secret, which are valid for either 1 or 3 years. Once they Expire, 
the apps will stop working and you need to generate new once for that particular appId or clientId. This PowerShell Script connects 
to Azure Active Directory and dumps all the un expired and expired/about to expire secrets and it keys. 
The appId and the secret together is sensitive information so please keep them secure and do not share clientsecret to any unauthorized users. 

Usage:
Open Windows Powershell in administrative mode and cd to the location where you save this script.
Run the script. It will prompt for your onmicrosoft account and password. Once authentication succeeds 
It will create 2 files in the same folder as below:-
Secret_Valid.txt: All unexpired and valid secrets are in Secret_Valid.
Secret_Expiring.txt: All expired and about to be expiring (10 days from the day you run this script).

#> 



Import-module MSOnline -ErrorAction Continue
$msolcred = get-credential
connect-msolservice -credential $msolcred

# List secrets that are expired or about to expire within 10 days from Today.
$dayLimit = 10;
$currentDate = (Get-Date).ToShortDateString();

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath

$allExpiredKeys = @()
$allValidKeys = @()


$applist = Get-MsolServicePrincipal -all  | Where-Object -FilterScript { ($_.DisplayName -notlike "*Microsoft*") -and ($_.DisplayName -notlike "autohost*") -and  ($_.ServicePrincipalNames -notlike "*localhost*")}

foreach ($appentry in $applist)
{
    $principalId = $appentry.AppPrincipalId.Guid
    $principalName = $appentry.DisplayName
    
    $clientSecrets = Get-MsolServicePrincipalCredential -AppPrincipalId $principalId -ReturnKeyValues $false | Where-Object { ($_.Type -ne "Other") -and ($_.Type -ne "Asymmetric") }
    
    if ($clientSecrets -ne $null)
    {
        foreach ($secret in $clientSecrets)
        {
            $clientSecret = "" | Select "PrincipalName","PrincipalID","KeyId","SecretType","StartDate","EndDate","Usage"
            $clientSecret.PrincipalName = $principalName
            $clientSecret.PrincipalID = $principalId
            $clientSecret.KeyId = $secret.KeyId
            $clientSecret.SecretType = $secret.Type
            $clientSecret.StartDate = $secret.StartDate
            $clientSecret.EndDate = $secret.EndDate
            $clientSecret.Usage = $secret.Usage
            $keyEndDate = $secret.EndDate.ToShortDateString();
            $dayDiff = New-TimeSpan -Start $currentDate -End $keyEndDate

            if($dayDiff.Days -le $dayLimit)
            {
                $allExpiredKeys += $clientSecret
            }
            else
            {
                $allValidKeys += $clientSecret
            }

        }
    }


} 

$allValidKeys | Out-File "$ScriptDir\Secret_Valid.txt"
$allExpiredKeys | Out-File "$ScriptDir\Secret_Expiring.txt"

Write-Host "Done."
