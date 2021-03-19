# Azure Analysis Service TSML Script

This release task can be added to a release pipeline to execute a custom TMSL script against an Azure Analysis Service instance.
![](images/screenshot-3.png)

## Parameters

Azure Details:
- **Azure Connection Type** - Only Azure Resource Manager is supported
- **Azure RM Subscription** - Which Azure Subscription (Service Endpoint) should be used to connect to the datafactory
- **Resource Group** - To which Resource Group is the Azure Analysis Service model deployed

Analysis Service Details:
- **Analysis Service name** - The name of the Azure Analysis Service server
- **Login type** - Type of Azure Analysis Service login: Named user or Service Principal

If **Login type** option is 'Service Principal':
- **Azure AD TenantID** - Azure ID Tenant ID
- **Application ID** - Application ID of the Service Principal
- **Application Key** - Key of the Application ID

If **Login type** option is 'Named User': 
- **Analysis Services Admin** - The admin user use to connect to the Azure Analysis Service instance
- **Analysis Services Admin Password** - The password of the admin user use to connect to the Azure Analysis Service instance

Script Details:
- **Type** - Type of how the TMSL script is provided: TMSL file or inline.
- **TMSL File** - The TMSL Script file to be executed
- **Inline** - TMSL Script to be executed
- **Folder** - Folder containing TMSL Script files to be executed

Firewall:
- **Specify Firewall Rules Using** - Auto Detect adds the IP address of the agent to the firewall rules. With the option 'IP Address Range' a start and end IP address of a range needs to be provided
- **Start IP Address** - Start IP address of the range
- **End IP Address** - End IP address of the range.
- **Delete Rule After Task Ends** - Delete the firewall rule at the end of the tasks 

## Release notes

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