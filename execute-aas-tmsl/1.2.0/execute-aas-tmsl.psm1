<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Server
Parameter description

.PARAMETER Script
Parameter description

.PARAMETER LoginType
Parameter description

.PARAMETER Credentials
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ExecuteScript($Server, $Script, $LoginType, $Credentials) {
    try {
        switch ($LoginType) {
            "user" {
                $result = Invoke-ASCmd -Server $Server -Query $Script -Credential $Credentials
            }
            "spn" {
                $result = Invoke-ASCmd -Server $Server -Query $Script
            }
        }
        return ProcessMessages($result)
    } catch {
        $errMsg = $_.exception.message
        throw "Error during deploying the model ($errMsg)"
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Server
Parameter description

.PARAMETER ScriptFile
Parameter description

.PARAMETER LoginType
Parameter description

.PARAMETER Credentials
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ExecuteScriptFile($Server, $ScriptFile, $LoginType, $Credentials) {
    try {
        switch ($LoginType) {
            "user" {
                $result = Invoke-ASCmd -Server $Server -InputFile $ScriptFile -Credential $Credentials
            }
            "spn" {                
                $result = Invoke-ASCmd -Server $Server -InputFile $ScriptFile
            }
        }
        return ProcessMessages($result)
    } catch {
        $errMsg = $_.exception.message
        throw "Error during deploying the model ($errMsg)"
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER result
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ProcessMessages($result) {
    $return = 0
    $resultXml = [Xml]$result
    $messages = $resultXml.return.root.Messages
    
    foreach($message in $messages) {
        $err = $message.Error
        if ($err) {
            $return = -1
            $errCode = $err.errorcode
            $errMsg = $err.Description
            Write-Host "##vso[task.logissue type=error;]Error: $errMsg (ErrorCode: $errCode)"
        }
        $warn = $message.Warning
        if ($warn) {
            if ($return -eq 0) {
                $return = 1
            }
            $warnCode = $warn.WarningCode
            $warnMsg = $warn.Description
            Write-Host "##vso[task.logissue type=warning;]Warning: $warnMsg (WarnCode: $warnCode)"
        }
    }

    return $return
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Server
Parameter description

.PARAMETER TenantId
Parameter description

.PARAMETER Credentials
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function SetASContext($Server, $TenantId, $Credentials) {
    $environment = $Server.Split('/')[2];
    $result = Add-AzureAnalysisServicesAccount -Credential $Credentials -ServicePrincipal -TenantId $TenantId -RolloutEnvironment $environment
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Server
Parameter description

.PARAMETER Credentials
Parameter description

.PARAMETER AzContext
Parameter description

.PARAMETER IpDetectionMethod
Parameter description

.PARAMETER StartIPAddress
Parameter description

.PARAMETER EndIPAddress
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function AddCurrentServerToASFirewall($Server, $Credentials, $AzContext, $IpDetectionMethod , $StartIPAddress, $EndIPAddress) {
    $qry = "<Discover xmlns='urn:schemas-microsoft-com:xml-analysis'><RequestType>DISCOVER_PROPERTIES</RequestType><Restrictions/><Properties/></Discover>"
    $serverName = $Server.Split('/')[3];
    switch ($IpDetectionMethod) {
        "ipAddressRange" {
            $startIP = $StartIPAddress
            $endIP = $EndIPAddress
        }
        "autoDetect" {
            try {
                if ($Credentials -eq $null) {
                    $result = Invoke-ASCmd -Server $Server -Query $qry
                } else {
                    $result = Invoke-ASCmd -Server $Server -Query $qry -Credential $Credentials
                }
            } catch {
                $errMsg = $_.exception.message
                $start = $errMsg.IndexOf("Client with IP Address '") + 24
                $length = $errMsg.IndexOf("' is not allowed to access the server.") - $start
                if (($start -gt 24) -and ($length -ge 7)) {
                    $startIP = $errMsg.SubString($start, $length)
                    $endIP = $startIP
                } else {
                    Write-Host "##vso[task.logissue type=error;]Error during adding automatic firewall rule ($errMsg)"
                    throw
                }
            }
        }
    }
    try {
        $currentConfig = (Get-AzureRmAnalysisServicesServer -Name $serverName -DefaultProfile $AzContext)[0].FirewallConfig
        $currentFirewallRules = $currentConfig.FirewallRules
        $firewallRule = New-AzureRmAnalysisServicesFirewallRule -FirewallRuleName 'vsts-release-aas-rule' -RangeStart $startIP -RangeEnd $endIP -DefaultProfile $AzContext
        $currentFirewallRules.Add($firewallRule)
        if ($currentConfig.EnablePowerBIService) {
            $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $currentFirewallRules -EnablePowerBIService -DefaultProfile $AzContext
        } else {
            $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $currentFirewallRules
        }
        $result = Set-AzureRmAnalysisServicesServer -Name $serverName -FirewallConfig $firewallConfig -DefaultProfile $AzContext
    } catch {
        $errMsg = $_.exception.message
        Write-Host "##vso[task.logissue type=error;]Error during adding firewall rule ($errMsg)"
        throw
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Server
Parameter description

.PARAMETER AzContext
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function RemoveCurrentServerFromASFirewall($Server, $AzContext) {
    $serverName = $Server.Split('/')[3];
    try {
        $currentConfig = (Get-AzureRmAnalysisServicesServer -Name $serverName -DefaultProfile $AzContext)[0].FirewallConfig
        $newFirewallRules = $currentConfig.FirewallRules
        $newFirewallRules.RemoveAll({ $args[0].FirewallRuleName -eq "vsts-release-aas-rule" })
        if ($currentConfig.EnablePowerBIService) {
            $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $newFirewallRules -EnablePowerBIService -DefaultProfile $AzContext
        } else {
            $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $newFirewallRules
        }
        $result = Set-AzureRmAnalysisServicesServer -Name $serverName -FirewallConfig $firewallConfig -DefaultProfile $AzContext
    } catch {
        $errMsg = $_.exception.message
        Write-Host "##vso[task.logissue type=error;]Error during removing firewall rule ($errMsg)"
        throw
    }
}