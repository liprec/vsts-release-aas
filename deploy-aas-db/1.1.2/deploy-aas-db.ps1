[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

$linkedModule = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.ps1', '.psm1')

# Import the logic of the linked module
Import-Module $PSScriptRoot\$linkedModule -Force
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Import-Module $PSScriptRoot\ps_modules\SqlServer

Initialize-Azure

$aasServer = Get-VstsInput -Name "aasServer" -Require
$modelName = Get-VstsInput -Name "modelName" -Require
$adminName = Get-VstsInput -Name "adminName" -Require
$adminPassword = ConvertTo-SecureString (Get-VstsInput -Name "adminPassword" -Require) -AsPlainText -Force

$pathToModel = Get-VstsInput -Name "pathToModel" -Require
$connectionType = Get-VstsInput -Name "connectionType" -Require

$sourceSQLServer = Get-VstsInput -Name "sourceSQLServer"
$sourceSQLDatabase = Get-VstsInput -Name "sourceSQLDatabase"
$sourceSQLUsername = Get-VstsInput -Name "sourceSQLUsername"
$sourceSQLPassword = Get-VstsInput -Name "sourceSQLPassword"

$overwrite = Get-VstsInput -Name "overwrite" -Require
$remove = Get-VstsInput -Name "remove" -Require

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

# Read .asdatabase/.bim file as model
$model = ReadModel -ModelFile $pathToModel

# Remove old model
if ($remove) {
    $result = RemoveModel -Server $aasServer -ModelName $modelName
} else {
    $result = $true;
}

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

# Deploy new model
if ($result) {
    $result = DeployModel -Server $aasServer -Command $tsmlCommand -Admin $adminName -Password $adminPassword
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