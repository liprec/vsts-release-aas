[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

# Get task inputs
$connectionType = Get-VstsInput -Name connectedServiceNameSelector -Require
$serviceName = Get-VstsInput -Name $connectionType -Require
if ($serviceName) {
    $endpoint = Get-VstsEndpoint -Name $serviceName -Require
}

$aasServer = Get-VstsInput -Name "aasServer" -Require
$loginType = Get-VstsInput -Name "loginType" -Require

$queryType = Get-VstsInput -Name "queryType" -Require
if ($queryType -eq "tsml") { 
    $queryType = "tmsl"
}

$tmslFile = Get-VstsInput -Name "tmslFile"
if (-not ($tmslFile)) {
    $tmslFile = Get-VstsInput -Name "tsmlFile"     # keep typo due to breaking changes
}
$tmslScript = Get-VstsInput -Name "tmslScript"
if (-not ($tmslScript)) {
    $tmslScript = Get-VstsInput -Name "tsmlScript" # keep typo due to breaking changes
}
$tmslFolder = Get-VstsInput -Name "tmslFolder"

$ipDetectionMethod = Get-VstsInput -Name "ipDetectionMethod"
$deleteFirewallRule = Get-VstsInput -Name "deleteFirewallRule" -AsBool

if ($ipDetectionMethod -eq "ipAddressRange") {
    $startIpAddress = Get-VstsInput -Name "startIpAddress"
    $endIpAddress = Get-VstsInput -Name "endIpAddress"
}

$linkedModule = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.ps1', '')

# Import the logic of the linked module
Import-Module $PSScriptRoot\ps_modules\VstsAzureRestHelpers_ -DisableNameChecking
Import-Module $PSScriptRoot\VstsAzureRestHelperExtra_ -DisableNameChecking
Import-Module $PSScriptRoot\$linkedModule

# Loading AMO
LoadDlls($PSScriptRoot)

# consts
$firewallRuleName = "vsts-release-aas-rule"

# helper variables
$isPBI = $aasServer.StartsWith("powerbi://")
if ($isPBI) {
    $serverName = $aasServer
} else {
    $serverName = $aasServer.Split('/')[3].Replace(':rw','')
}

switch ($loginType) {
    "user" {
        Write-Verbose "Retrieving user/password"
        $identifier = Get-VstsInput -Name "adminName" -Require
        $secret = ConvertTo-SecureString -String (Get-VstsInput -Name "adminPassword" -Require) -AsPlainText -Force
    }
    "spn" {
        Write-Verbose "Retrieving service principal"
        $identifier = ("app:{0}@{1}" -f (Get-VstsInput -Name "appId" -Require), (Get-VstsInput -Name "tenantId" -Require))
        $secret = ConvertTo-SecureString -String (Get-VstsInput -Name "appKey" -Require) -AsPlainText -Force
    }
    "inherit" {
        Write-Verbose "Using endpoint credentials"
        if ($isPBI) {
            $identifier = ("app:{0}@{1}" -f $endpoint.Auth.parameters.applicationId, $endpoint.Auth.parameters.tenantId)
            $secret = ConvertTo-SecureString -String ($endpoint.Auth.parameters.clientSecret) -AsPlainText -Force
        } else {
            $identifier = ("app:{0}@{1}" -f $endpoint.Auth.parameters.ServicePrincipalId, $endpoint.Auth.parameters.TenantId)
            $secret = ConvertTo-SecureString -String ($endpoint.Auth.Parameters.ServicePrincipalKey) -AsPlainText -Force
        }
    }
}
$credential = New-Object System.Management.Automation.PSCredential($identifier, $secret)

if (-not ($isPBI)) {
    $status = Get-AzureAnalysisServicesStatus -endpoint $endpoint -serverName $serverName
    if ($status -ne "Succeeded") {
        throw "Please make sure that the Azure Analysis Service ('$servername') is running."
    }
}

try {
    if (-not $isPBI) {
        if ($deleteFirewallRule) {
            Write-Verbose "Remove leftover firewall rule"
            Remove-AzureAnalysisServicesFirewallRule -endpoint $endpoint -serverName $serverName -firewallRuleName $firewallRuleName
        }

        if (($null -eq $startIpAddress) -and ($null -eq $endIpAddress)) {   
            Write-Verbose "Get agent IP address"
            $startIpAddress, $endIpAddress = Get-AgentIpAddress -server $aasServer -credential $credential
        }
        
        if (($null -ne $startIpAddress) -and ($null -ne $endIpAddress)) {        
            Write-Verbose "Adding firewall rule"
            Add-AzureAnalysisServicesFirewallRule -endpoint $endpoint -serverName $serverName -startIPAddress $startIpAddress -endIPAddress $endIpAddress -firewallRuleName $firewallRuleName
        }
    }

    $server = Get-AnalysisServieServer -server $aasServer -credential $credential

    $commands = @()
    switch ($queryType) {
        "tmsl" {
            Write-Verbose "Parse TMSL file"
            $fileContent = Get-Content $tmslFile -Encoding UTF8
            $command = ""
            $checkQuery = CheckQuery($fileContent)
            if ($checkQuery) {
                $command += "<Statement>"
            }
            $command += $fileContent
            if ($checkQuery) {
                $command += "</Statement>"
            }
            $commands += $command
        }
        "inline" { 
            Write-Verbose "Parse TMSL inline script"
            $command = ""
            $checkQuery = CheckQuery($tmslScript)
            if ($checkQuery) {
                $command += "<Statement>"
            }
            $command += $tmslScript
            if ($checkQuery) {
                $command += "</Statement>"
            }
            $commands += $command
        }
        "folder" { 
            Write-Verbose "Parse TMSL folder"
            $tmslFiles = Get-ChildItem -Path $tmslFolder
            foreach ($tmslFile in $tmslFiles) {
                $scriptFile = Join-Path -Path $tmslFolder -ChildPath $tmslFile
                $fileContent = Get-Content $scriptFile -Encoding UTF8
                $command = ""
                $checkQuery = CheckQuery($fileContent)
                if ($checkQuery) {
                    $command += "<Statement>"
                }
                $command += $fileContent
                if ($checkQuery) {
                    $command += "</Statement>"
                }
                $commands += $command
            }
        }
    }

    try {
        $result = 0
        $errorMsg = @()
        Write-Verbose "Executing queries at $aasserver"
        foreach ($command in $commands) {
            $subResult = $server.Execute($command.ToString())    
            $return, $msg = ProcessMessages -result $subResult
            switch($return) {
                1  { 
                    if ($result -eq 0) {
                        $result = 1 
                    }
                }
                -1 {
                    $result = -1
                    $errorMsg += $msg
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
                $errorMsg = $errorMsg -join "`n"
                Write-Error "Execute TMSL against '$aasServer' complete with errors.`n`n$errorMsg"
            }
        }
    } catch {
        $errMsg = $_.exception.message
        throw "Error during executing queries ($errMsg)"
    }
} catch {
    $errMsg = $_.exception.message
    if ($errMsg) {
        Write-Error $errMsg
    }
} finally {
    if ($null -ne $server) {
        $server.Disconnect()
    }
    if (-not $isPBI) {
        if (($null -ne $startIpAddress) -and ($deleteFirewallRule)) {
            Write-Verbose "Remove firewall rule"
            Remove-AzureAnalysisServicesFirewallRule -endpoint $endpoint -serverName $serverName -firewallRuleName $firewallRuleName
        }
    }

    Trace-VstsLeavingInvocation $MyInvocation
}
