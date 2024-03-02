# BDLauncher
### A script to install and (re)launch (Better)Discord on Windows

## Usage (Command Line)
```
bdlauncher.ps1 [{-Install|-Repair|-Uninject|-Status}] [-Release {stable|ptb|canary}] [-DiscordPath <path>] [-skipDownload] [-LaunchDiscord]
```

#### `-Install`
Pass this to download and inject BetterDiscord

#### `-Repair`
Same as `-Install` but also disables plugins and themes before re-injecting to Discord.

#### `-Uninject`
Self-explanatory

#### `-Status`
Returns installation status for selected release.

**Note: The previous 4 options cannot be combined, use only one of them when running the script.**

#### `-Release`
Use this to select your Discord release.
Expected values are `stable`, `ptb` and `canary`
The script will default to `stable` if this is omitted

##### `-DiscordPath`
Use this to specify the path to a Discord installation. This is only needed if you're not using the default install directories. Must be combined with `-Release` to work.

#### `-skipDownload`
Skips downloading `betterdiscord.asar` if one already exists.

#### `-LaunchDiscord`
Launches the appropriate Discord release after the command completes.

## Usage (Recommended)

1. Create a Shortcut with the target being `"C:\Program Files\PowerShell\7\pwsh.exe" \path\to\bdlauncher.ps1` and your desired arguments.
- Note that Windows includes legacy versions of PowerShell that this script will fail to run in. The `powershell` command points to version 1 at the time of writing.
2. Add `-LaunchDiscord` as an argument for it to always launch Discord.
3. Add to Start Menu or your desktop for your convenience.