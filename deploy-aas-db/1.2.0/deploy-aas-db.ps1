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
$modelName = Get-VstsInput -Name "modelName" -Require
$loginType = Get-VstsInput -Name "loginType" -Require

switch ($loginType) {
    "user" {
        Write-Verbose "Retrieving user/password"
        $identifier = Get-VstsInput -Name "adminName" -Require
        $secret = ConvertTo-SecureString (Get-VstsInput -Name "adminPassword" -Require) -AsPlainText -Force        
    }
    "spn" {
        Write-Verbose "Retrieving service principal"
        $tenantId =  Get-VstsInput -Name "tenantId" -Require
        $identifier = Get-VstsInput -Name "appId" -Require
        $secret = ConvertTo-SecureString (Get-VstsInput -Name "appKey" -Require) -AsPlainText -Force        
    }
}
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $identifier, $secret

$pathToModel = Get-VstsInput -Name "pathToModel" -Require
$connectionType = Get-VstsInput -Name "connectionType" -Require

$sourceSQLServer = Get-VstsInput -Name "sourceSQLServer"
$sourceSQLDatabase = Get-VstsInput -Name "sourceSQLDatabase"
$sourceSQLUsername = Get-VstsInput -Name "sourceSQLUsername"
$sourceSQLPassword = Get-VstsInput -Name "sourceSQLPassword"

$overwrite = Get-VstsInput -Name "overwrite" -Require
$remove = Get-VstsInput -Name "remove" -Require

$ipDetectionMethod = Get-VstsInput -Name "ipDetectionMethod"
$deleteFirewallRule = Get-VstsInput -Name "deleteFirewallRule"

if ($ipDetectionMethod -eq "ipAddressRange") {
    $startIpAddress = Get-VstsInput -Name "startIpAddress"
    $endIpAddress = Get-VstsInput -Name "endIpAddress"
}

# This is a hack since the agent passes this as a string.
if ($overwrite -eq "true") {
    $overwrite = $true
} else {
    $overwrite = $false
}

if ($remove -eq "true") {
    $remove = $true
} else {
    $remove = $false
}

if ($deleteFirewallRule -eq "true") {
    $deleteFirewallRule = $true
} else {
    $deleteFirewallRule = $false
}

# Read .asdatabase/.bim file as model
$model = ReadModel -ModelFile $pathToModel

# Rename model name
$model = RenameModel -Model $model -NewName $modelName

# Remove security Ids
$model = RemoveSecurityIds -Model $model

# Alter model JSON with provided username/password
switch ($connectionType) {
    "sql" {
        $model = ApplySQLSecurity -Model $model -Server $sourceSQLServer -Database $sourceSQLDatabase -UserName $sourceSQLUsername -Password $sourceSQLPassword
    }
}

# Create TSML command
$tsmlCommand = PrepareCommand -Model $model -Overwrite $overwrite -ModelName $modelName

# Remove leftover firewall rule
if (($deleteFirewallRule) -and ($addedFirewallRule)) {
    Write-Verbose "Remove leftover firewall rule"
    RemoveCurrentServerFromASFirewall -Server $aasServer -AzContext $azContext
}

# Set firewall and SP context
switch ($loginType) {
    "user" {
        Write-Verbose "Set firewall"
        $addedFirewallRule = AddCurrentServerToASFirewall -Server $aasServer -Credentials $credentials -AzContext $azContext -IpDetectionMethod $ipDetectionMethod -StartIPAddress $startIPAddress -EndIPAddress $endIPAddress
    }
    "spn" {
        Write-Verbose "Set service principal context and firewall"
        SetASContext -Server $aasServer -TenantId $tenantId -Credentials $credentials
        $addedFirewallRule = AddCurrentServerToASFirewall -Server $aasServer -AzContext $azContext -IpDetectionMethod $ipDetectionMethod -StartIPAddress $startIPAddress -EndIPAddress $endIPAddress
    }
}

# Remove old model
if ($remove) {
    Write-Verbose "Remove model"
    $result = RemoveModel -Server $aasServer -ModelName $modelName -LoginType $loginType -Credentials $credentials
} else {
    $result = $true;
}

# Deploy new model
if ($result) {
    Write-Verbose "Deploy model"
    $result = DeployModel -Server $aasServer -Command $tsmlCommand -LoginType $loginType -Credentials $credentials
}

# Remove firewall rule
if (($deleteFirewallRule) -and ($addedFirewallRule)) {
    Write-Verbose "Remove firewall rule"
    RemoveCurrentServerFromASFirewall -Server $aasServer -AzContext $azContext
}

switch ($result) {
    0 {
        Write-Host "Deploy database to '$aasServer' complete"
    }
    1 {
        Write-Host "Deploy database to '$aasServer' complete with warnings"
    }
    -1 {
        Write-Error "Deploy database to '$aasServer' complete with errors"
        throw
    }
}