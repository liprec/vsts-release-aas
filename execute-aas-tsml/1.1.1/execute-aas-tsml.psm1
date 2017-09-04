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
function ExecuteScript($Server, $Script, $Admin, [SecureString]$Password) {
    try {
        $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Admin,$Password
        $result = Invoke-ASCmd -Server $Server -Query $Script -Credential $credentials
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

.PARAMETER Admin
Parameter description

.PARAMETER Password
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ExecuteScriptFile($Server, $ScriptFile, $Admin, [SecureString]$Password) {
    try {
        $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Admin,$Password
        $result = Invoke-ASCmd -Server $Server -InputFile $ScriptFile -Credential $credentials
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