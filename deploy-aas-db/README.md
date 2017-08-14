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
- **Analysis Services Admin** - The admin user use to connect to the Azure Analysis Service instance
- **Analysis Services Admin Password** - The password of the admin user use to connect to the Azure Analysis Service instance

Data Source Connection Detailss:
- **Data Source Type** - Type of the first data source defined in the model. SQL is for now the only option.
- **Source Azure SQL Server Name** - The servername of the Azure SQL database server
- **Source Database Name** - The database name
- **Source User Login** - The username used for the connection by the model for trhe connection to the source database
- **Source Password** - The password for the given username

Advanced:
- **Overwrite** - Option to overwrite existing model with the new one.
- **Remove** - Option to remove the old model before deploying a new one.

## Tested configuration

At this moment the following configuration are tested and working:
- Model 1400 and a single SQL Server database as datasource

More configuration will follow. Feel free to contact me for a specific configuration.

## Release notes

**1.0.0**
- Initial public release