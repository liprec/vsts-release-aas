<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER ModelFile
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ReadModel($ModelFile) {
    if ([string]::IsNullOrWhitespace($ModelFile) -eq $false `
                -and $ModelFile -ne $env:SYSTEM_DEFAULTWORKINGDIRECTORY `
                -and $ModelFile -ne [String]::Concat($env:SYSTEM_DEFAULTWORKINGDIRECTORY, "\")) {
        try {
            return Get-Content $ModelFile -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $errMsg = $_.exception.message
            throw "Not a valid model file (.asdatabase/.bim) provided. ($errMsg)"
        }
    } else {
        $errMsg = $_.exception.message
        throw "No model file (.asdatabase/.bim) provided. ($errMsg)"
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Model
Parameter description

.PARAMETER NewName
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function RenameModel($Model, $NewName) {
    if ([string]::IsNullOrWhitespace($NewName) -eq $false `
        -and [string]::IsNullOrEmpty($NewName) -eq $false) {
        $Model.name = $NewName
        $Model = ($Model | Select-Object -Property * -ExcludeProperty id) # Remove not needed Id property
        return $Model
    } else {
        return $Model
    }
}

<#
.SYNOPSIS

.DESCRIPTION
Long description

.PARAMETER Model
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function RemoveSecurityIds($Model) {
    $roles = $Model.model.roles
    foreach($role in $roles) {
        if ($role.members) {
            $role.members = @(($role.members | Select-Object -Property * -ExcludeProperty memberId))
        }
    }
    return $Model
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Model
Parameter description

.PARAMETER Server
Parameter description

.PARAMETER Database
Parameter description

.PARAMETER UserName
Parameter description

.PARAMETER Password
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ApplySQLSecurity($Model, $Server, $Database, $UserName, $Password) {
    $connectionDetails = ConvertFrom-Json '{"connectionDetails":{"protocol":"tds","address":{"server":"server","database":"database"}}}'
    $credential = ConvertFrom-Json '{"credential":{"AuthenticationKind":"UsernamePassword","kind":"kind","path":"server","Username":"user","Password":"pass","EncryptConnection":true}}'
    $dataSources = $Model.model.dataSources
    foreach($dataSource in $dataSources) {
        if ($dataSource.type) {
            $connectionDetails.connectionDetails.protocol = $dataSource.connectionDetails.protocol
            $connectionDetails.connectionDetails.address.server = $Server
            $connectionDetails.connectionDetails.address.database = $Database
            $dataSource.connectionDetails = $connectionDetails.connectionDetails
            $credential.credential.kind = $dataSource.credential.kind
            $credential.credential.EncryptConnection = $dataSource.credential.EncryptConnection
            $credential.credential.AuthenticationKind = $dataSource.credential.AuthenticationKind
            $credential.credential.path = $Server
            $credential.credential.Username = $UserName
            $credential.credential.Password = $Password
            $dataSource.credential = $credential.credential
        }
    }
    return $Model
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Server
Parameter description

.PARAMETER ModelName
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function RemoveModel($Server, $ModelName, $LoginType, $Credentials) {
    $removeTmsl = '{"delete":{"object":{"database":"existingModel"}}}' | ConvertFrom-Json
    try {
        $tmsl = $removeTmsl
        $tmsl.delete.object.database = $ModelName
        $tmslRemove = ConvertTo-Json $tmsl -Depth 100 -Compress
        switch ($LoginType) {
            "user" {
                $result = Invoke-ASCmd -Server $Server -Query $tmslRemove -Credential $Credentials
            }
            "spn" {
                $result = Invoke-ASCmd -Server $Server -Query $tmslRemove
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

.PARAMETER Model
Parameter description

.PARAMETER Overwrite
Parameter description

.PARAMETER ModelName
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function PrepareCommand($Model, $Overwrite, $ModelName) {
    $createTmsl = '{"create":{"database":{"name":"emptyModel"}}}' | ConvertFrom-Json
    $updateTmsl = '{"createOrReplace":{"object":{"database":"existingModel"},"database":{"name":"emptyModel"}}}' | ConvertFrom-Json

    if ($Overwrite) {
        $tmsl = $updateTmsl
        $tmsl.createOrReplace.object.database = $ModelName
        $tmsl.createOrReplace.database = $Model
        return ConvertTo-Json $tmsl -Depth 100 -Compress
    } else {
        $tmsl = $createTmsl
        $tmsl.create.database = $Model
        return ConvertTo-Json $tmsl -Depth 100 -Compress
    }
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Server
Parameter description

.PARAMETER Command
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function DeployModel($Server, $Command, $LoginType, $Credentials) {
    try {
        switch ($LoginType) {
            "user" {
                $result = Invoke-ASCmd -Server $Server -Query $Command -Credential $Credentials
            }
            "spn" {
                $result = Invoke-ASCmd -Server $Server -Query $Command
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

.PARAMETER Command
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
    $serverName = $Server.Split('/')[3].Replace(':rw','');
    $added = $false
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
    if (($null -ne $startIP) -and ($null -ne $endIP)) {
        try {
            $added = $true
            $currentConfig = (Get-AzureRmAnalysisServicesServer -Name $serverName -DefaultProfile $AzContext)[0].FirewallConfig
            $currentFirewallRules = $currentConfig.FirewallRules
            $firewallRule = New-AzureRmAnalysisServicesFirewallRule -FirewallRuleName 'vsts-release-aas-rule' -RangeStart $startIP -RangeEnd $endIP -DefaultProfile $AzContext
            $currentFirewallRules.Add($firewallRule)
            if ($currentConfig.EnablePowerBIService) {
                $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $currentFirewallRules -EnablePowerBIService -DefaultProfile $AzContext
            } else {
                $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $currentFirewallRules -DefaultProfile $AzContext
            }
            $result = Set-AzureRmAnalysisServicesServer -Name $serverName -FirewallConfig $firewallConfig -DefaultProfile $AzContext
        } catch {
            $errMsg = $_.exception.message
            Write-Host "##vso[task.logissue type=error;]Error during adding firewall rule ($errMsg)"
            throw
        }
    }

    return $added
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
function RemoveCurrentServerFromASFirewall($Server, $AzContext, $Skip) {
    $serverName = $Server.Split('/')[3].Replace(':rw','');
    try {
        $currentConfig = (Get-AzureRmAnalysisServicesServer -Name $serverName -DefaultProfile $AzContext)[0].FirewallConfig
        $newFirewallRules = $currentConfig.FirewallRules
        $newFirewallRules.RemoveAll({ $args[0].FirewallRuleName -eq "vsts-release-aas-rule" })
        if ($currentConfig.EnablePowerBIService) {
            $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $newFirewallRules -EnablePowerBIService -DefaultProfile $AzContext
        } else {
            $firewallConfig = New-AzureRmAnalysisServicesFirewallConfig -FirewallRule $newFirewallRules -DefaultProfile $AzContext
        }
        $result = Set-AzureRmAnalysisServicesServer -Name $serverName -FirewallConfig $firewallConfig -DefaultProfile $AzContext
    } catch {
        if ($Skip -ne $true) {
            $errMsg = $_.exception.message
            Write-Host "##vso[task.logissue type=error;]Error during removing firewall rule ($errMsg)"
            throw
        }
    }
}
