# Private module-scope variables.
$script:jsonContentType = "application/json;charset=utf-8"

# API-Version(s)
$apiVersion = "2014-04-01"
$apiVersionAAS = "2017-08-01"

# Override the DebugPreference.
if ($global:DebugPreference -eq 'Continue') {
    Write-Verbose '$OVERRIDING $global:DebugPreference from ''Continue'' to ''SilentlyContinue''.'
    $global:DebugPreference = 'SilentlyContinue'
}

# Import the loc strings of VstsAzureRestHelpers_.
Import-VstsLocStrings -LiteralPath $PSScriptRoot/ps_modules/VstsAzureRestHelpers_/module.json

Import-Module $PSScriptRoot/ps_modules/TlsHelper_
Add-Tls12InSession

Import-Module $PSScriptRoot\ps_modules\VstsAzureRestHelpers_ -DisableNameChecking

# Get the Azure Resource Id
function Get-AzureRmAnalysisServicesResourceId {
    [CmdletBinding()]
    param([String] [Parameter(Mandatory = $true)] $serverName,
        [Object] [Parameter(Mandatory = $true)] $endpoint,
        [Object] [Parameter(Mandatory = $true)] $accessToken)


    $serverType = "Microsoft.AnalysisServices/servers"
    $subscriptionId = $endpoint.Data.SubscriptionId.ToLower()

    Write-Verbose "Get Resource Groups"
    $method = "GET"
    $uri = "$($endpoint.Url)/subscriptions/$subscriptionId/resources?api-version=$apiVersion"
    $headers = @{Authorization = ("{0} {1}" -f $accessToken.token_type, $accessToken.access_token) }

    do {
        Write-Verbose "Fetching Resources from $uri"
        $ResourceDetails = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -ContentType $script:jsonContentType
        foreach ($resourceDetail in $ResourceDetails.Value) {
            if ($resourceDetail.name -eq $serverName -and $resourceDetail.type -eq $serverType) {
                return $resourceDetail.id
            }
        }
        $uri = $ResourceDetails.nextLink
    } until([string]::IsNullOrEmpty($ResourceDetails.nextLink))

    throw (Get-VstsLocString -Key AZ_NoValidResourceIdFound -ArgumentList $serverName, $serverType, $subscriptionId)
}

function Get-AzureRmAnalysisServicesProperties {
    [CmdletBinding()]
    param([Object] [Parameter(Mandatory = $true)] $endpoint,
        [String] [Parameter(Mandatory = $true)] $serverName)

    Write-Verbose "Getting azure analysis service properties: '$serverName'"
    $accessToken = Get-AzureRMAccessToken $endpoint

    # Fetch Azure Analysis Services resource Id
    $azureResourceId = Get-AzureRmAnalysisServicesResourceId -endpoint $endpoint -serverName $serverName -accessToken $accessToken

    $uri = "$($endpoint.Url)${azureResourceId}?api-version=$apiVersionAAS"
    $headers = @{Authorization = ("{0} {1}" -f $accessToken.token_type, $accessToken.access_token) }

    Write-Verbose "Fetching properties from $uri"
    $aasResponse = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

    if ($null -ne $aasResponse.properties) {
        return $aasResponse.properties
    } else {
        return $null
    }
}

function Set-AzureRmAnalysisServicesFirewallSettings {
    [CmdletBinding()]
    param([Object] [Parameter(Mandatory = $true)] $endpoint,
        [String] [Parameter(Mandatory = $true)] $serverName,
        [String] [Parameter(Mandatory = $true)] $firewallSettings)

    $accessToken = Get-AzureRMAccessToken $endpoint

    # Fetch Azure Analysis Services resource Id
    $azureResourceId = Get-AzureRmAnalysisServicesResourceId -endpoint $endpoint -serverName $serverName -accessToken $accessToken

    $uri = "$($endpoint.Url)${azureResourceId}?api-version=$apiVersionAAS"
    $headers = @{Authorization = ("{0} {1}" -f $accessToken.token_type, $accessToken.access_token) }

    $body = "{
        'properties': {
            'ipV4FirewallSettings': $firewallSettings
        }
    }"

    $null = Invoke-RestMethod -Uri $uri -Method Patch -Headers $headers -Body $body -ContentType $script:jsonContentType
}

function Add-AzureAnalysisServicesFirewallRule {
    [CmdletBinding()]
    param([Object] [Parameter(Mandatory = $true)] $endpoint,
        [String] [Parameter(Mandatory = $true)] $startIPAddress,
        [String] [Parameter(Mandatory = $true)] $endIPAddress,
        [String] [Parameter(Mandatory = $true)] $serverName,
        [String] [Parameter(Mandatory = $true)] $firewallRuleName)
    
    Trace-VstsEnteringInvocation $MyInvocation

    try {
        Write-Verbose "Creating firewall rule '$firewallRuleName'"

        $connectionType = Get-ConnectionType -serviceEndpoint $endpoint

        if (IsAzureRmConnection $connectionType) {
            $aasSettings = Get-AzureRmAnalysisServicesProperties -endpoint $endpoint -serverName $serverName
            $firewallSettings = $aasSettings.ipV4FirewallSettings
            if ($null -ne $firewallSettings) {
                $json = $firewallSettings.firewallRules
                $json += @{
                    "firewallRuleName" = $firewallRuleName
                    "rangeStart" = $startIPAddress
                    "rangeEnd" = $endIPAddress
                }
                $firewallSettings.firewallRules = $json

                Set-AzureRmAnalysisServicesFirewallSettings -endpoint $endpoint -serverName $serverName -firewallSettings ($firewallSettings | ConvertTo-Json)
            }
        }
        else {
            throw (Get-VstsLocString -Key AZ_UnsupportedAuthScheme0 -ArgumentList $connectionType)
        }

        Write-Verbose "Firewall rule '$firewallRuleName' created"
    }
    catch {
        $parsedException = Get-ExceptionMessage($_.Exception)
        if ($parsedException) {
            throw  $parsedException
        }
        throw $_.Exception.ToString()
    }
}

function Remove-AzureAnalysisServicesFirewallRule {
    [CmdletBinding()]
    param([Object] [Parameter(Mandatory = $true)] $endpoint,
        [String] [Parameter(Mandatory = $true)] $serverName,
        [String] [Parameter(Mandatory = $true)] $firewallRuleName)

    Trace-VstsEnteringInvocation $MyInvocation

    try {
        Write-Verbose "Removing firewall rule '$firewallRuleName' on azure analysis services server: $serverName"
        
        $connectionType = Get-ConnectionType -serviceEndpoint $endpoint

        if (IsAzureRmConnection $connectionType) {
            $aasSettings = Get-AzureRmAnalysisServicesProperties -endpoint $endpoint -serverName $serverName
            $firewallSettings = $aasSettings.ipV4FirewallSettings
            if ($null -ne $firewallSettings) {
                $json = @()
                foreach ($firewallRule in $firewallSettings.firewallRules) {
                    if ($firewallRule.firewallRuleName -ne $firewallRuleName) {
                        $json += $firewallRule
                    }
                }

                $firewallSettings.firewallRules = $json

                Set-AzureRmAnalysisServicesFirewallSettings -endpoint $endpoint -serverName $serverName -firewallSettings ($firewallSettings | ConvertTo-Json)
            }
        }
        else {
            throw (Get-VstsLocString -Key AZ_UnsupportedAuthScheme0 -ArgumentList $connectionType)
        }
        
        Write-Verbose "Removed firewall rule '$firewallRuleName' on azure database server: $serverName"
    }
    catch {
        $parsedException = Get-ExceptionMessage($_.Exception)
        if ($parsedException) {
            throw  $parsedException
        }
        throw $_.Exception.ToString()
    }
}

function Get-AzureAnalysisServicesStatus {
    [CmdletBinding()]
    param([Object] [Parameter(Mandatory = $true)] $endpoint,
        [String] [Parameter(Mandatory = $true)] $serverName)

    Trace-VstsEnteringInvocation $MyInvocation

    try {
        Write-Verbose "Getting running status of azure analysis services server: $serverName"
        
        $connectionType = Get-ConnectionType -serviceEndpoint $endpoint

        if (IsAzureRmConnection $connectionType) {
            $aasSettings = Get-AzureRmAnalysisServicesProperties -endpoint $endpoint -serverName $serverName
            if ($null -ne $aasSettings) {
                return $aasSettings.state
            } else {
                return "Unknown"
            }
        }
        else {
            throw (Get-VstsLocString -Key AZ_UnsupportedAuthScheme0 -ArgumentList $connectionType)
        }
    }
    catch {
        $parsedException = Get-ExceptionMessage($_.Exception)
        if ($parsedException) {
            throw  $parsedException
        }
        throw $_.Exception.ToString()
    }
}

# Export only the public function.
Export-ModuleMember -Function Add-AzureAnalysisServicesFirewallRule
Export-ModuleMember -Function Remove-AzureAnalysisServicesFirewallRule
Export-ModuleMember -Function Get-AzureAnalysisServicesStatus