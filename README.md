# Azure Analysis Service

This extension adds Azure DevOps pipeline tasks for Azure Analysis Service or Power BI Premium

## Build status

| Branch  | status                                                                                                                                                                                                                           |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Main    | [![Build and test](https://github.com/liprec/vsts-release-aas/workflows/Build%20and%20test/badge.svg?branch=main)](https://github.com/liprec/vsts-release-aas/actions?query=branch%3Amain+workflow%3A%22Build+and+test%22)       |
| Develop | [![Build and test](https://github.com/liprec/vsts-release-aas/workflows/Build%20and%20test/badge.svg?branch=develop)](https://github.com/liprec/vsts-release-aas/actions?query=branch%3Adevelop+workflow%3A%22Build+and+test%22) |

## 

See https://azurebi-docs.jppp.org/vsts-extensions/azure-analysis-service.html for the complete documentation.

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

**1.1.3**
- New: Execute TMSL Script can now have a folder with scripts as input
- Bugfix: Corrected typo TMSL

**1.1.0**
- New: AAS return messages (error/warning) are used for the tasks logging
- Bugfix: Better logging when exceptions are thrown

**1.0.1**
- Initial public release