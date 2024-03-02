param (
    [switch]$LaunchDiscord = $false,
    [switch]$Uninject = $false,
    [switch]$Install = $false,
    [switch]$Repair = $false,
    [string]$Release = "",
    [string]$DiscordPath = "",
    [switch]$Status = $false,
    [switch]$skipDownload = $false
)

$ErrorActionPreference = "Stop"

$bdFolder = "$Env:APPDATA\BetterDiscord"
$bdDatafolder = "$bdFolder\data"
$bdPluginsFolder = "$bdFolder\plugins"
$bdThemesFolder = "$bdFolder\themes"
$foldersList = "$bdFolder", "$bdDataFolder", "$bdPluginsFolder", "$bdThemesFolder"

function setDiscordPath {

    if ($script:Release) {
        switch ($Script:Release) {
            stable { $script:DiscordPath = "$Env:LOCALAPPDATA\Discord" } 
            ptb { $script:DiscordPath = "$Env:LOCALAPPDATA\DiscordPTB" } 
            canary { $script:DiscordPath = "$Env:LOCALAPPDATA\DiscordCanary" }
            default { Write-Error "Invalid Discord version. Expected values are 'stable', 'ptb' and 'canary'"; exit 1 }
        } 
    }
    elseif (!($script:Release) -and ($script:DiscordPath)) {
        Write-Error "'-Release' is required if '-DiscordPath' is specified. Expected values are 'stable', 'ptb' and 'canary'"
        exit 2
    } 
    else {
        Write-Host -ForegroundColor Yellow "Defaulting to 'stable' as -Release was not set."
        $script:DiscordPath = "$Env:LOCALAPPDATA\Discord" 
        $script:Release = "stable" 
    }   
    switch ($Script:Release) {
        stable { $Script:execName = "Discord" } 
        ptb { $Script:execName = "DiscordPTB" }  
        canary { $Script:execName = "DiscordCanary" } 
        default { Write-Error "Invalid Discord version. Expected values are 'stable', 'ptb' and 'canary'"; exit 1 }
    }   
   
}

$releaseTitle = (Get-Culture).TextInfo.ToTitleCase($Script:Release)

$pluginsJSON = "$bdDatafolder\$Release\plugins.json"
$themesJSON = "$bdDatafolder\$Release\themes.json"

function launchClient {
        Write-Host "Launching Discord $Script:releaseTitle...."
       & "$appVer\$Script:execName.exe" 
       # I want to close the window but discord opens a pipe for its log and it throws a fit if i redirect it...
        Write-Host "Exiting in 5 seconds..."
        Start-Sleep 5
        exit 0
}

function cordCutter {
    Write-Host "Telling Discord $releaseTitle to exit..."
    try {
        Stop-Process -Name $execName
        Write-Host -ForegroundColor Green "Discord $releaseTitle has been killed." 
    }
    catch { Write-Host -ForegroundColor Yellow "Discord $releaseTitle doesn`'t seem to be running..." }
}

function installBD {
  
    ForEach ($item in $Script:foldersList) {
        if (Test-Path $item) {
            continue
        }
        else {
            Write-Host "Creating $item"
            try { New-Item -ItemType Directory $item }
            catch {
                Write-Host -ForegroundColor Red "Unable to create $item."
                exit 9
            }
        }
    }

    if ($script:Install -or $Script:Repair) {
        if (!($Script:skipDownload)){
            downloadBD
        } 
        elseif (($Script:skipDownload) -and (Test-Path -Path "$bdDataFolder\betterdiscord.asar")) {
            Write-Host "asar already exists, skipping download because asked."
        }
        cordCutter 
        injectBD
        checkInstall
    }
}

function repairBD {
    Write-Host "Disabling all plugins for Discord $releaseTitle..."
((Get-Content -path "$Script:pluginsJSON" -Raw) -replace 'true', 'false') | Set-Content -Path "$Script:pluginsJSON"
    Write-Host "Disabling all themes for Discord $releaseTitle..."
((Get-Content -path "$Script:themesJSON" -Raw) -replace 'true', 'false') | Set-Content -Path "$Script:themesJSON"

    Write-Host "Re-installing BetterDiscord to Discord $releaseTitle..."
    uninjectBD
    installBD
}

function downloadBD {
    Write-Host "Downloading BetterDiscord..."
    $dlFile = "betterdiscord.asar"
    try {
        Invoke-RestMethod -Method Get -AllowInsecureRedirect -UserAgent "joshuah345/BDLauncher" -Headers @{"Accept" = "application/octet-stream" } -Uri https://betterdiscord.app/Download/$dlFile -OutFile "$bdDatafolder/$dlFile" -ResponseHeadersVariable ResponseHeaders
        $bdDLVersion = $ResponseHeaders["X-Bd-Version"]
        Write-Host -ForegroundColor Green "betterdiscord.asar ($bdDLVersion) has been downloaded!"
    }
    catch {
        Write-Host -ForegroundColor Red "An error occured while downloading BetterDiscord from the official website. Attempting to use GitHub...."
        try {
            downloadBDfromGithub
            Write-Host -ForegroundColor "betterdiscord.asar ($bdDlVersion) has been downloaded!"
        }
        catch {
            Write-Error "Downloading BetterDiscord from Github has failed. Installation cannot continue."
            exit 10
        }
    }
}

function downloadBDfromGithub {
    $dlFile = "betterdiscord.asar"
    $bdRepo = "BetterDiscord/BetterDiscord"
    $ghReleases = "https://api.github.com/repos/$bdRepo/releases/latest"

    Write-Host "Determining latest BetterDiscord release..."
    $tag = (Invoke-WebRequest $ghReleases | ConvertFrom-Json)[0].tag_name
    $Script:bdDlVersion = $tag
    $ghURI = "https://github.com/$bdRepo/releases/download/$tag/$dlFile"

    Invoke-WebRequest -Uri "$ghURI" -OutFile "$bdDataFolder/$dlFile"
}
function latestAppVersion {
    try { Get-ChildItem $DiscordPath -Filter "app-*" | Sort-Object -Property @{Expression = { [Int32]($_ -split '\.' | Select-Object -Last 1) } } | Select-Object -Last 1 -Expand FullName > $null } 
    catch {
        Write-Error "Unable to locate discord app folder for release '$Release' at '$DiscordPath'. Check your Discord installation or specify a path with '-DiscordPath' "
        exit 3
    }
    $Script:appVer = (Get-ChildItem $DiscordPath -Filter "app-*" | Sort-Object -Property @{Expression = { [Int32]($_ -split '\.' | Select-Object -Last 1) } } | Select-Object -Last 1 -Expand FullName)
    $Script:ModulesPath = "$appVer\modules"
    $Script:indexFile = "$ModulesPath\discord_desktop_core-*\discord_desktop_core\index.js"
    
}
function checkInstall {

    if (!(Test-Path $Script:DiscordPath)) {
        Write-Error "Discord $Release could not be found at '$DiscordPath'. Check your Discord installation or specify a path with '-DiscordPath'"
        exit 5
    }
    if ((Get-Content "$indexFile" | Select-String "betterdiscord")) {
        if ($Script:Status) {
            Write-Host "BetterDiscord injected to $Release was found at '$ModulesPath'." -ForegroundColor Green
            exit 0
        }
        elseif ($Script:Install) {
            Write-Host -ForegroundColor Green "BetterDiscord has been sucessfully installed to Discord $releaseTitle!" 
        }  
    }
    else {
        Write-Host -ForegroundColor Red "BetterDiscord is not injected into Discord $releaseTitle."
    }  

}

function injectBD {
    $escapedbdDataFolder = $bdDataFolder.Replace("\", "\\")
    Set-Content -Path $indexFile -Value "require(`"$($escapedbdDataFolder)\\betterdiscord.asar`");"
    Add-Content -Path $indexFile -Value "module.exports = require(`".`/core.asar`");"
}

function uninjectBD {
    Set-Content -Path $indexFile -Value "module.exports = require(`".`/core.asar`");"
    checkInstall
}
function onlyOneSwitch {
    [array]$Local:SwitchConflict = [bool]$Script:Install, [bool]$Script:Status,[bool]$Script:Uninject,[bool]$Script:Repair

    $enabledSwitchCount = 0
    for ($index = 0; $index -lt $Local:SwitchConflict.count; $index++) {
        $enabledSwitchCount = $enabledSwitchCount + $Local:SwitchConflict[$index]
    }

    if ($enabledSwitchCount -ge 2) {
        Write-Error "Arguments -Install, -Repair, -Uninject and -Status cannot be combined."   
    }
}
function mainLogic {
    
onlyOneSwitch
setDiscordPath
latestAppVersion

Write-Host -ForegroundColor Yellow "Using $DiscordPath as Discord directory." 

if ($Script:Status) {
    checkInstall
}

if ($Script:Repair) {
    repairBD
    checkInstall
}

if ($Script:Uninject) {
    uninjectBD
    cordCutter
}

if ($Script:Install) {
    installBD
}

if ($Script:LaunchDiscord) {
    launchClient
}

}

mainLogic # yep, totally treating PS like java now.