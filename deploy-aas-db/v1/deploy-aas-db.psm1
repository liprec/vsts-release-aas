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

function LoadDlls {
    [CmdletBinding()]
    param([string] [Parameter(Mandatory = $true)] $path)

    $binaryModuleRoot = Join-Path -Path $path -ChildPath 'assemblies'
    
    $amoDlls = @(   'Microsoft.AnalysisServices.Runtime.Core.dll',
                    'Microsoft.AnalysisServices.Runtime.Windows.dll',
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

function LoadTabularDatabaseFromFile {
    [CmdletBinding()]
    param([string] [Parameter(Mandatory = $true)] $path)

    Write-Verbose "Loading tabular database from file"

    try {
        $sourceFileContent = Get-Content -Path $path -Encoding UTF8 | ConvertFrom-Json
        # Remove memberIds from role memberships
        $roles = $sourceFileContent.Model.Roles
        foreach($role in $roles) {
            if ($role.members) {
                $role.members = @(($role.members | Select-Object -Property * -ExcludeProperty memberId))
            }
        }
        $sourceFileContent = ($sourceFileContent | ConvertTo-Json -Depth 100 -Compress)

        $sourceDatabase = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($sourceFileContent);
        if ($null -eq $sourceDatabase) {
            throw "Not a valid model file."
        }

        return $sourceDatabase
    } catch {
        $errMsg = $_.exception.message
        throw "Not a valid model file. ($errMsg)"
    }
}

function LoadTabularDatabaseFromServer {
    [CmdletBinding()]
    param([string] [Parameter(Mandatory = $true)] $server,
        [String] [Parameter(Mandatory = $true)] $database,
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $credential = [System.Management.Automation.PSCredential]::Empty)
    
    Write-Verbose "Loading tabular database from server"

    $pass = $credential.GetNetworkCredential().Password
    if ($credential.GetNetworkCredential().Domain -ne "") {
        $userID = ("{0}@{1}" -f $credential.GetNetworkCredential().UserName, $credential.GetNetworkCredential().Domain)
    } else {
        $userID = $credential.GetNetworkCredential().UserName
    }
    $tabularServer = New-Object Microsoft.AnalysisServices.Tabular.Server
    
    try {
        $tabularServer.Connect("DataSource=${server};User ID=${userID};Password=${pass}")
    } catch {
        $errMsg = $_.exception.message
        throw "Error connecting to tabular service. ($errMsg)"
    }
    $currentDatabase = $tabularServer.Databases.FindByName($database)

    if ($null -eq $currentDatabase) {
        $emptyDatabase = "{""name"":""${database}"",""id"":""${database}""}"
        $currentDatabase = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($emptyDatabase);
    }

    return ($currentDatabase, $tabularServer)
}

function MergeDatabases {
    [CmdletBinding()]
    param([Microsoft.AnalysisServices.Tabular.Database] [Parameter(Mandatory = $true)] $sourceDatabase,
        [Microsoft.AnalysisServices.Tabular.Database] [Parameter(Mandatory = $true)] $currentDatabase,
        [string] [Parameter(Mandatory = $true)] $databaseName,
        [PartitionDeployment] [Parameter(Mandatory = $true)] $partitionDeployment,
        [RoleDeployment] [Parameter(Mandatory = $true)] $roleDeployment)

    $sourceDatabase.Name = $databaseName
    $sourceDatabase.ID = $databaseName

    if ($partitionDeployment -ne [PartitionDeployment]::DeployPartitions) {
        Write-Verbose "Copying target partitions to source"
        foreach ($table in $currentDatabase.Model.Tables) {
            $tableName = $table.Name
            if (!$sourceDatabase.Model.Tables.ContainsName($table.Name)) {
                Write-Verbose "Skipping table: '${tableName}'"
                continue
            }
            $currentTable = $sourceDatabase.Model.Tables.Find($table.Name)
            if ($currentTable.Partitions.Where({ $_.SourceType -eq [Microsoft.AnalysisServices.Tabular.PartitionSourceType]::Calculated }).Count -gt 0) {
                Write-Verbose "Skipping partitions of table: '${tableName}'"
                continue
            }
            $currentTable.Partitions.Clear()
            foreach ($partition in $table.Partitions) {
                $pratitionName = $partition.Name
                Write-Verbose "Copying partition '${pratitionName}' of table: '${tableName}'"
                $newPartition = $partition.Clone()
                $currentTable.Partitions.Add($newPartition)
            }
        }
    } else {
        Write-Verbose "Overwriting target partitions"
    }

    if ($roleDeployment -eq [RoleDeployment]::DeployRolesAndMembers) {
        Write-Verbose "Overwriting target roles and members"
    } elseif ($roleDeployment -eq [RoleDeployment]::DeployRolesRetainMembers) {
        # [RoleDeployment]::DeployRolesRetainMembers
        Write-Verbose "Copying target role memberships to source"
        foreach ($role in $currentDatabase.Model.Roles) {
            $roleName = $role.Name
            if (!$sourceDatabase.Model.Roles.ContainsName($role.Name)) {
                Write-Verbose "Skipping role: '${roleName}'"
                continue
            }
            $currentRole = $sourceDatabase.Model.Roles.Find($role.Name)
            $currentRole.Members.Clear()
            foreach ($member in $role.Members) {
                $memberName = $member.Name
                Write-Verbose "Copying member '${memberName}' of role: '${roleName}'"
                $newMember = $member.Clone()
                $newMember.MemberID = $null
                $currentRole.Members.Add($newMember)
            }
        }
    } elseif ($roleDeployment -eq [RoleDeployment]::RetainRoles) {
        Write-Verbose "Copying target roles to source"
        $sourceDatabase.Model.Roles.Clear()
        foreach ($role in $currentDatabase.Model.Roles) {
            $roleName = $role.Name
            Write-Verbose "Copying role: '${roleName}'"
            $newRole = $role.Clone()
            $sourceDatabase.Model.Roles.Add($newRole)
        }
    }
}


function Get-AgentIpAddress {
    [CmdletBinding()]
    param([string] [Parameter(Mandatory = $true)] $server,
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $credential = [System.Management.Automation.PSCredential]::Empty)

    $pass = $credential.GetNetworkCredential().Password
    if ($credential.GetNetworkCredential().Domain -ne "") {
        $userID = ("{0}@{1}" -f $credential.GetNetworkCredential().UserName, $credential.GetNetworkCredential().Domain)
    } else {
        $userID = $credential.GetNetworkCredential().UserName
    }
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
