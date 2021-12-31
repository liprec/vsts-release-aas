# Tabular Database Deployment

Azure DevOps pipeline task that will deploy a Tabular Model to an existing Azure Analysis Service or Power BI Premium dataset. 

```yml
- task: deploy-aas-db@1
  inputs:
    connectedServiceNameSelector: 'connectedServiceNameARM | connectedServiceNamePBI'
    connectedServiceNameARM: 'service connection to AAS' # connectedServiceNameSelector = 'connectedServiceNameARM'
    connectedServiceNamePBI: 'service connection to PBI' #  connectedServiceNameSelector = 'connectedServiceNamePBI'
    aasServer: 'asazure://westeurope.asazure.windows.net/fabrikam | powerbi://api.powerbi.com/v1.0/myorg/dataset'
    databaseName: 'database'
    loginType: 'inherit | spn | user'
    tenantId: 'tenantId'      # loginType = 'spn'
    appId: 'appId'            # loginType = 'spn'
    appKey: 'appKey'          # loginType = 'spn'
    adminName: "username"     # loginType = 'user'
    adminPassword: "password" # loginType = 'user'
    pathToModel: './model.bim'
    partitionDeployment: 'retainpartitions | deploypartitions'
    roleDeployment: 'deployrolesandmembers | deployrolesretainmembers | retainroles'
    connectionType: 'none | advanced | sql'
    datasources: | # connectionType = 'advanced'
      [
        {
          "name": "<datasetname>",
          "authenticationKind": "UsernamePassword",
          "connectionDetails": {
            "address": {
              "server": "<sqlserver>",
              "database": "<databasename>"
            }
          },
          "credential": {
            "Username": "<username>",
            "Password": "<password>"
          }
        }
      ]
    sourceSQLServer: 'SQLServer'  # connectionType = 'sql'
    sourceSQLDatabase: 'Database' # connectionType = 'sql'
    sourceSQLUsername: 'Username' # connectionType = 'sql'
    sourceSQLPassword: 'Password' # connectionType = 'sql'
    ipDetectionMethod: "autoDetect | ipAddressRange"
    startIpAddress: "10.0.0.1" # ipDetectionMethod = 'ipAddressRange' 
    endIpAddress: "10.0.0.1"   # ipDetectionMethod = 'ipAddressRange'
    deleteFirewallRule: "true | false"
```

## Parameters

Azure Details:
- **connectedServiceNameSelector** - Type of service connection to use
    - `connectedServiceNameARM`: Use an Azure Resource Manager service connection
    - `connectedServiceNamePBI`: Use a Power Platform service connection, to install: [Power Platform Build Tools](https://marketplace.visualstudio.com/items?itemName=microsoft-IsvExpTools.PowerPlatform-BuildTools)
- **connectedServiceNameARM** - Which Azure RM service connection should be used to connect to the datafactory
- **connectedServiceNamePBI** - Which Power Platform service connection should be used to connect to the datafactory

Analysis Service Details:
- **aasServer** - The name of the Azure Analysis Service server or Power BI Premium connection
- **databaseName** - The name of the Tabular database
- **loginType** - Type of Azure Analysis Service login:
    - `inherit`: inherit the service principal from the service connection
    - `spn`: using a service principal
    - `user`: using a named user 

If **loginType** option is `spn`:
- **tenantId** - Azure ID Tenant ID
- **appId** - Application ID of the Service Principal
- **appKey** - Key/secret of the Application ID

If **loginType** option is `user`: 
- **adminName** - The admin user use to connect to the Azure Analysis Service instance
- **adminPassword** - The password of the admin user use to connect to the Azure Analysis Service instance

Deployment Details:
- **pathToModel** - Location of the '.asdatabase'/'.bim' file
- **partitionDeployment** - Determine how existing partitions are treated during deployment.
    - `deploypartitions`: any existing partitions will be replaces
    - `retainpartitions`: partitions of new tables will be deployed, but partitions for existing tables will be unaffected
- **roleDeployment** - Determine how security roles and role members are treated during deployment.
    - `deployrolesandmembers`: any existing roles and members will be replaced
    - `deployrolesretainmembers`: roles will be deployed along with their members for new roles. Members for existing roles will be retained
    - `retainroles`: the roles and members will not be deployed

Data Source Connection Details (only applicable for Azure Analysis service):
- **connectionType** - Type of the data source configuration:
    - `none`: no additional security configuration is needed
    - `advanced`: addtional security configuration is provided in a JSON array.
    - `sql`: configure the first datasource with the provided servername, databasename, username and password. Support also legacy datasource

If **loginType** option is `advanced`:
- **datasources**: - See sample above on the format of the JSON and model definition in the .asdatabase/.bim file
    ```json
        [
          {
            "name": "<DataSourceName>",
            "authenticationKind": "UsernamePassword",
            "connectionDetails": {
              "address": {
                "server": "<ServerName>",
                "database": "<DatabaseName>"
              }
            },
            "credential": {
              "Username": "<UserName>",
              "Password": "<Password>"
            }
          }
        ]
    ```
     
If **loginType** option is `sql`: 
- **sourceSQLServer** - The servername of the Azure SQL database server
- **sourceSQLDatabase** - The database name
- **sourceSQLUsername** - The username used for the connection by the model for trhe connection to the source database
- **sourceSQLPassword** - The password for the given username

Firewall (only applicable for Azure Analysis service):
- **ipDetectionMethod** - How to determine the IP address that needs to be added to the firewall to enable a connection
    - `autoDetect`: adds the IP address of the agent to the firewall rules
    - `ipAddressRange`: Manual provide the IP Address Range to be added to the firewall rules.
- **deleteFirewallRule** - Delete the firewall rule at the end of the tasks 

If **ipDetectionMethod** option is `ipAddressRange`:
- **startIpAddress** - Start IP address of the range
- **endIpAddress** - End IP address of the range.

# Power BI Premium Data Source Connection Details

Setting datasource credentials via metadata is not possible for Power BI datasets, see: https://docs.microsoft.com/en-us/power-bi/admin/service-premium-connect-tools#setting-data-source-credentials
To set Power BI datasource credentials either vai the UI or via the Power BI REST APIs. 

## Release notes

**1.5.0**
- Rewritten to Powershell 5.1 (powershell.exe) and ADOMD + TOM
- Support for Power BI Premium XMLA endpoints
- Support for multiple datasources
- Support for merging of roles + members and partitions

**1.3.0**
- Support for legacy datasources

**1.2.0**
- Add support for service principal deployments
- Add support for adding firewall rules

**1.1.2**
- Model files are readed with UTF8 encoding

**1.1.0**
- New: AAS return messages (error/warning) are used for the tasks logging
- Bugfix: Better logging when exceptions are thrown

**1.0.0**
- Initial public release