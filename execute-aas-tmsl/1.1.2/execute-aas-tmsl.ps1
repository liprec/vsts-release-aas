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

$tmslFile = Get-VstsInput -Name "tsmlFile"     # keep typo due to breaking changes
$tmslScript = Get-VstsInput -Name "tsmlScript" # keep typo due to breaking changes
$tmslFolder = Get-VstsInput -Name "tmslFolder"

$result = 0

switch ($queryType) {
    "tsml" {
        $result = ExecuteScriptFile -Server $aasServer -ScriptFile $tmslFile -Admin $adminName -Password $adminPassword
    }
    "inline" { 
        $result = ExecuteScript -Server $aasServer -Script $tmslScript -Admin $adminName -Password $adminPassword
    }
    "folder" { 
        $tmslFiles = Get-ChildItem -Path $tmslFolder
        foreach ($tmslFile in $tmslFiles) {
            $scriptFile = $tmslFolder + '\' + $tmslFile
            $subResult = ExecuteScriptFile -Server $aasServer -ScriptFile $scriptFile -Admin $adminName -Password $adminPassword
            switch($subResult) {
                1  { if ($result -eq 0) { $result = 1 }}
                -1 { $result = -1 }
            }
        }
    }
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