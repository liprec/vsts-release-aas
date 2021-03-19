[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

$targetAzurePs = Get-VstsInput -Name targetAzurePs
$customTargetAzurePs = Get-VstsInput -Name customTargetAzurePs

# string constants
$otherVersion = "otherVersion"
$latestVersion = "latestVersion"

if ($targetAzurePs -eq $otherVersion) {
    if ($customTargetAzurePs -eq $null) {
        throw "The Azure PowerShell version '$customTargetAzurePs' specified is not in the correct format. Please check the format. An example of correct format is 1.0.1"
    } else {
        $targetAzurePs = $customTargetAzurePs.Trim()        
    }
}

$pattern = "^[0-9]+\.[0-9]+\.[0-9]+$"
$regex = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList $pattern

if ($targetAzurePs -eq $latestVersion) {
    $targetAzurePs = ""
} elseif (-not($regex.IsMatch($targetAzurePs))) {
    throw "The Azure PowerShell version '$targetAzurePs' specified is not in the correct format. Please check the format. An example of correct format is 1.0.1"
}

$linkedModule = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.ps1', '.psm1')

# Import the logic of the linked module
Import-Module $PSScriptRoot\$linkedModule -Force
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Import-Module $PSScriptRoot\ps_modules\AzureRM.Profile
Import-Module $PSScriptRoot\ps_modules\AzureRM.AnalysisServices
Import-Module $PSScriptRoot\ps_modules\Azure.AnalysisServices
Import-Module $PSScriptRoot\ps_modules\SqlServer

Initialize-Azure -azurePsVersion $targetAzurePs

$azContext = Get-AzureRmContext

$aasServer = Get-VstsInput -Name "aasServer" -Require
$loginType = Get-VstsInput -Name "loginType" -Require

switch ($loginType) {
    "user" {
        $identifier = Get-VstsInput -Name "adminName" -Require
        $secret = ConvertTo-SecureString (Get-VstsInput -Name "adminPassword" -Require) -AsPlainText -Force        
    }
    "spn" {
        $tenantId =  Get-VstsInput -Name "tenantId" -Require
        $identifier = Get-VstsInput -Name "appId" -Require
        $secret = ConvertTo-SecureString (Get-VstsInput -Name "appKey" -Require) -AsPlainText -Force        
    }
}
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $identifier, $secret

$queryType = Get-VstsInput -Name "queryType" -Require

$tmslFile = Get-VstsInput -Name "tsmlFile"     # keep typo due to breaking changes
$tmslScript = Get-VstsInput -Name "tsmlScript" # keep typo due to breaking changes
$tmslFolder = Get-VstsInput -Name "tmslFolder"

$ipDetectionMethod = Get-VstsInput -Name "ipDetectionMethod"
$deleteFirewallRule = Get-VstsInput -Name "deleteFirewallRule"

if ($ipDetectionMethod -eq "ipAddressRange") {
    $startIpAddress = Get-VstsInput -Name "startIpAddress"
    $endIpAddress = Get-VstsInput -Name "endIpAddress"
}

if ($deleteFirewallRule -eq "true") {
    $deleteFirewallRule = $true
} else {
    $deleteFirewallRule = $false
}

$result = 0

# Remove leftover firewall rule
if ($deleteFirewallRule) {
    Write-Verbose "Try to remove leftover firewall rule"
    RemoveCurrentServerFromASFirewall -Server $aasServer -AzContext $azContext -Skip $true
}

# Set firewall and SP context
switch ($loginType) {
    "user" {
        $addedFirewallRule = AddCurrentServerToASFirewall -Server $aasServer -Credentials $credentials -AzContext $azContext -IpDetectionMethod $ipDetectionMethod -StartIPAddress $startIPAddress -EndIPAddress $endIPAddress
    }
    "spn" {
        SetASContext -Server $aasServer -TenantId $tenantId -Credentials $credentials
        $addedFirewallRule = AddCurrentServerToASFirewall -Server $aasServer -AzContext $azContext -IpDetectionMethod $ipDetectionMethod -StartIPAddress $startIPAddress -EndIPAddress $endIPAddress
    }
}

switch ($queryType) {
    "tsml" {
        $result = ExecuteScriptFile -Server $aasServer -ScriptFile $tmslFile -LoginType $loginType -Credentials $credentials
    }
    "inline" { 
        $result = ExecuteScript -Server $aasServer -Script $tmslScript -LoginType $loginType -Credentials $credentials
    }
    "folder" { 
        $tmslFiles = Get-ChildItem -Path $tmslFolder
        foreach ($tmslFile in $tmslFiles) {
            $scriptFile = $tmslFolder + '\' + $tmslFile
            $subResult = ExecuteScriptFile -Server $aasServer -ScriptFile $scriptFile -LoginType $loginType -Credentials $credentials
            switch($subResult) {
                1  { if ($result -eq 0) { $result = 1 }}
                -1 { $result = -1 }
            }
        }
    }
}

if (($deleteFirewallRule) -and ($addedFirewallRule)) {
    RemoveCurrentServerFromASFirewall -Server $aasServer -AzContext $azContext
}

switch ($result) {
    0 {
        Write-Host "Execute TMSL against '$aasServer' complete"
    }
    1 {
        Write-Host "Execute TMSL against '$aasServer' complete with warnings"
    }
    -1 {
        Write-Error "Execute TMSL against '$aasServer' complete with errors"
        throw
    }
}