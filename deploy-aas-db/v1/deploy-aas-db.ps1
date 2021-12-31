[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

#Enums
enum RoleDeployment {
    DeployRolesAndMembers = 0
	DeployRolesRetainMembers = 1
	RetainRoles = 2
}

enum PartitionDeployment {
    DeployPartitions = 0
	RetainPartitions = 1
}

# Get task inputs
$connectionType = Get-VstsInput -Name connectedServiceNameSelector -Require
$serviceName = Get-VstsInput -Name $connectionType -Require
if ($serviceName) {
    $endpoint = Get-VstsEndpoint -Name $serviceName -Require
}

$aasServer = Get-VstsInput -Name "aasServer" -Require
$databaseName = Get-VstsInput -Name "databaseName"
$modelName = Get-VstsInput -Name "modelName"
$loginType = Get-VstsInput -Name "loginType" -Require

$pathToModel = Get-VstsInput -Name "pathToModel" -Require

$sourceSQLServer = Get-VstsInput -Name "sourceSQLServer"
$sourceSQLDatabase = Get-VstsInput -Name "sourceSQLDatabase"
$sourceSQLUsername = Get-VstsInput -Name "sourceSQLUsername"
$sourceSQLPassword = Get-VstsInput -Name "sourceSQLPassword"

$secrets = Get-VstsInput -Name "datasources"

$overwrite = Get-VstsInput -Name "overwrite" -Require -AsBool
$remove = Get-VstsInput -Name "remove" -Require -AsBool

$partitionDeployment = Get-VstsInput -Name "partitionDeployment"
$roleDeployment = Get-VstsInput -Name "roleDeployment"

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

# Loading AMO & TOM
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

if ((-not ($databaseName)) -and ($modelName)) {
    Write-Warning "The 'modelName' option will be deprecated in a future version."
    $databaseName = $modelName
}

if (-not ($databaseName)) {
    throw "Missing required input 'databaseName'"
}

if ($overwrite -ne $true) {
    Write-Warning "The 'overwrite' option will be deprecated in a future version."
}
if ($remove -ne $false) {
    Write-Warning "The 'remove' option will be deprecated in a future version."
}

switch ($partitionDeployment.ToLower()) {
    "retainpartitions" {
        $partitionDeployment = [PartitionDeployment]::RetainPartitions
    }
    default {
        $partitionDeployment = [PartitionDeployment]::DeployPartitions
    }
}
switch ($roleDeployment.ToLower()) {
    "retainroles" {
        $roleDeployment = [RoleDeployment]::RetainRoles
    }
    "deployrolesretainmembers" {
        $roleDeployment = [RoleDeployment]::DeployRolesRetainMembers
    }
    default {
        $roleDeployment = [RoleDeployment]::DeployRolesAndMembers
    }
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

    Write-Verbose "Loading database from '$pathToModel'"
    $sourceDatabase = LoadTabularDatabaseFromFile -path $pathToModel
    Write-Verbose "Loading database '$databaseName' from '$aasServer'"
    $currentDatabase, $server = LoadTabularDatabaseFromServer -server $aasServer -database $databaseName -credential $credential
    
    if (-not $isPBI) {
        if (("" -eq $secrets) -and ("" -ne $sourceSQLServer)) {
            $dataSourceName = $sourceDatabase.Model.DataSources[0].Name
            $secrets = "[{
                'name': '$dataSourceName',
                'authenticationKind': 'UsernamePassword',
                'connectionDetails': {
                    'address': {
                        'server': '$sourceSQLServer',
                        'database': '$sourceSQLDatabase'
                    }
                },
                'credential': {
                    'Username': '$sourceSQLUsername',
                    'Password': '$sourceSQLPassword'
                }
            }]" | ConvertFrom-Json
        }
        foreach ($secret in $secrets) {
            $secretName = $secret.name
            Write-Verbose "Applying datasouce credentials for '$secretName'"
            if ($sourceDatabase.Model.DataSources.ContainsName($secretName)) {
                $currentDatasource = $sourceDatabase.Model.DataSources.Find($secretName)
                if ($currentDatasource.Type -eq [Microsoft.AnalysisServices.Tabular.DataSourceType]::Structured) {
                    $address = $secret.connectionDetails.address
                    $address | Get-Member -MemberType NoteProperty | ForEach-Object { 
                        $key = $_.Name
                        $currentDatasource.connectionDetails.address["$key"] = $address."$key"
                    }
                    $credential = $secret.credential
                    $credential | Get-Member -MemberType NoteProperty | ForEach-Object { 
                        $key = $_.Name
                        $currentDatasource.credential["$key"] = $credential."$key"
                    }
                } else {
                    $connectionString = $currentDatasource.connectionString
                    $connectionStringJSON = ConvertFrom-Json ("{`"" + $connectionString.replace("=", "`":`"").replace(";", "`",`"") + "`"}")
                    $connectionStringJSON."Data Source" = $sourceSQLServer
                    $connectionStringJSON."Initial Catalog" = $sourceSQLDatabase
                    $connectionStringJSON."User ID" = $sourceSQLUsername
                    $connectionStringJSON | Add-Member -name "Password" -Value $sourceSQLPassword -MemberType NoteProperty
                    $currentDatasource.connectionString = ($connectionStringJSON | ConvertTo-Json -Compress).replace("`":`"", "=").replace("`",`"", ";").replace("{`"", "").replace("`"}", "")
                }
            }
        }
    } else {
        if ($null -eq $currentDatabase.Model.DefaultPowerBIDataSourceVersion) {
            $sourceDatabase.Model.DefaultPowerBIDataSourceVersion = "PowerBI_V3"
        } else {
            $sourceDatabase.Model.DefaultPowerBIDataSourceVersion = $currentDatabase.Model.defaultPowerBIDataSourceVersion
        }
    }

    Write-Verbose "Merge database with the following options: $partitionDeployment, $roleDeployment"
    MergeDatabases -sourceDatabase $sourceDatabase -currentDatabase $currentDatabase -databaseName $databaseName -partitionDeployment $partitionDeployment -roleDeployment $roleDeployment
    
    $command = New-Object -TypeName "System.Text.StringBuilder"
    [void]$command.Append([Microsoft.AnalysisServices.Tabular.JsonScripter]::ScriptCreateOrReplace($sourceDatabase, $true))

    try {
        Write-Verbose "Deploying database to $aasserver"
        $result = $server.Execute($command.ToString())
        $return, $msg  = ProcessMessages -result $result

        switch ($return) {
            0 {
                Write-Host "Deploying database ('$databaseName') to '$aasServer' complete"
            }
            1 {
                Write-Host "Deploying database ('$databaseName') to '$aasServer' complete with warnings"
            }
            -1 {
                Write-Error "Deploying database ('$databaseName') to '$aasServer' complete with errors.`n`n$msg"
            }
        }
    } catch {
        $errMsg = $_.exception.message
        throw "Error during deploying the model ($errMsg)"
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