function LoadDlls {
    [CmdletBinding()]
    param([string] [Parameter(Mandatory = $true)] $path)

    $binaryModuleRoot = Join-Path -Path $path -ChildPath 'assemblies'
    
    $amoDlls = @(   'Microsoft.AnalysisServices.Runtime.Core.dll',
                    
                    'Microsoft.AnalysisServices.Core.dll',
                    'Microsoft.AnalysisServices.dll',
                    'Microsoft.AnalysisServices.Tabular.dll',
                    'Microsoft.AnalysisServices.Tabular.Json.dll')

    $amoDlls | ForEach-Object {
        $binaryPath = Join-Path -Path $binaryModuleRoot -ChildPath "$_"
        
        if (Test-Path -Path $binaryPath) {
            Write-Verbose "Loading assembly: $binaryPath"
            Add-Type -Path $binaryPath
        }
    }
}
function Get-AnalysisServieServer {
    [CmdletBinding()]
    param([string] [Parameter(Mandatory = $true)] $server,
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $credential = [System.Management.Automation.PSCredential]::Empty)
    
    Write-Verbose "Connecting to Analysis Service server: '$server'"

    $pass = $credential.GetNetworkCredential().Password
    $userID = ("{0}@{1}" -f $credential.GetNetworkCredential().UserName, $credential.GetNetworkCredential().Domain)
    $tabularServer = New-Object Microsoft.AnalysisServices.Tabular.Server

    try {
        $tabularServer.Connect("DataSource=${server};User ID=${userID};Password=${pass}")
    } catch {
        $errMsg = $_.exception.message
        throw "Error connecting to tabular service. ($errMsg)"
    }

    return $tabularServer
}

function Get-AgentIpAddress {
    [CmdletBinding()]
    param([string] [Parameter(Mandatory = $true)] $server,
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $credential = [System.Management.Automation.PSCredential]::Empty)

    $pass = $credential.GetNetworkCredential().Password
    $userID = $credential.GetNetworkCredential().UserName
    $tabularServer = New-Object Microsoft.AnalysisServices.Tabular.Server

    try {
        $tabularServer.Connect("DataSource=${server};User ID=${userID};Password=${pass}")
    } catch {
        $errMsg = $_.exception.message
        $start = $errMsg.IndexOf("Client with IP Address '") + 24
        $length = $errMsg.IndexOf("' is not allowed to access the server.") - $start
        if (($start -gt 24) -and ($length -ge 7)) {
            $startIP = $errMsg.SubString($start, $length)
            $endIP = $startIP
        } else {
            throw "Error during detecting agent IP address ($errMsg)"
        }
    }

    return $startIP, $endIP
}

function CheckQuery($tmslScript) {
    if ($tmslScript[0] -eq '<') {
        return $false
    }
    if ($tmslScript[0] -eq '{') {
        return $false
    }
    return $true
}

function ProcessMessages {
    [CmdletBinding()]
    param([Microsoft.AnalysisServices.XmlaResultCollection] [Parameter(Mandatory = $true)] $result)

    $return = 0
    if ($result.ContainsErrors) {
        $return = -1
        for ($i = 0; $i -lt $result.Count; $i++) {
            $messages = $result[$i].Messages
            foreach ($message in $messages) {
                return $return, $message.Description
            }
            
        }
    }

    return $return, ""
}
