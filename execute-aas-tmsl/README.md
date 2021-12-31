# Azure Analysis Service TMSL Script

Azure DevOps pipeline task to execute a custom TMSL script against an Azure Analysis Service or Power BI Premium dataset. 

```yml
- task: execute-aas-tsml@1
  inputs:
    connectedServiceNameSelector: 'connectedServiceNameARM | connectedServiceNamePBI'
    connectedServiceNameARM: 'service connection to AAS' # connectedServiceNameSelector = 'connectedServiceNameARM'
    connectedServiceNamePBI: 'service connection to PBI' #  connectedServiceNameSelector = 'connectedServiceNamePBI'
    aasServer: 'asazure://westeurope.asazure.windows.net/fabrikam | powerbi://api.powerbi.com/v1.0/myorg/dataset'
    loginType: 'inherit | spn | user'
    tenantId: 'tenantId'      # loginType = 'spn'
    appId: 'appId'            # loginType = 'spn'
    appKey: 'appKey'          # loginType = 'spn'
    adminName: "username"     # loginType = 'user'
    adminPassword: "password" # loginType = 'user'
    queryType: "tmsl | inline | folder"
    tmslFile: "query.tmsl" # queryType = 'tmsl'
    tmslScript: "query"    # queryType = 'inline'
    tmslFolder: "folder"   # queryType = 'folder'
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

Script Details:
- **queryType** - Type of how the TMSL script is provided:
    - `tmsl`: a single TMSL file
    - `inline`: provided the TMSL query directly in the task
    - `folder`: a folder with TMSL query files

If **queryType** option is `tmsl`:
- **tmslFile** - The TMSL Script file to be executed

If **queryType** option is `inline`:
- **tmslScript** - TMSL Script to be executed

If **queryType** option is `folder`:
- **tmslFolder** - Folder containing TMSL Script files to be executed

Firewall (only applicable for Azure Analysis service):
- **ipDetectionMethod** - How to determine the IP address that needs to be added to the firewall to enable a connection
    - `autoDetect`: adds the IP address of the agent to the firewall rules
    - `ipAddressRange`: Manual provide the IP Address Range to be added to the firewall rules.
- **deleteFirewallRule** - Delete the firewall rule at the end of the tasks 

If **ipDetectionMethod** option is `ipAddressRange`:
- **startIpAddress** - Start IP address of the range
- **endIpAddress** - End IP address of the range.

## Release notes

**1.5.0**
- Rewritten to Powershell 5.1 (powershell.exe) and ADOMD + TOM
- Support for Power BI Premium XMLA endpoints

**1.2.0**
- Add support for service principal deployments
- Add support for adding firewall rules

**1.1.2**
- New: Folder option added as input
- Bugfix: Replace typo TMSL

**1.1.0**
- New: AAS return messages (error/warning) are used for the tasks logging
- Bugfix: Better logging when exceptions are thrown

**1.0.0**
- Initial public release