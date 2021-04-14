#Script to prepare machine for Docker use
#Written by Sergio Padure for IT-Anywhere
#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -PSEdition Desktop

$winver = Get-ComputerInfo | Select-Object -ExpandProperty 'WindowsVersion'

if ($winver -lt 1909) {
    throw "Windows 10 version is too old. Please upgrade to 1909 or higher and re-run the script"
}
else {
    Write-Host "Windows version is $winver. Continuing"
    #Preparing logging and general variables
    $scriptdir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $mainpath = Split-Path $PSScriptRoot -Parent
    $WorkingDirectory = "C:\temp"
    $WDExists = Test-Path -Path $WorkingDirectory
    if (-not $WDExists) {
        New-Item -ItemType Directory -Path $WorkingDirectory
    }
    $dateandtime = Get-Date -Format "dd_MM_yyyy_HH-mm"

    #Starting logging
    $ErrorActionPreference = "SilentlyContinue"
    Stop-Transcript | out-null
    #Continuing
    $ErrorActionPreference = "Continue"
    Start-Transcript -path "$scriptdir\InstallCentreonPollerRequirements-$dateandtime.log" -append
    $ProgressPreference = 'SilentlyContinue' 

    #Enabling required features
    try {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
        #dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V /all /norestart
        #bcdedit.exe /set hypervisorlaunchtype auto
    }
    catch {
        $_
    }

    #Pulling and installing kernel
    Write-host "Pulling and installing kernel"
    $kernel = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
    $Installer = "wsl_update_x64.msi"
    $InstallerFullPath = Join-Path -Path $WorkingDirectory -ChildPath $Installer
    $Installerexists = Test-Path -Path $InstallerFullPath
    if (-not $Installerexists) {
        Invoke-WebRequest -Uri $kernel -OutFile $InstallerFullPath | Out-Null
    }
    $arguments = "/i $InstallerFullPath /l*v $WorkingDirectory\kernel-$dateandtime.log /qn"
    try {
        # Install the package
        Start-Process "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow
    }
    catch {
        $_
    }

    #Setting WSL2 as default
    try {
        wsl --set-default-version 2
    }
    catch {
        Write-Warning "Failed setting wsl version. Please restart the computer and run the script again"
    }


    #Pulling and installing docker
    Write-Host "Pulling and installing docker"
    $docker = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
    $Installer = "dockerdesktop.exe"
    $InstallerFullPath = Join-Path -Path $WorkingDirectory -ChildPath $Installer
    $Installerexists = Test-Path -Path $InstallerFullPath
    $dockerinstalllog = "$WorkingDirectory\docker-$dateandtime.log"
    if (-not $Installerexists) {
        Invoke-WebRequest -Uri $docker -OutFile $InstallerFullPath | Out-Null
    }
    $arguments = "install --quiet"
    try {
        # Install the package
        Start-Process $InstallerFullPath -ArgumentList $arguments -Wait -RedirectStandardOutput $dockerinstalllog -NoNewWindow
    }
    catch {
        $_
    }

    #Pulling and installing wireguard
    Write-Host "Pulling and installing wireguard"
    $files = (Invoke-WebRequest -Uri "https://download.wireguard.com/windows-client").Links.Href
    foreach ($file in $files) {
        if ($file -like "wireguard-amd64-*.msi") {
            $Installer = $file
        }
    }
    $wireguard = "https://download.wireguard.com/windows-client/$Installer"
    $InstallerFullPath = Join-Path -Path $WorkingDirectory -ChildPath $Installer
    $Installerexists = Test-Path -Path $InstallerFullPath
    if (-not $Installerexists) {
        Invoke-WebRequest -Uri $wireguard -OutFile $InstallerFullPath | Out-Null
    }
    $arguments = "/i $InstallerFullPath /l*v $WorkingDirectory\wireguard-$dateandtime.log  /q DO_NOT_LAUNCH=True"
    try {
        # Install the package
        Start-Process "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow
    }
    catch {
        $_
    }

    #Registering the automatic scheduled task that will keep Docker up to date even if running as a service account
    Write-Host "Installing update scheduled task"
    try {
        #Preparing file variable
        $scheduledarguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$mainpath\3_Maintain\DockerAutoUpdate\Update-Docker.ps1`""
        #Preparing the Scheduled Task Properties
        $trigger = New-ScheduledTaskTrigger -Daily -At 1am
        $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument $scheduledarguments
        $settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable -RestartCount 999
        $settings.ExecutionTimeLimit = 'PT72H'
        $settings.RestartInterval = 'PT1M' 

        #Registering the scheduled task
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName UpdateDocker -Settings $settings -User "NT AUTHORITY\SYSTEM" -RunLevel Highest -ErrorAction SilentlyContinue

        #Starting the scheduled task
        Start-ScheduledTask -TaskName "UpdateDocker" -ErrorAction SilentlyContinue
    }
    catch {
        $_
    }
    #Registering the automatic scheduled task that will regularly re-sync time with the local system
    Write-Host "Installing timesync scheduled task"
    try {
        #Preparing file variable
        $scheduledarguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$mainpath\3_Maintain\DockerAutoUpdate\Update-Docker.ps1`" -OnlyTime"
        #Preparing the Scheduled Task Properties
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument $scheduledarguments
        $settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable -RestartCount 999
        $settings.ExecutionTimeLimit = 'PT72H'
        $settings.RestartInterval = 'PT1M' 

    
        #Registering the scheduled task
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "UpdateDockerTime" -Settings $settings -User "NT AUTHORITY\SYSTEM" -RunLevel Highest -ErrorAction SilentlyContinue -Force

        #adding repeat every 1 hour
        $schdtask = Get-ScheduledTask -TaskName "UpdateDockerTime"
        $schdtask.Triggers.Repetition.Interval = "PT1H"
        $schdtask | Set-ScheduledTask -User "NT AUTHORITY\SYSTEM"
    
        #Starting the scheduled task
        Start-ScheduledTask -TaskName "UpdateDockerTime" -ErrorAction SilentlyContinue
    }
    catch {
        $_
    }
    <#
    #Preparing mount directory. Commented out since testing was unsuccessful. Currently using standard Docker volumes
    $dockerdir = "C:\docker\centreon"
    $dockerfolderexists = Test-Path -Path $dockerdir
    if (-not $dockerfolderexists) {
        New-Item -ItemType Directory -Path $dockerdir
    }
#>

}


Write-Host "If no errors before this message go to the next step"

#Stop logging
Stop-Transcript