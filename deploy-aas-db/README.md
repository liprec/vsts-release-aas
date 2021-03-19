# Azure Analysis Service deployment

Visual Studio Team Service deploy task that will deploy a Azure Analysis Service Model to an existing Azure Analysis Service. 
![](../images/screenshot-2.png)

*NOTE: At this moment the task only supports 1 SQL Server connection*
*Support for more types of connection is in development*

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

Data Source Connection Detailss:
- **Data Source Type** - Type of the first data source defined in the model. SQL is for now the only option.
- **Source Azure SQL Server Name** - The servername of the Azure SQL database server
- **Source Database Name** - The database name
- **Source User Login** - The username used for the connection by the model for trhe connection to the source database
- **Source Password** - The password for the given username

Firewall:
- **Specify Firewall Rules Using** - Auto Detect adds the IP address of the agent to the firewall rules. With the option 'IP Address Range' a start and end IP address of a range needs to be provided
- **Start IP Address** - Start IP address of the range
- **End IP Address** - End IP address of the range.
- **Delete Rule After Task Ends** - Delete the firewall rule at the end of the tasks 

Advanced:
- **Overwrite** - Option to overwrite existing model with the new one.
- **Remove** - Option to remove the old model before deploying a new one.

## Tested configuration

At this moment the following configuration are tested and working:
- Model 1400 and a single SQL Server database as datasource

More configuration will follow. Feel free to contact me for a specific configuration.

## Release notes

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