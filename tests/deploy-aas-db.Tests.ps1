# Set the $version to the 'to be tested' version
$version = '1.0.0'

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
            
        }
    }
}