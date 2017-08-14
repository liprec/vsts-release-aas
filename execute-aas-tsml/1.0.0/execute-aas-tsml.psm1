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
        return $result
    } catch {
        throw "Error during deploying the model ($_.exception.message)"
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
        return $result
    } catch {
        throw "Error during deploying the model ($_.exception.message)"
    }
}