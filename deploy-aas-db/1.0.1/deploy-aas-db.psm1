<#
// Microsoft.AnalysisServices.Tabular.ProviderDataSource   -- (1200)
- ConnectionsString (Server Database)
- Account
- Password

$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder -argumentlist "Data Source=database;Initial Catalog=catalog;";
$builder["Data Source"];
$builder["Initial Catalog"];

// Microsoft.AnalysisServices.Tabular.StructuredDataSource -- (1400)
- ConnectionDetails
	- ConnectionAddress
		- Server
		- Database
- Credential
	- Username
	- Password
#>

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
            return Get-Content $ModelFile | ConvertFrom-Json
        } catch {
            throw "Not a valid model file (.asdatabase/.bim) provided. ($_.exception.message)"
        }
    } else {
        throw "No model file (.asdatabase/.bim) provided. ($_.exception.message)"
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
function RemoveModel($Server, $ModelName) {
    $removeTsml = '{"delete":{"object":{"database":"existingModel"}}}'
    try {
        $tsml = $removeTsml
        $tsml.delete.object.database = $ModelName
        $result = Invoke-ASCmd -Server $Server -Query $tsml
        return $true
    } catch {
        throw "Error during removing old model. ($_.exception.message)"
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
    $createTsml = '{"create":{"database":{"name":"emptyModel"}}}' | ConvertFrom-Json
    $updateTsml = '{"createOrReplace":{"object":{"database":"existingModel"},"database":{"name":"emptyModel"}}}' | ConvertFrom-Json

    if ($Overwrite) {
        $tsml = $updateTsml
        $tsml.createOrReplace.object.database = $ModelName
        $tsml.createOrReplace.database = $Model
        return ConvertTo-Json $tsml -Depth 100 -Compress
    } else {
        $tsml = $createTsml
        $tsml.create.database = $Model
        return ConvertTo-Json $tsml -Depth 100 -Compress
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
function DeployModel($Server, $Command, $Admin, [SecureString]$Password) {
    try {
        $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Admin,$Password
        $result = Invoke-ASCmd -Server $Server -Query $Command -Credential $credentials
        return $result
    } catch {
        throw "Error during deploying the model ($_.exception.message)"
    }
}