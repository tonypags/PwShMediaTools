Describe 'PwShMediaTools Tests' {

    Import-Module "PwShMediaTools" -ea 0 -Force
    # $Parent = Split-Path (
    #     Get-Module PwShMediaTools -ListAvailable).Path -Parent

    Context 'Test Module import' {

        It 'Module is imported' {
            $Valid = Get-Module -Name 'PwShMediaTools'
            $Valid.Name | Should -Be 'PwShMediaTools'
        }

    }

    Context 'Test PwShMediaTools Functions' {

        # # (mediainfo $file | Out-String) -split "`n"
        # Mock mediainfo {
        #     $samplePath = Join-Path $Parent 'lib' 'Get-MediaInfo.sample.data'
        #     $sampleData = Get-Content $samplePath -Raw
        #     return $sampleData
        # }

        It 'Gets mediainfo version' {
            $obj = Test-PackageInstalled 'mediainfo'
            $obj.Version | Should -BeOfType [version]
        }

        It 'Gets file size from a file' {
            $Valid = Get-Item $PSCommandPath | Get-MediaInfo
            $Valid.General.'File Size' | Should -Not -BeNullOrEmpty
        }

    }

}

