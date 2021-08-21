Describe 'PwShMediaTools Tests' {

    Import-Module "PwShMediaTools" -ea 0 -Force

    Context 'Test Module import' {

        It 'Module is imported' {
            $Valid = Get-Module -Name 'PwShMediaTools'
            $Valid.Name | Should -Be 'PwShMediaTools'
        }

    }

    Context 'Test PwShMediaTools Functions' {

        It 'Valid Value (sample test)' {
            $Valid = 'Valid'
            $Valid | Should -Be $Valid
        }

    }

}

