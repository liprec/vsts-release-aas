[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

$linkedModule = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.ps1', '.psm1')

# Import the logic of the linked module
Import-Module $PSScriptRoot\$linkedModule -Force
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Import-Module $PSScriptRoot\ps_modules\AzureRM.Profile
Import-Module $PSScriptRoot\ps_modules\AzureRM.AnalysisServices
Import-Module $PSScriptRoot\ps_modules\Azure.AnalysisServices
Import-Module $PSScriptRoot\ps_modules\SqlServer

Initialize-Azure
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

switch ($loginType) {
    "user" {
        AddCurrentServerToASFirewall -Server $aasServer -Credentials $credentials -AzContext $azContext -IpDetectionMethod $ipDetectionMethod -StartIPAddress $startIPAddress -EndIPAddress $endIPAddress
    }
    "spn" {
        SetASContext -Server $aasServer -TenantId $tenantId -Credentials $credentials
        AddCurrentServerToASFirewall -Server $aasServer -AzContext $azContext -IpDetectionMethod $ipDetectionMethod -StartIPAddress $startIPAddress -EndIPAddress $endIPAddress
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

if ($deleteFirewallRule) {
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