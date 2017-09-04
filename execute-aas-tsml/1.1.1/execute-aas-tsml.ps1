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

$queryType = Get-VstsInput -Name "queryType" -Require

$tsmlFile = Get-VstsInput -Name "tsmlFile"
$tsmlScript = Get-VstsInput -Name "tsmlScript"

$result = 0

switch ($queryType) {
    "tsml" {
        $result = ExecuteScriptFile -Server $aasServer -ScriptFile $tsmlFile -Admin $adminName -Password $adminPassword
    }
    "inline" { 
        $result = ExecuteScript -Server $aasServer -Script $tsmlScript -Admin $adminName -Password $adminPassword
    }
}

switch ($result) {
    0 {
        Write-Host "Execute TSML against '$aasServer' complete"
    }
    1 {
        Write-Host "Execute TSML against '$aasServer' complete with warnings"
    }
    -1 {
        Write-Error "Execute TSML against '$aasServer' complete with errors"
        throw
    }
}