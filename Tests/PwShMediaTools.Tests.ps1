Describe 'PwShMediaTools Tests' {

    Import-Module "PwShMediaTools" -ea 0 -Force

    Context 'Test Module import' {

        It 'Module is imported' {
            $Valid = Get-Module -Name 'PwShMediaTools'
            $Valid.Name | Should -Be 'PwShMediaTools'
        }

    }

    Context 'Test PwShMediaTools Functions' {

        # It 'Gets bitrate and duration from a media file' {
        #     # NEED TO MOCK A FILE FOR mediainfo APP
        #     # $Valid = Get-Item | Get-MediaInfo
        #     # $Valid.bitrate | Should -Not -BeNullOrEmpty
        #     # $Valid.duration | Should -Not -BeNullOrEmpty
        # }

    }

}

