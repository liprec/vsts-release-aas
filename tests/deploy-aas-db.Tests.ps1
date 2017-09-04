# Set the $version to the 'to be tested' version
$version = '1.1.1'

# Dynamic set the $testModule to the module file linked to the current test file
$linkedModule = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.ps1', '')
# Import the logic of the linked module
Import-Module $PSScriptRoot\..\$linkedModule\$version\$linkedModule.psm1 -Force

Describe "Module: $linkedModule" {
    Context "function: ReadModel" {
        InModuleScope $linkedModule {
            # Model definition
            $jsonModel = '{"name":"TabularModel"}' | ConvertFrom-Json
            # Mock functions
            Mock Get-Content { return '{"name":"TabularModel"}' }

            Context "Correct model file" {
                $model = ReadModel -ModelFile 'C:\\modelfile.asdatabase'
                It "read Model file correct" {
                    ($model | ConvertTo-Json)  | Should Be ($jsonModel | ConvertTo-Json)
                }

                It "Mock Functions correct" {
                    Assert-MockCalled Get-Content -Times 1
                }

                It "complete succesfully" {
                    { $model } | Should Not Throw
                }
            }

            Context "Correct model file; spaces in path/name" {
                $model = ReadModel -ModelFile 'C:\\model file.asdatabase'
                It "read Model file correct" {
                    ($model | ConvertTo-Json)  | Should Be ($jsonModel | ConvertTo-Json)
                }

                It "Mock Functions correct" {
                    Assert-MockCalled Get-Content -Times 1
                }

                It "complete succesfully" {
                    { $model } | Should Not Throw
                }
            }

            Context "Empty model file" {
                try {
                    $model = ReadModel -ModelFile ''
                } catch {}
            
                It "do not return a Model file" {
                    $model | Should Be $null
                }

                It "Mock Functions correct" {
                    Assert-MockCalled Get-Content -Times 0
                }

                It "throw exception" {
                    { $model = ReadModel -ModelFile '' } | Should Throw "No model file (.asdatabase/.bim) provided."
                }
            }

            Context "No json Model file" {
                Mock Get-Content { return 'TextFile' }
                
                It "throw exception" {
                    { $model = ReadModel -ModelFile 'C:\\somefile' } | Should Throw "Not a valid model file (.asdatabase/.bim) provided."
                }
            }
        }
    }

    Context "function: RenameModel" {
        InModuleScope $linkedModule {
            Context "NewName provided" {
                # Model definitions
                $jsonModel = '{"name":"TabularModel"}' | ConvertFrom-Json
                $model = RenameModel -Model $jsonModel -NewName "SampleModel"
                It "Should rename model name" {
                    $model.name | Should Be "SampleModel"
                }
            }

            Context "Empty string provided" {
                # Model definitions
                $jsonModel = '{"name":"TabularModel"}' | ConvertFrom-Json
                $model = RenameModel -Model $jsonModel -NewName ""
                It "Should not rename model name" {
                    $model.name | Should Be "TabularModel"
                }
            }
                         
            Context "Null string provided" {
                # Model definitions
                $jsonModel = '{"name":"TabularModel"}' | ConvertFrom-Json
                $model = RenameModel -Model $jsonModel -NewName $null
                It "Should not rename model name" {
                    $model.name | Should Be "TabularModel"
                }
            }
        }
    }

    Context "function RemoveSecurityIds" {
        InModuleScope $linkedModule {
            Context "Remove memberIds from roles" {
                $jsonModel = '{"name":"TabularModel","model":{"roles":[{"name":"Role","modelPermission":"read","members":[{"memberName":"sample@mail","memberId":"sample@mail","identityProvider":"AzureAD"}]}]}}' | ConvertFrom-Json
                $model = RemoveSecurityIds -Model $jsonModel

                It "be removed" {
                    $model.model.roles[0].members[0].memberId | Should Be $null
                }
            }
        }
    }

    Context "function: ApplySQLSecurity" {
        InModuleScope $linkedModule {
            
        }
    }

    Context "function: RemoveModel" {
        InModuleScope $linkedModule {

        }
    }

    Context "function: PrepareCommand" {
        InModuleScope $linkedModule {
            # Model definition
            $jsonModel = '{"name":"TabularModel"}' | ConvertFrom-Json
            $jsonRenamedModel = '{"name":"SampleModel"}' | ConvertFrom-Json
            $tsmlCreateCommand = '{"create":{"database":{"name":"TabularModel"}}}'
            $tsmlCreateOrUpdateCommand = '{"createOrReplace":{"object":{"database":"SampleModel"},"database":{"name":"SampleModel"}}}'

            Context "Correct model file, without overwrite" {
                $tsml = PrepareCommand -Model $jsonModel -Overwrite $false -ModelName $null
                It "read Model file correct" {
                    $tsml | Should Be $tsmlCreateCommand
                }
            }

            Context "Correct model file, with overwrite" {
                $tsml = PrepareCommand -Model $jsonRenamedModel -Overwrite $true -ModelName "SampleModel"
                It "read Model file correct" {
                    $tsml | Should Be $tsmlCreateOrUpdateCommand
                }
            }

        }
    }

    Context "function: DeployModel" {
        InModuleScope $linkedModule {
            # Mock functions
            Mock Write-Host {}
            Mock New-Object {}
            Mock Invoke-ASCmd { return $successResult } -ParameterFilter { $Command -eq '{Correct}' }
            Mock Invoke-ASCmd { return $errorResult } -ParameterFilter { $Command -eq '{Error}' }
            Mock Invoke-ASCmd { throw 'Error: missing server variable' } -ParameterFilter { $Server -eq '' }
            Mock Invoke-ASCmd { throw 'Error: missing admin variable' } -ParameterFilter { $Admin -eq '' }
            
            $Server = 'localhost'
            $Command = '{Correct}'
            $Admin = 'admin@localhost'
            $Password = ConvertTo-SecureString 'Password' -AsPlainText -Force

            $successResult = '
            <return xmlns="urn:schemas-microsoft-com:xml-analysis">
                <root xmlns="urn:schemas-microsoft-com:xml-analysis:empty">
                </root>
            </return>'

            $errorResult = '
            <return xmlns="urn:schemas-microsoft-com:xml-analysis">
                <root xmlns="urn:schemas-microsoft-com:xml-analysis:empty">
                    <Exception xmlns="urn:schemas-microsoft-com:xml-analysis:exception" />
                    <Messages xmlns="urn:schemas-microsoft-com:xml-analysis:exception">
                        <Error ErrorCode="-1055784777" 
                            Description="The JSON DDL ..." 
                            Source="Microsoft SQL Server 2018 CTP1 Analysis Services Managed Code Module"
                            HelpFile="" />
                    </Messages>
                </root>
            </return>'


            Context "Successfull deployment" {
                $return = DeployModel -Server $Server -Command $Command -Admin $Admin -Password $Password
                
                It "No errors" {
                    $return | Should Be 0
                }
            }

            Context "No server variable" {
                $Server = ''
                
                It "Should throw exception" {
                    { $return = DeployModel -Server $Server -Command $Command -Admin $Admin -Password $Password } | Should Throw "Error during deploying the model (Error: missing server variable)"
                }
            }

            Context "No admin variable" {
                $Admin = ''
                
                It "Should throw exception" {
                    { $return = DeployModel -Server $Server -Command $Command -Admin $Admin -Password $Password } | Should Throw "Error during deploying the model (Error: missing admin variable)"
                }
            }

            Context "Successfull deployment; server returns error" {
                $Command = '{Error}'

                $return = DeployModel -Server $Server -Command $Command -Admin $Admin -Password $Password
                
                It "Returns 1 errors" {
                    $return | Should Be -1
                }
            }
        }
    }

    Context "function: ProcessMessages" {
        InModuleScope $linkedModule {
            # Mock functions
            Mock Write-Host { }
            
            Context "Process result: no error and warnings" {
                $result = '
                    <return xmlns="urn:schemas-microsoft-com:xml-analysis">
                        <root xmlns="urn:schemas-microsoft-com:xml-analysis:empty">
                        </root>
                    </return>'

                $return = ProcessMessages($result)

                It "Return succesfull" {
                    $return | Should Be 0
                }

                It "No errors and warnings" {
                    Assert-MockCalled Write-Host -Times 0
                }
            }

            Context "Process result: 1 error" {
                $result = '
                <return xmlns="urn:schemas-microsoft-com:xml-analysis">
                    <root xmlns="urn:schemas-microsoft-com:xml-analysis:empty">
                        <Exception xmlns="urn:schemas-microsoft-com:xml-analysis:exception" />
                        <Messages xmlns="urn:schemas-microsoft-com:xml-analysis:exception">
                            <Error ErrorCode="-1055784777" 
                                Description="The JSON DDL ..." 
                                Source="Microsoft SQL Server 2018 CTP1 Analysis Services Managed Code Module"
                                HelpFile="" />
                        </Messages>
                    </root>
                </return>'

                $return = ProcessMessages($result)

                It "Return error" {
                    $return | Should Be -1
                }

                It "Process 1 error" {
                    Assert-MockCalled Write-Host -Times 1
                }
            }

            Context "Process result: 1 warning" {
                $result = '
                <return xmlns="urn:schemas-microsoft-com:xml-analysis">
                    <root xmlns="urn:schemas-microsoft-com:xml-analysis:empty">
                        <Exception xmlns="urn:schemas-microsoft-com:xml-analysis:exception" />
                        <Messages xmlns="urn:schemas-microsoft-com:xml-analysis:exception">
                            <Warning WarningCode="1092354050" 
                                Description="Server: Operation completed with 17 problems logged."
                                Source="Microsoft SQL Server 2018 CTP1 Analysis Services Managed Code Module"
                                HelpFile="" />
                        </Messages>
                    </root>
                </return>'

                $return = ProcessMessages($result)

                It "Return succesfull with warning" {
                    $return | Should Be 1
                }

                It "Process 1 warning" {
                    Assert-MockCalled Write-Host -Times 1
                }
            }

            Context "Process result: 1 warning and 1 error" {
                $result = '
                <return xmlns="urn:schemas-microsoft-com:xml-analysis">
                    <root xmlns="urn:schemas-microsoft-com:xml-analysis:empty">
                        <Exception xmlns="urn:schemas-microsoft-com:xml-analysis:exception" />
                        <Messages xmlns="urn:schemas-microsoft-com:xml-analysis:exception">
                            <Warning WarningCode="1092354050" 
                                Description="Server: Operation completed with 17 problems logged."
                                Source="Microsoft SQL Server 2018 CTP1 Analysis Services Managed Code Module"
                                HelpFile="" />
                            <Error ErrorCode="-1055784777" 
                                Description="The JSON DDL ..." 
                                Source="Microsoft SQL Server 2018 CTP1 Analysis Services Managed Code Module"
                                HelpFile="" />
                        </Messages>
                    </root>
                </return>'

                $return = ProcessMessages($result)

                It "Return error" {
                    $return | Should Be -1
                }

                It "Process 1 warning and 1 error" {
                    Assert-MockCalled Write-Host -Times 2
                }
            }
        }
    }
}