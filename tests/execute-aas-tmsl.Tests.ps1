# Set the $version to the 'to be tested' version
$version = '1.1.2'

# Dynamic set the $testModule to the module file linked to the current test file
$linkedModule = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace('.Tests.ps1', '')
# Import the logic of the linked module
Import-Module $PSScriptRoot\..\$linkedModule\$version\$linkedModule.psm1 -Force

Describe "Module: $linkedModule" {

    Context "function: ExecuteScript" {
        InModuleScope $linkedModule {
            # Mock functions
            Mock Write-Host {}
            Mock New-Object {}
            Mock Invoke-ASCmd { return $successResult } -ParameterFilter { $Script -eq '{Correct}' }
            Mock Invoke-ASCmd { return $errorResult } -ParameterFilter { $Script -eq '{Error}' }
            Mock Invoke-ASCmd { throw 'Error: missing server variable' } -ParameterFilter { $Server -eq '' }
            Mock Invoke-ASCmd { throw 'Error: missing admin variable' } -ParameterFilter { $Admin -eq '' }

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

            $Server = 'localhost'
            $Script = '{Correct}'
            $Admin = 'admin@localhost'
            $Password = ConvertTo-SecureString 'Password' -AsPlainText -Force

            Context "Succesfull execute script" {
                $result = ExecuteScript -Server $Server -Script $Script -Admin $Admin -Password $Password

                It "No errors" {
                    $result | Should Be $result 0
                }
            }

            Context "No server variable" {
                $Server = ''
                
                It "Should throw exception" {
                    { $return = ExecuteScript -Server $Server -Script $Script -Admin $Admin -Password $Password } | Should Throw "Error during deploying the model (Error: missing server variable)"
                }
            }

            Context "No admin variable" {
                $Admin = ''
                
                It "Should throw exception" {
                    { $return = ExecuteScript -Server $Server -Script $Script -Admin $Admin -Password $Password } | Should Throw "Error during deploying the model (Error: missing admin variable)"
                }
            }

            Context "Successfull script call; server returns error" {
                $Script = '{Error}'

                $return = ExecuteScript -Server $Server -Script $Script -Admin $Admin -Password $Password
                
                It "Returns 1 errors" {
                    $return | Should Be -1
                }
            }
        }
    }

    Context "function: ExecuteScriptFile" {
        InModuleScope $linkedModule {
            # Mock functions
            Mock Write-Host {}
            Mock New-Object {}
            Mock Invoke-ASCmd { return $successResult } -ParameterFilter { $InputFile -eq 'C:\\CorrectFile' }
            Mock Invoke-ASCmd { return $errorResult } -ParameterFilter { $InputFile -eq 'C:\\ErrorFile' }
            Mock Invoke-ASCmd { throw 'Error: missing server variable' } -ParameterFilter { $Server -eq '' }
            Mock Invoke-ASCmd { throw 'Error: missing admin variable' } -ParameterFilter { $Admin -eq '' }

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

            $Server = 'localhost'
            $ScriptFile = 'C:\\CorrectFile'
            $Admin = 'admin@localhost'
            $Password = ConvertTo-SecureString 'Password' -AsPlainText -Force

            Context "Succesfull execute script" {
                $result = ExecuteScriptFile -Server $Server -ScriptFile $ScriptFile -Admin $Admin -Password $Password

                It "No errors" {
                    $result | Should Be $result 0
                }
            }

            Context "No server variable" {
                $Server = ''
                
                It "Should throw exception" {
                    { $return = ExecuteScriptFile -Server $Server -ScriptFile $ScriptFile -Admin $Admin -Password $Password } | Should Throw "Error during deploying the model (Error: missing server variable)"
                }
            }

            Context "No admin variable" {
                $Admin = ''
                
                It "Should throw exception" {
                    { $return = ExecuteScriptFile -Server $Server -ScriptFile $ScriptFile -Admin $Admin -Password $Password } | Should Throw "Error during deploying the model (Error: missing admin variable)"
                }
            }

            Context "Successfull script call; server returns error" {
                $ScriptFile = 'C:\\ErrorFile'

                $return = ExecuteScriptFile -Server $Server -ScriptFile $ScriptFile -Admin $Admin -Password $Password
                
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