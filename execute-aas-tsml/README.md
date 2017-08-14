# Azure Analysis Service TSML Script

This release task can be added to a release pipeline to execute a custom TSML script against an Azure Analysis Service instance.
![](images/screenshot-3.png)

## Parameters

Azure Details:
- **Azure Connection Type** - Only Azure Resource Manager is supported
- **Azure RM Subscription** - Which Azure Subscription (Service Endpoint) should be used to connect to the datafactory
- **Resource Group** - To which Resource Group is the Azure Analysis Service model deployed


Analysis Service Details:
- **Analysis Service name** - The name of the Azure Analysis Service server
- **Analysis Services Admin** - The admin user use to connect to the Azure Analysis Service instance
- **Analysis Services Admin Password** - The password of the admin user use to connect to the Azure Analysis Service instance

Script Details:
- **Type** - Type of how the TSML script is provided: TSML file or inline.
- **TSML File** - The TSML Script file to be executed
- **Inline** - TSML Script to be executed