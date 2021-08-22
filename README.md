# PwShMediaTools

Tools for processing media files and their details. 

***

# Getting Started
1.	Installation process 

    Clone directly from Git:

        $uri = 'https://github.com/tonypags/PwShMediaTools.git'
        $ModuleParent = $env:PSModulePath -split ';|:' | Where {$_ -like "*$($env:USERNAME)*"} | Select -First 1
        Set-Location $ModuleParent
        git clone $uri


    Then you have to load the module

        ipmo PwShMediaTools

        # Run on some video file you have somewhere...
        @(dir ~/Movies/*.mp4)[0] | Get-MediaInfo -ov info

        # Inspect the object
        $info.General
        $info.Video
        $info.Audio

<br>

2.	Dependencies

    This module has the following PowerShell Dependancies:
    
        None

    This module has the following Software Dependancies:
    
    You need to have a supported package manager (apt or yum on Linux, or homebrew on your Mac).

    For MacOS

        brew install mediainfo

    For Debian/Ubuntu

        sudo apt-get install mediainfo -y

    For CentOS/RHEL

        sudo yum install mediainfo -y


<br>

3.	Version History

    - v0.1.0.1 - Initial Commit.
    - v0.1.1.3 - Working version.

<br>



# Build, Test, and Publish

1.  Pester test. 

2.  Get next version number `v#.#.#.#` and a comment `[string]` for the change log.

3.  Create a new Package folder as .\Package\v#.#.#.#\

4.  Copy the PSD1 files in as-is.

    Update the version number and copyright date if required.

	Update the Exported Function Name array with the basenames of the files under the Public folder only.

5.  Create a new, blank PSM1 file in here. 

    Populate it with all of the PS1 files' content from the .\Public and .\Private folders.

6.  Create a NUSPEC file and update the version and change log.

7.  Build the NuGet package.

8.  Push to private repo.


<br>


# Contribute
How to help make this module better: 

1.  Add your changes to a new feature sub-branch.

2.  Add Pester tests for your changes.

3.  Push your branch to origin.

4.  Submit a PR with description of changes.

5.  Follow up in 1 business day.


<br>

