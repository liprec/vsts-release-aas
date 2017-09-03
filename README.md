[![Build Status](https://ci.appveyor.com/api/projects/status/github/liprec/vsts-release-aas?branch=master&svg=true)](https://ci.appveyor.com/project/liprec/vsts-release-aas)

# Azure Analysis Service

This extension adds release tasks related to Azure Analysis Service to Visual Studio Team Service.

## Azure Analysis Service Deployment

Visual Studio Team Service deploy task that will deploy a Tabular model to an existing Azure Analysis Service instance. Also option to change the connected source datasource during release.
![](images/screenshot-2.png)

At this moment the following configuration are tested and working:
- Model 1400 and a single SQL Server database as datasource

More configuration will follow. Feel free to contact me for a specific configuration.

[More information](deploy-aas-db/README.md)

## Azure Analysis Service TSML Script

This release task can be added to a release pipeline to execute a custom TSML script against an Azure Analysis Service instance.
![](images/screenshot-3.png)

[More information](execute-aas-tsml/README.md)

## Release notes

**1.1.0**
- New: AAS return messages (error/warning) are used for the tasks logging
- Bugfix: Better logging when exceptions are thrown

**1.0.1**
- Initial public release