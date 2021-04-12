#Script to keep docker automatically updated
#Written by Sergio Padure for IT-Anywhere
#Based on https://github.com/damienvanrobaeys/Docker_Desktop_CE_Auto_Update_Service
#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -PSEdition Desktop

#Preparing logging and general variables
$scriptdir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$RootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$ParentDir = [System.IO.Path]::GetDirectoryName($RootDir)
$ParentDir2 = [System.IO.Path]::GetDirectoryName($ParentDir)
$restartdocker = "$ParentDir2\2_Deploy\restartdocker.bat"
$WorkingDirectory = "C:\temp\docker"
$WDExists = Test-Path -Path $WorkingDirectory
if (-not $WDExists) {
    New-Item -ItemType Directory -Path $WorkingDirectory
}
$dateandtime = Get-Date -Format "dd_MM_yyyy_HH-mm"

$Log_File_Full = "$WorkingDirectory\Debug\Update_Docker_Full_Log.log"
$Log_File = "$WorkingDirectory\Debug\Docker_Update.log"
$Appli_name = "Docker for Windows"

If (!(test-path $Log_File)) { new-item $Log_File -type file -force }
$Global:Current_Folder = split-path $MyInvocation.MyCommand.Path

#Preparing functions
Function Write_Log {
    param(
        $Message_Type,	
        $Message
    )
		
    $MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
    Add-Content $Log_File  "$MyDate - $Message_Type : $Message"			
}
Function Get_Info_Beetween_Strings {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $false)]	
        [string]$version
    )	
    $Check_Pattern = ">(.*?)</a>"
    $Get_Info = ([regex]::match($version, $Check_Pattern).Groups[1].Value).Trim()
    Return $Get_Info
}

Write_Log -Message_Type "INFO" -Message "Starting Time Sync"

#Updating time
$timeupdateoutput = docker run --privileged --rm alpine date -s "$(Get-Date ([datetime]::UTCNow) -UFormat "+%Y-%m-%d %H:%M:%S")"

Write_Log -Message_Type "INFO" -Message "$timeupdateoutput"

Write_Log -Message_Type "INFO" -Message "Starting $Appli_name update process"

$New_Version_available = $False
$Docker_Reg_Path = "HKLM:\software\microsoft\windows\currentversion\uninstall\Docker desktop"

If (Test-Path $Docker_Reg_Path) {
    $Get_Current_Docker_Version = (Get-ItemProperty -Path "HKLM:\software\microsoft\windows\currentversion\uninstall\Docker desktop").displayversion
    $Current_Docker_CE_Version = "docker desktop community $Get_Current_Docker_Version"
    $Release_Notes_Page = "https://docs.docker.com/docker-for-windows/release-notes/"
    $Get_Docker_CE_Versions = ((Invoke-WebRequest -Uri $Release_Notes_Page -UseBasicParsing).links | Where { $_.outerhtml -like "*docker desktop community*" }).outerhtml
    $Get_Latest_CE_Version = $Get_Docker_CE_Versions[0]
    $Docker_available_Version = Get_Info_Beetween_Strings -version $Get_Latest_CE_Version
    If ($Docker_available_Version -gt $Current_Docker_CE_Version) {
        Write_Log -Message_Type "INFO" -Message "A new version of $Appli_name is available"	
        Write_Log -Message_Type "INFO" -Message "This version is: $Docker_available_Version"		
        $New_Version_available = $True
    }				

    If ($New_Version_available -eq $True) {
        $New_Version_Download_Status = $False
        $New_Docker_Version_Path = "$WorkingDirectory\Docker_Desktop_Installer.exe"
        $Docker_Installer_Link = "https://download.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
        Write_Log -Message_Type "INFO" -Message "The new version will be downloaded"
        Try {							
            $Download_EXE = new-object -typename system.net.webclient
            $Download_EXE.Downloadfile($Docker_Installer_Link, $New_Docker_Version_Path)									
            $New_Version_Download_Status = $True
            Write_Log -Message_Type "SUCCESS" -Message "The new version of $Appli_name has been successfully downloaded"																								
        }
        Catch {							
            $New_Version_Download_Status = $False
            Write_Log -Message_Type "ERROR" -Message "An issue occured while downloading the new version of $Appli_name"																																		
        }
    }
    Else {
        Write_Log -Message_Type "INFO" -Message "There is no new version for $Appli_name"						
    }
    If (($New_Version_Download_Status -eq $True) -and ($Run_Update_Status -eq $True)) {
        Write_Log -Message_Type "INFO" -Message "The new version will be installed"	
        #Stopping the start-at-boot scheduled task
        Write_Log -Message_Type "INFO" -Message "Stopping the start-at-boot scheduled task"	
        Stop-ScheduledTask -TaskName "StartDockerAtStartup" -ErrorAction SilentlyContinue
        #Starting install
        Try {			
            start-process -FilePath $New_Docker_Version_Path -ArgumentList "install --quiet" -RedirectStandardOutput $Log_File_Full -Wait
        }
        Catch {				
            Write_Log -Message_Type "ERROR" -Message "An issue occured while installing the new version of $Appli_name"																
        }		
    }	
    #Starting the start-at-boot scheduled task
    Write_Log -Message_Type "INFO" -Message "Starting the start-at-boot scheduled task"	
    Start-ScheduledTask -TaskName "StartDockerAtStartup" -ErrorAction SilentlyContinue
}
Else {
    Write_Log -Message_Type "ERROR" -Message "$Appli_name is not installed on your computer"																
}

#Updating wireguard
switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 
        $path = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    }
    Default {
        $path = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
    
    }
}
    
$wgcurrentversion = Get-ChildItem -Path $path | Get-ItemProperty | Where-Object { $_.DisplayName -match 'WireGuard' } | Select-Object -ExpandProperty 'DisplayVersion'
    
#Pulling and installing wireguard
Write-Host "Pulling and installing wireguard"
$files = (Invoke-WebRequest -Uri "https://download.wireguard.com/windows-client" -UseBasicParsing).Links.Href
foreach ($file in $files) {
    if ($file -like "wireguard-amd64-*.msi") {
        $Installer = $file
    }
}
if ($Installer -like "*$wgcurrentversion*") {
    Write_Log -Message_Type "INFO" -Message "Wireguard is already up to date"	
}
else {
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
        Write_Log -Message_Type "ERROR" -Message "$_"
    }
    
}

#Updating docker image
Start-Process $restartdocker