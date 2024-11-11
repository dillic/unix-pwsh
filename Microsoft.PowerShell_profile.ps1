$githubUser = "Dillic" # Change this here if you forked the repository.
$name= "Martin" # Change this to your name.
$githubRepo = "unix-pwsh" # Change this here if you forked the repository and changed the name.
$githubBaseURL= "https://raw.githubusercontent.com/$githubUser/$githubRepo/main"
$OhMyPoshConfigFileName = "montys.omp.json" # Filename of the OhMyPosh config file
$OhMyPoshConfig = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$OhMyPoshConfigFileName" # URL of the OhMyPosh config file, make sure to use the last part of the raw lik, (stands for the filename) in the variable on the line below

# -----------------------------------------------------------------------------

# Check internet access
# Use wmi as there is no timeout in pwsh  5.0 and generally slow.
$timeout = 1000 
$pingResult = Get-CimInstance -ClassName Win32_PingStatus -Filter "Address = 'github.com' AND Timeout = $timeout" -Property StatusCode 2>$null
if ($pingResult.StatusCode -eq 0) {
    $canConnectToGitHub = $true
} else {
    $canConnectToGitHub = $false
}

# Define vars.
$baseDir = "$HOME\unix-pwsh"
$configPath = "$baseDir\pwsh_custom_config.yml"
$xConfigPath = "$baseDir\pwsh_full_custom_config.yml" # This file exists if the prompt is fully installed with all dependencies.
$promptColor = "DarkCyan" # Choose a color in which the hello text is colored; All Colors: Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, DarkRed, DarkYellow, Gray, Green, Magenta, Red, White, Yellow.
$font="FiraCode" # Font-Display and variable Name, name the same as font_folder
$font_url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip" # Put here the URL of the font file that should be installed
$fontFileName = "FiraCodeNerdFontMono-Regular.ttf" # Put here the font file that should be installed
$font_folder = "FiraCode" # Put here the name of the zip folder of the downloaded font, but without the .zip extension.

$modules = @( 
    # This is a list of modules that need to be imported / installed
    @{ Name = "Powershell-Yaml"; ConfigKey = "Powershell-Yaml_installed" },
    @{ Name = "Terminal-Icons"; ConfigKey = "Terminal-Icons_installed" },
    @{ Name = "PoshFunctions"; ConfigKey = "PoshFunctions_installed" }
)
$files = @("Microsoft.PowerShell_profile.ps1", "installer.ps1", "pwsh_helper.ps1", "functions.ps1", $OhMyPoshConfigFileName)

# Message to tell the user what to do after installation
$infoMessage = @"
To fully utilize the custom Unix-pwsh profile, please follow these steps:
1. Set Windows Terminal as the default terminal.
2. Choose PowerShell Core as the preferred startup profile in Windows Terminal.
3. Go to Settings > Defaults > Appearance > Font and select the Nerd Font.

These steps are necessary to ensure the pwsh profile works as intended.
If you have further questions, on how to set the above, don't hesitate to ask me, by filing an issue on my repository, after you tried searching the web for yourself.
"@

$scriptBlock = {
    param($githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL)
    Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/pwsh_helper.ps1" -UseBasicParsing).Content
    BackgroundTasks
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

# Function for calling the update Powershell Script
function Run-UpdatePowershell {
    . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/pwsh_helper.ps1" -UseBasicParsing).Content
    Update-Powershell
}

# ----------------------------------------------------------------------------

Write-Host ""
Write-Host "Welcome $name ⚡" -ForegroundColor $promptColor
Write-Host ""

# Function to check if all the $files exist or not.
$allFilesExist = $files | ForEach-Object { Join-Path -Path $baseDir -ChildPath $_ } | Test-Path -PathType Leaf -ErrorAction SilentlyContinue | ForEach-Object { $_ -eq $true }
if ($allFilesExist -contains $false) {
    $injectionMethod = "remote"
} else {
    $injectionMethod = "local"
    $OhMyPoshConfig = Join-Path -Path $baseDir -ChildPath $OhMyPoshConfigFileName
}

# Check for dependencies and if not chainload the installer.
if (Test-Path -Path $xConfigPath) {
    # Check if the Master config file exists, if so skip every other check.
    Write-Host "✅ Successfully initialized Pwsh`n" -ForegroundColor Green
    Import-Module Terminal-Icons
    # foreach ($module in $modules) {
    #     # As the master config exists, we assume that all modules are installed.
    #     Import-Module $module.Name
    # }
} else {
    # If there is no internet connection, we cannot install anything.
    if (-not $global:canConnectToGitHub) {
        Write-Host "❌ Skipping initialization due to GitHub not responding within 4 second." -ForegroundColor Red
        exit
    }
    . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/installer.ps1" -UseBasicParsing).Content
    Install-NuGet
    Test-Pwsh 
    Test-CreateProfile
    Install-Config
}

# Try to import MS PowerToys WinGetCommandNotFound
Import-Module -Name Microsoft.WinGet.CommandNotFound > $null 2>&1
if (-not $?) {Install-Module -Name Microsoft.WinGet.CommandNotFound}

# Inject OhMyPosh
oh-my-posh init pwsh --config $OhMyPoshConfig | Invoke-Expression


# ----------------------------------------------------------
# Deferred loading
# Source: https://fsackur.github.io/2023/11/20/Deferred-profile-loading-for-better-performance/
# ----------------------------------------------------------

# Check if psVersion is lower than 7.x, then load the functions **without** deferred loading
if ($PSVersionTable.PSVersion.Major -lt 7) {
    if ($injectionMethod -eq "local") {
        . "$baseDir\functions.ps1"
        # Execute the background tasks
        Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
        } else {
        if ($global:canConnectToGitHub) {
            #Load Functions
            . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/functions.ps1" -UseBasicParsing).Content
            # Update PowerShell in the background
            Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
                } else {
            Write-Host "❌ Skipping initialization due to GitHub not responding within 1 second." -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------

$Deferred = {
    if ($injectionMethod -eq "local") {
        . "$baseDir\functions.ps1"
        # Execute the background tasks
        Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
        } else {
        if ($global:canConnectToGitHub) {
            #Load Functions
            . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/functions.ps1" -UseBasicParsing).Content
            # Update PowerShell in the background
            Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
            } else {
            Write-Host "❌ Skipping initialization due to GitHub not responding within 1 second." -ForegroundColor Red
        }
    }
}


$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState
# to run our code asynchronously
$Runspace = [runspacefactory]::CreateRunspace($Host)
$Powershell = [powershell]::Create($Runspace)
$Runspace.Open()
$Runspace.SessionStateProxy.PSVariable.Set('GlobalState', $GlobalState)
# ArgumentCompleters are set on the ExecutionContext, not the SessionState
# Note that $ExecutionContext is not an ExecutionContext, it's an EngineIntrinsics 😡
$Private = [Reflection.BindingFlags]'Instance, NonPublic'
$ContextField = [Management.Automation.EngineIntrinsics].GetField('_context', $Private)
$Context = $ContextField.GetValue($ExecutionContext)
# Get the ArgumentCompleters. If null, initialise them.
$ContextCACProperty = $Context.GetType().GetProperty('CustomArgumentCompleters', $Private)
$ContextNACProperty = $Context.GetType().GetProperty('NativeArgumentCompleters', $Private)
$CAC = $ContextCACProperty.GetValue($Context)
$NAC = $ContextNACProperty.GetValue($Context)
if ($null -eq $CAC)
{
    $CAC = [Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextCACProperty.SetValue($Context, $CAC)
}
if ($null -eq $NAC)
{
    $NAC = [Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextNACProperty.SetValue($Context, $NAC)
}
# Get the AutomationEngine and ExecutionContext of the runspace
$RSEngineField = $Runspace.GetType().GetField('_engine', $Private)
$RSEngine = $RSEngineField.GetValue($Runspace)
$EngineContextField = $RSEngine.GetType().GetFields($Private) | Where-Object {$_.FieldType.Name -eq 'ExecutionContext'}
$RSContext = $EngineContextField.GetValue($RSEngine)
# Set the runspace to use the global ArgumentCompleters
$ContextCACProperty.SetValue($RSContext, $CAC)
$ContextNACProperty.SetValue($RSContext, $NAC)
$Wrapper = {
    # Without a sleep, you get issues:
    #   - occasional crashes
    #   - prompt not rendered
    #   - no highlighting
    # Assumption: this is related to PSReadLine.
    # 20ms seems to be enough on my machine, but let's be generous - this is non-blocking
    Start-Sleep -Milliseconds 100
    . $GlobalState {. $Deferred; Remove-Variable Deferred}
}
$null = $Powershell.AddScript($Wrapper.ToString()).BeginInvoke()

function Edit-Profile {
    code $PROFILE
}
function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = "& '$args'"
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}

# Set UNIX-like aliases for the admin command, so sudo <command> will run the command with elevated rights.
Set-Alias -Name su -Value admin

function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

function reload-profile {
    & $profile
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

function tail {
  param($Path, $n = 10, [switch]$f = $false)
  Get-Content $Path -Tail $n -Wait:$f
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

### Quality of Life Aliases

# Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }

function dtop { Set-Location -Path $HOME\Desktop }

# Quick Access to Editing the Profile
function ep { vim $PROFILE }

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gp { git push }

function g { __zoxide_z github }

function gcl { git clone "$args" }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
	Clear-DnsClientCache
	Write-Host "DNS has been flushed"
}

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Winget functions
# Winget Upgrade All
function wgu { winget upgrade --all }
# Winget Search
function wgs { winget search "$args"}
# Winget Install Package - based on ID
function wgi { winget install --id @args }
# Winget Package Information - based on ID
function wgss { winget show --id @args }

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

$PSROptions = @{
    ContinuationPrompt = '  '
    Colors             = @{
    Parameter          = $PSStyle.Foreground.Magenta
    Selection          = $PSStyle.Background.Black
    InLinePrediction   = $PSStyle.Foreground.BrightYellow + $PSStyle.Background.BrightBlack
    }
}
Set-PSReadLineOption @PSROptions
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

# Help Function
function Show-Help {
    @"
PowerShell Profile Help
=======================

Update-PowerShell - Checks for the latest PowerShell release and updates if a new version is available.

Edit-Profile - Opens the current user's profile for editing using the configured editor.

touch <file> - Creates a new empty file.

Get-PubIP - Retrieves the public IP address of the machine.

winutil - Runs the WinUtil script from Chris Titus Tech.

uptime - Displays the system uptime.

reload-profile - Reloads the current user's PowerShell profile.

unzip <file> - Extracts a zip file to the current directory.

df - Displays information about volumes.

grep <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.

sed <file> <find> <replace> - Replaces text in a file.

which <name> - Shows the path of the command.

export <name> <value> - Sets an environment variable.

pkill <name> - Kills processes by name.

pgrep <name> - Lists processes by name.

head <path> [n] - Displays the first n lines of a file (default 10).

tail <path> [n] - Displays the last n lines of a file (default 10).

nf <name> - Creates a new file with the specified name.

mkcd <dir> - Creates and changes to a new directory.

docs - Changes the current directory to the user's Documents folder.

dtop - Changes the current directory to the user's Desktop folder.

ep - Opens the profile for editing.

k9 <name> - Kills a process by name.

la - Lists all files in the current directory with detailed formatting.

ll - Lists all files, including hidden, in the current directory with detailed formatting.

gs - Shortcut for 'git status'.

ga - Shortcut for 'git add .'.

gc <message> - Shortcut for 'git commit -m'.

gp - Shortcut for 'git push'.

g - Changes to the GitHub directory.

gcom <message> - Adds all changes and commits with the specified message.

lazyg <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.

sysinfo - Displays detailed system information.

flushdns - Clears the DNS cache.

cpy <text> - Copies the specified text to the clipboard.

pst - Retrieves text from the clipboard.

Use 'Show-Help' to display this help message.

winget-upgrade - Upgrades all installed packages using Winget.
"@
}
Write-Host "Use 'Show-Help' to display help"
