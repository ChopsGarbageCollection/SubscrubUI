# SubScrubUI v1.1 - DARK THEME - FULLY COMPLETE
# CSV Report Generation & Empty Folder Cleanup Added

param([string]$Language = "")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Set-StrictMode -Version Latest

$script:stopRequested = $false
$script:pauseRequested = $false

$defaultSource = "C:\Media"
$backupRoot = "C:\Backups\Media_Subtitles"
$minFileSizeKB = 1
$extensions = @("*.srt", "*.vtt", "*.ass", "*.sub", "*.ssa")
$excludeFolders = @('$RECYCLE.BIN', '@eaDir', '#recycle', '.appledouble', 'extras', 'Backup_', 'Media_SRT_Backup', '_Backup')

$languageMappings = @{
    'eng'=@('english','eng','en','en-us','en-gb'); 'spa'=@('spanish','spa','es','es-mx','es-es')
    'fre'=@('french','fre','fra','fr','fr-fr','fr-ca'); 'ger'=@('german','ger','deu','de','de-de')
    'ita'=@('italian','ita','it','it-it'); 'por'=@('portuguese','por','pt','pt-br','pt-pt')
    'jpn'=@('japanese','jpn','ja','ja-jp'); 'chi'=@('chinese','chi','zh','zh-cn','zh-tw')
    'kor'=@('korean','kor','ko','ko-kr'); 'rus'=@('russian','rus','ru','ru-ru')
    'dut'=@('dutch','dut','nld','nl','nl-nl'); 'pol'=@('polish','pol','pl','pl-pl')
}

$keepLanguages = New-Object System.Collections.Generic.List[string]

# DARK THEME COLORS
$darkBg = [System.Drawing.Color]::FromArgb(45, 45, 48)
$darkControl = [System.Drawing.Color]::FromArgb(62, 62, 66)
$lightText = [System.Drawing.Color]::White
$grayBg = [System.Drawing.Color]::FromArgb(80, 80, 84)

$form = New-Object System.Windows.Forms.Form
$form.Text = "SubScrubUI v1.1 - Subtitle Manager"
$form.ClientSize = New-Object System.Drawing.Size(680, 650)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.ShowInTaskbar = $true
$form.BackColor = $darkBg

# Load icon if it exists
if (Test-Path "SubScrub.ico") {
    try {
        $form.Icon = New-Object System.Drawing.Icon("SubScrub.ico")
    } catch {
        # Icon load failed, use default
    }
}

# Source
$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Location = New-Object System.Drawing.Point(20, 20)
$lblSource.Size = New-Object System.Drawing.Size(640, 20)
$lblSource.Text = "1. Select Media Directory to Scan:"
$lblSource.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblSource.ForeColor = $lightText
$lblSource.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblSource)

$lblNetworkHint = New-Object System.Windows.Forms.Label
$lblNetworkHint.Location = New-Object System.Drawing.Point(40, 40)
$lblNetworkHint.Size = New-Object System.Drawing.Size(620, 15)
$lblNetworkHint.Text = "Network drives: Type UNC path (\\server\share) - Scanning may be slow"
$lblNetworkHint.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$lblNetworkHint.ForeColor = [System.Drawing.Color]::DarkOrange
$lblNetworkHint.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblNetworkHint)

$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = New-Object System.Drawing.Point(20, 58)
$txtSource.Size = New-Object System.Drawing.Size(540, 25)
$txtSource.Text = $defaultSource
$txtSource.BackColor = $darkControl
$txtSource.ForeColor = $lightText
$txtSource.BorderStyle = "FixedSingle"
$form.Controls.Add($txtSource)

$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Location = New-Object System.Drawing.Point(570, 56)
$btnBrowseSource.Size = New-Object System.Drawing.Size(90, 27)
$btnBrowseSource.Text = "Browse..."
$btnBrowseSource.BackColor = $darkControl
$btnBrowseSource.ForeColor = $lightText
$btnBrowseSource.FlatStyle = "Flat"
$btnBrowseSource.Add_Click({
    # Enumerate all available drives (A-Z) including mapped network drives
    $availableDrives = @()
    
    try {
        # Use .NET DriveInfo instead of WMI (more reliable in compiled exes)
        $allDrives = @([System.IO.DriveInfo]::GetDrives())
        
        foreach ($drive in $allDrives) {
            if (-not $drive.IsReady) { continue }
            
            $driveLetter = $drive.Name.TrimEnd('\\')
            $driveType = ""
            $driveLabel = ""
            
            switch ($drive.DriveType.ToString()) {
                'Fixed' { $driveType = "Local" }
                'Network' { 
                    $driveType = "Network"
                    # Try to get network path using WMI for this specific drive
                    try {
                        $wmiDrive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$($driveLetter.TrimEnd(':')):'" -ErrorAction SilentlyContinue
                        if ($wmiDrive -and $wmiDrive.ProviderName) {
                            $driveLabel = " - $($wmiDrive.ProviderName)"
                        }
                    } catch { }
                }
                'CDRom' { $driveType = "CD/DVD" }
                'Removable' { $driveType = "Removable" }
                default { $driveType = $drive.DriveType.ToString() }
            }
            
            $availableDrives += "$driveLetter ($driveType)$driveLabel"
        }
    } catch {
        # Fallback to Test-Path method if all else fails
        65..90 | ForEach-Object {
            $driveLetter = [char]$_ + ":"
            if (Test-Path $driveLetter -ErrorAction SilentlyContinue) {
                $availableDrives += "$driveLetter (Drive)"
            }
        }
    }
    
        # Show available drives in status bar (shorter message)
    if ($availableDrives.Count -gt 0) {
        Update-Status "Detected $($availableDrives.Count) drives (see dialog for details)"
    }
    
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = "Select the directory where your subtitle files are located`r`n`r`nDetected Drives:`r`n$($availableDrives -join "`r`n")`r`n`r`nFor network paths, you can also type UNC path manually (\\server\share)"
    $fb.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    $fb.ShowNewFolderButton = $false
    
    if ($fb.ShowDialog() -eq "OK") { 
        $txtSource.Text = $fb.SelectedPath 
        Update-Status "Ready"
    } else {
        Update-Status "Ready"
    }
    [System.Windows.Forms.Application]::DoEvents()
})
$form.Controls.Add($btnBrowseSource)

# Depth
$lblDepth = New-Object System.Windows.Forms.Label
$lblDepth.Location = New-Object System.Drawing.Point(20, 88)
$lblDepth.Size = New-Object System.Drawing.Size(110, 20)
$lblDepth.Text = "Max folder depth:"
$lblDepth.ForeColor = $lightText
$lblDepth.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblDepth)

$cmbDepth = New-Object System.Windows.Forms.ComboBox
$cmbDepth.Location = New-Object System.Drawing.Point(130, 86)
$cmbDepth.Size = New-Object System.Drawing.Size(120, 25)
$cmbDepth.DropDownStyle = "DropDownList"
$cmbDepth.Items.AddRange(@("Unlimited", "3 levels", "5 levels", "10 levels"))
$cmbDepth.SelectedIndex = 0
$cmbDepth.BackColor = $darkControl
$cmbDepth.ForeColor = $lightText
$cmbDepth.FlatStyle = "Flat"
$form.Controls.Add($cmbDepth)

$lblDepthHint = New-Object System.Windows.Forms.Label
$lblDepthHint.Location = New-Object System.Drawing.Point(260, 88)
$lblDepthHint.Size = New-Object System.Drawing.Size(400, 15)
$lblDepthHint.Text = "(Limits subfolder depth - helps with large network shares)"
$lblDepthHint.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Italic)
$lblDepthHint.ForeColor = [System.Drawing.Color]::DarkOrange
$lblDepthHint.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblDepthHint)

# Language
$lblLanguage = New-Object System.Windows.Forms.Label
$lblLanguage.Location = New-Object System.Drawing.Point(20, 118)
$lblLanguage.Size = New-Object System.Drawing.Size(640, 20)
$lblLanguage.Text = "2. Select Language to Keep:"
$lblLanguage.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblLanguage.ForeColor = $lightText
$lblLanguage.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblLanguage)

$cmbLanguage = New-Object System.Windows.Forms.ComboBox
$cmbLanguage.Location = New-Object System.Drawing.Point(20, 143)
$cmbLanguage.Size = New-Object System.Drawing.Size(220, 25)
$cmbLanguage.DropDownStyle = "DropDownList"
$cmbLanguage.Items.AddRange(@("English","Spanish","French","German","Italian","Portuguese","Japanese","Chinese","Korean","Russian","Dutch","Polish"))
$cmbLanguage.SelectedIndex = 0
$cmbLanguage.BackColor = $darkControl
$cmbLanguage.ForeColor = $lightText
$cmbLanguage.FlatStyle = "Flat"
$form.Controls.Add($cmbLanguage)

$lblAdditional = New-Object System.Windows.Forms.Label
$lblAdditional.Location = New-Object System.Drawing.Point(250, 143)
$lblAdditional.Size = New-Object System.Drawing.Size(165, 25)
$lblAdditional.Text = "Additional Language Codes:"
$lblAdditional.TextAlign = "MiddleRight"
$lblAdditional.ForeColor = $lightText
$lblAdditional.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblAdditional)

$txtAdditional = New-Object System.Windows.Forms.TextBox
$txtAdditional.Location = New-Object System.Drawing.Point(420, 143)
$txtAdditional.Size = New-Object System.Drawing.Size(240, 25)
$txtAdditional.BackColor = $darkControl
$txtAdditional.ForeColor = $lightText
$txtAdditional.BorderStyle = "FixedSingle"
$form.Controls.Add($txtAdditional)

$lblAdditionalHint = New-Object System.Windows.Forms.Label
$lblAdditionalHint.Location = New-Object System.Drawing.Point(420, 168)
$lblAdditionalHint.Size = New-Object System.Drawing.Size(240, 15)
$lblAdditionalHint.Text = "(comma-separated: spa, fre, rus)"
$lblAdditionalHint.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Italic)
$lblAdditionalHint.ForeColor = [System.Drawing.Color]::DarkOrange
$lblAdditionalHint.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblAdditionalHint)

# Backup
$lblBackup = New-Object System.Windows.Forms.Label
$lblBackup.Location = New-Object System.Drawing.Point(20, 193)
$lblBackup.Size = New-Object System.Drawing.Size(640, 20)
$lblBackup.Text = "3. Backup Location:"
$lblBackup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblBackup.ForeColor = $lightText
$lblBackup.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblBackup)

$txtBackup = New-Object System.Windows.Forms.TextBox
$txtBackup.Location = New-Object System.Drawing.Point(20, 218)
$txtBackup.Size = New-Object System.Drawing.Size(540, 25)
$txtBackup.Text = $backupRoot
$txtBackup.BackColor = $darkControl
$txtBackup.ForeColor = $lightText
$txtBackup.BorderStyle = "FixedSingle"
$form.Controls.Add($txtBackup)

$btnBrowseBackup = New-Object System.Windows.Forms.Button
$btnBrowseBackup.Location = New-Object System.Drawing.Point(570, 216)
$btnBrowseBackup.Size = New-Object System.Drawing.Size(90, 27)
$btnBrowseBackup.Text = "Browse..."
$btnBrowseBackup.BackColor = $darkControl
$btnBrowseBackup.ForeColor = $lightText
$btnBrowseBackup.FlatStyle = "Flat"
$btnBrowseBackup.Add_Click({
    # Enumerate all available drives (A-Z) including mapped network drives
    $availableDrives = @()
    
    try {
        # Use .NET DriveInfo instead of WMI (more reliable in compiled exes)
        $allDrives = @([System.IO.DriveInfo]::GetDrives())
        
        foreach ($drive in $allDrives) {
            if (-not $drive.IsReady) { continue }
            
            $driveLetter = $drive.Name.TrimEnd('\\')
            $driveType = ""
            $driveLabel = ""
            
            switch ($drive.DriveType.ToString()) {
                'Fixed' { $driveType = "Local" }
                'Network' { 
                    $driveType = "Network"
                    # Try to get network path using WMI for this specific drive
                    try {
                        $wmiDrive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$($driveLetter.TrimEnd(':')):'" -ErrorAction SilentlyContinue
                        if ($wmiDrive -and $wmiDrive.ProviderName) {
                            $driveLabel = " - $($wmiDrive.ProviderName)"
                        }
                    } catch { }
                }
                'CDRom' { $driveType = "CD/DVD" }
                'Removable' { $driveType = "Removable" }
                default { $driveType = $drive.DriveType.ToString() }
            }
            
            $availableDrives += "$driveLetter ($driveType)$driveLabel"
        }
    } catch {
        # Fallback to Test-Path method if all else fails
        65..90 | ForEach-Object {
            $driveLetter = [char]$_ + ":"
            if (Test-Path $driveLetter -ErrorAction SilentlyContinue) {
                $availableDrives += "$driveLetter (Drive)"
            }
        }
    }
    
        # Show available drives in status bar (shorter message)
    if ($availableDrives.Count -gt 0) {
        Update-Status "Detected $($availableDrives.Count) drives (see dialog for details)"
    }
    
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = "Select backup location for archived subtitle files`r`n`r`nDetected Drives:`r`n$($availableDrives -join "`r`n")`r`n`r`nFor network paths, you can also type UNC path manually (\\server\share)"
    $fb.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    $fb.ShowNewFolderButton = $true
    
    if ($fb.ShowDialog() -eq "OK") { 
        $txtBackup.Text = $fb.SelectedPath 
        Update-Status "Ready"
    } else {
        Update-Status "Ready"
    }
    [System.Windows.Forms.Application]::DoEvents()
})
$form.Controls.Add($btnBrowseBackup)

# Options
$lblOptions = New-Object System.Windows.Forms.Label
$lblOptions.Location = New-Object System.Drawing.Point(20, 258)
$lblOptions.Size = New-Object System.Drawing.Size(640, 20)
$lblOptions.Text = "4. Options:"
$lblOptions.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblOptions.ForeColor = $lightText
$lblOptions.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblOptions)

$chkDryRun = New-Object System.Windows.Forms.CheckBox
$chkDryRun.Location = New-Object System.Drawing.Point(20, 283)
$chkDryRun.Size = New-Object System.Drawing.Size(300, 25)
$chkDryRun.Text = "Dry Run (preview only, no changes)"
$chkDryRun.Checked = $true
$chkDryRun.ForeColor = $lightText
$chkDryRun.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($chkDryRun)

$chkCleanup = New-Object System.Windows.Forms.CheckBox
$chkCleanup.Location = New-Object System.Drawing.Point(20, 308)
$chkCleanup.Size = New-Object System.Drawing.Size(300, 25)
$chkCleanup.Text = "Clean up empty folders"
$chkCleanup.Checked = $true
$chkCleanup.ForeColor = $lightText
$chkCleanup.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($chkCleanup)

$chkCSV = New-Object System.Windows.Forms.CheckBox
$chkCSV.Location = New-Object System.Drawing.Point(340, 283)
$chkCSV.Size = New-Object System.Drawing.Size(300, 25)
$chkCSV.Text = "Generate CSV report"
$chkCSV.Checked = $true
$chkCSV.ForeColor = $lightText
$chkCSV.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($chkCSV)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 348)
$progressBar.Size = New-Object System.Drawing.Size(640, 25)
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

# Log - GRAY BACKGROUND
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Location = New-Object System.Drawing.Point(20, 383)
$lblLog.Size = New-Object System.Drawing.Size(640, 20)
$lblLog.Text = "Output Log:"
$lblLog.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblLog.ForeColor = $lightText
$lblLog.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblLog)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 408)
$txtLog.Size = New-Object System.Drawing.Size(640, 150)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8)
$txtLog.BackColor = $grayBg
$txtLog.ForeColor = $lightText
$txtLog.BorderStyle = "FixedSingle"
$form.Controls.Add($txtLog)

# Buttons - ALL HAVE WHITE TEXT
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(250, 573)
$btnStart.Size = New-Object System.Drawing.Size(100, 35)
$btnStart.Text = "Start"
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = "Flat"
$btnStart.FlatAppearance.BorderSize = 0
$btnStart.UseVisualStyleBackColor = $false
$form.Controls.Add($btnStart)

$btnPause = New-Object System.Windows.Forms.Button
$btnPause.Location = New-Object System.Drawing.Point(360, 573)
$btnPause.Size = New-Object System.Drawing.Size(100, 35)
$btnPause.Text = "Pause"
$btnPause.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnPause.BackColor = [System.Drawing.Color]::FromArgb(255, 215, 0)
$btnPause.ForeColor = [System.Drawing.Color]::White
$btnPause.FlatStyle = "Flat"
$btnPause.FlatAppearance.BorderSize = 0
$btnPause.UseVisualStyleBackColor = $false
$btnPause.Enabled = $false
$btnPause.Add_Click({
    if ($script:pauseRequested) {
        $script:pauseRequested = $false
        $btnPause.Text = "Pause"
        $btnPause.BackColor = [System.Drawing.Color]::FromArgb(255, 215, 0)
        Write-Log ">>> Resumed"
    } else {
        $script:pauseRequested = $true
        $btnPause.Text = "Resume"
        $btnPause.BackColor = [System.Drawing.Color]::FromArgb(50, 205, 50)
        Write-Log ">>> Paused"
    }
})
$form.Controls.Add($btnPause)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Location = New-Object System.Drawing.Point(470, 573)
$btnStop.Size = New-Object System.Drawing.Size(90, 35)
$btnStop.Text = "Stop"
$btnStop.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnStop.BackColor = [System.Drawing.Color]::FromArgb(220, 20, 60)
$btnStop.ForeColor = [System.Drawing.Color]::White
$btnStop.FlatStyle = "Flat"
$btnStop.FlatAppearance.BorderSize = 0
$btnStop.UseVisualStyleBackColor = $false
$btnStop.Enabled = $false
$btnStop.Add_Click({
    $script:stopRequested = $true
    $script:pauseRequested = $false
    Write-Log ">>> STOP requested"
    Update-Status "Stopping..."
    $btnStop.Enabled = $false
    $btnPause.Enabled = $false
    [System.Windows.Forms.Application]::DoEvents()
})
$form.Controls.Add($btnStop)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Location = New-Object System.Drawing.Point(570, 573)
$btnExit.Size = New-Object System.Drawing.Size(90, 35)
$btnExit.Text = "Exit"
$btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnExit.BackColor = [System.Drawing.Color]::FromArgb(255, 140, 0)
$btnExit.ForeColor = [System.Drawing.Color]::White
$btnExit.FlatStyle = "Flat"
$btnExit.FlatAppearance.BorderSize = 0
$btnExit.UseVisualStyleBackColor = $false
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# Status
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 618)
$lblStatus.Size = New-Object System.Drawing.Size(640, 25)
$lblStatus.Text = "Ready"
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Italic)
$lblStatus.ForeColor = $lightText
$lblStatus.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($lblStatus)

function Write-Log {
    param([string]$Message)
    $txtLog.AppendText("$Message`r`n")
    $txtLog.Select($txtLog.Text.Length, 0)
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-Status {
    param([string]$Message)
    $lblStatus.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-Progress {
    param([int]$Percent)
    if ($Percent -ge 0 -and $Percent -le 100) {
        $progressBar.Value = $Percent
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Check-PauseStop {
    while ($script:pauseRequested -and -not $script:stopRequested) {
        Update-Status "⏸ PAUSED"
        [System.Threading.Thread]::Sleep(50)
        [System.Windows.Forms.Application]::DoEvents()
    }
    return $script:stopRequested
}

function Get-FilesWithDepthLimit {
    param([string]$Path, [string]$Filter, [int]$MaxDepth)
    
    $baseDepth = ($Path.TrimEnd('\').Split('\').Count)
    
    if ($MaxDepth -eq -1) {
        return Get-ChildItem -Path $Path -Filter $Filter -Recurse -File -ErrorAction SilentlyContinue
    } else {
        return Get-ChildItem -Path $Path -Filter $Filter -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $currentDepth = ($_.DirectoryName.Split('\').Count)
            ($currentDepth - $baseDepth) -le $MaxDepth
        }
    }
}

function Remove-EmptyFolders {
    param([string]$Path)
    
    $removed = 0
    $retries = 3
    
    for ($r = 0; $r -lt $retries; $r++) {
        $emptyDirs = @()
        
        Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue | 
            Sort-Object FullName -Descending | ForEach-Object {
            if ($script:stopRequested) { return }
            
            $skip = $false
            foreach ($ex in $excludeFolders) {
                if ($_.FullName -like "*$ex*") { $skip = $true; break }
            }
            
            if (-not $skip) {
                $items = @(Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue)
                if ($items.Count -eq 0) {
                    $emptyDirs += $_
                }
            }
        }
        
        if ($emptyDirs.Count -eq 0) { break }
        
        foreach ($dir in $emptyDirs) {
            if ($script:stopRequested) { break }
            try {
                Remove-Item -Path $dir.FullName -Force -ErrorAction Stop
                $removed++
            } catch {
                # Folder may be in use or locked
            }
        }
    }
    
    return $removed
}

function Generate-CSVReport {
    param(
        [array]$AllFiles,
        [array]$ArchivedFiles,
        [string]$SourcePath,
        [string]$BackupPath,
        [array]$KeepLanguages,
        [bool]$IsDryRun
    )
    
    try {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $csvPath = Join-Path $SourcePath "SubScrub_Report_$timestamp.csv"
        
        $report = @()
        
        foreach ($file in $AllFiles) {
            if ($script:stopRequested) { break }
            
            $archived = $ArchivedFiles -contains $file
            $action = if ($archived) { if ($IsDryRun) { "Would Archive" } else { "Archived" } } else { "Kept" }
            
            $detectedLang = "Unknown"
            foreach ($lang in $KeepLanguages) {
                if ($file.Name -match $lang) {
                    $detectedLang = $lang
                    break
                }
            }
            
            $report += [PSCustomObject]@{
                FileName = $file.Name
                FilePath = $file.DirectoryName
                SizeKB = [math]::Round($file.Length / 1KB, 2)
                DetectedLanguage = $detectedLang
                Action = $action
                Extension = $file.Extension
                LastModified = $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
        
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        return $csvPath
        
    } catch {
        return $null
    }
}

$btnStart.Add_Click({
    try {
        $script:stopRequested = $false
        $script:pauseRequested = $false
        
        # DISABLE ALL CONTROLS TO PREVENT FREEZING
        $txtSource.Enabled = $false
        $btnBrowseSource.Enabled = $false
        $cmbDepth.Enabled = $false
        $cmbLanguage.Enabled = $false
        $txtAdditional.Enabled = $false
        $txtBackup.Enabled = $false
        $btnBrowseBackup.Enabled = $false
        $chkDryRun.Enabled = $false
        $chkCleanup.Enabled = $false
        $chkCSV.Enabled = $false
        
        $btnStart.Enabled = $false
        $btnPause.Enabled = $true
        $btnStop.Enabled = $true
        $btnExit.Enabled = $false
        
        $btnStart.BackColor = [System.Drawing.Color]::FromArgb(57, 255, 20)
        $btnStart.ForeColor = [System.Drawing.Color]::Black
        $btnStart.Text = "Running..."
        
        $txtLog.Clear()
        $progressBar.Value = 0
        
        Write-Log "=== SubScrub v1.1 ==="
        Write-Log ""
        
        $sourcePath = $txtSource.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($sourcePath) -or -not (Test-Path $sourcePath)) {
            Write-Log "ERROR: Invalid path"
            return
        }
        
        $depthLimit = -1
        $depthText = $cmbDepth.SelectedItem.ToString()
        if ($depthText -eq "3 levels") { $depthLimit = 3 }
        elseif ($depthText -eq "5 levels") { $depthLimit = 5 }
        elseif ($depthText -eq "10 levels") { $depthLimit = 10 }
        
        Write-Log "Source: $sourcePath"
        Write-Log "Backup: $($txtBackup.Text)"
        Write-Log "Depth: $(if ($depthLimit -eq -1) { 'Unlimited' } else { "$depthLimit levels" })"
        Write-Log ""
        
        $keepLanguages.Clear()
        $lang = $cmbLanguage.SelectedItem.ToString().ToLower()
        $map = @{'english'='eng';'spanish'='spa';'french'='fre';'german'='ger';'italian'='ita';'portuguese'='por';'japanese'='jpn';'chinese'='chi';'korean'='kor';'russian'='rus';'dutch'='dut';'polish'='pol'}
        if ($map.ContainsKey($lang)) {
            foreach ($l in $languageMappings[$map[$lang]]) { $keepLanguages.Add($l) }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($txtAdditional.Text)) {
            $txtAdditional.Text.Split(',') | ForEach-Object {
                $code = $_.Trim().ToLower()
                if (-not [string]::IsNullOrWhiteSpace($code) -and -not $keepLanguages.Contains($code)) {
                    $keepLanguages.Add($code)
                }
            }
        }
        
        Write-Log "Languages: $($keepLanguages -join ', ')"
        Write-Log ""
        
        Update-Status "Scanning..."
        Update-Progress 5
        
        $allFiles = @()
        $fc = 0
        $skipped = 0
        $extCount = $extensions.Count
        
        for ($e = 0; $e -lt $extCount; $e++) {
            if (Check-PauseStop) {
                Write-Log "*** STOPPED ***"
                break
            }
            
            $ext = $extensions[$e]
            Update-Status "Scanning *$ext ($($e+1)/$extCount)..."
            Update-Progress ([int](5 + (($e / $extCount) * 40)))
            
            try {
                Get-FilesWithDepthLimit -Path $sourcePath -Filter $ext -MaxDepth $depthLimit | ForEach-Object {
                    if ($script:stopRequested) { return }
                    
                    $skip = $false
                    foreach ($ex in $excludeFolders) {
                        if ($_.FullName -like "*$ex*") { $skip = $true; $skipped++; break }
                    }
                    if (-not $skip -and $_.Length -gt ($minFileSizeKB * 1KB)) {
                        $allFiles += $_
                        $fc++
                        if ($fc % 5 -eq 0) {
                            if (Check-PauseStop) { return }
                            Update-Status "Found $fc files..."
                        }
                    }
                }
            } catch {
                Write-Log "Warning: $ext error"
            }
        }
        
        if ($script:stopRequested) {
            Write-Log "Stopped"
            return
        }
        
        Update-Progress 45
        if ($skipped -gt 0) { Write-Log "Skipped $skipped backup files" }
        Write-Log "Found $($allFiles.Count) files"
        Write-Log ""
        
        if ($allFiles.Count -eq 0) {
            Write-Log "No files found"
            return
        }
        
        Update-Status "Analyzing..."
        $toArchive = @()
        
        for ($i = 0; $i -lt $allFiles.Count; $i++) {
            if (Check-PauseStop) {
                Write-Log "*** STOPPED ***"
                break
            }
            
            $keep = $false
            foreach ($l in $keepLanguages) {
                if ($allFiles[$i].Name -match $l) { $keep = $true; break }
            }
            if (-not $keep) { $toArchive += $allFiles[$i] }
            
            if ($i % 10 -eq 0) {
                Update-Progress ([int](45 + (($i / $allFiles.Count) * 25)))
            }
        }
        
        if ($script:stopRequested) {
            Write-Log "Stopped"
            return
        }
        
        Update-Progress 70
        Write-Log "Keep: $($allFiles.Count - $toArchive.Count)"
        Write-Log "Archive: $($toArchive.Count)"
        Write-Log ""
        
        if ($toArchive.Count -eq 0) {
            Write-Log "Nothing to archive"
            Update-Progress 100
            [System.Media.SystemSounds]::Asterisk.Play()
            return
        }
        
                if ($chkDryRun.Checked) {
            Write-Log "=== DRY RUN ==="
            $toArchive | Select-Object -First 20 | ForEach-Object { Write-Log "  $($_.Name)" }
            if ($toArchive.Count -gt 20) { Write-Log "  ... $($toArchive.Count - 20) more" }
            Write-Log ""
            
            # GENERATE CSV FOR DRY RUN
            if ($chkCSV.Checked) {
                Write-Log "Generating CSV report..."
                Update-Status "Generating CSV report..."
                Update-Progress 85
                $csvPath = Generate-CSVReport -AllFiles $allFiles -ArchivedFiles $toArchive -SourcePath $sourcePath -BackupPath "N/A" -KeepLanguages $keepLanguages -IsDryRun $true
                if ($csvPath) {
                    Write-Log "CSV saved: $csvPath"
                } else {
                    Write-Log "CSV generation failed"
                }
                Write-Log ""
            }
            
            Write-Log "*** COMPLETE ***"
            Update-Status "Dry run complete"
            Update-Progress 100
            [System.Media.SystemSounds]::Asterisk.Play()
        } else {
            $backup = Join-Path $txtBackup.Text "Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            New-Item -ItemType Directory -Path $backup -Force | Out-Null
            Write-Log "Backup: $backup"
            Write-Log ""
            
            $ok = 0
            $fail = 0
            
            for ($i = 0; $i -lt $toArchive.Count; $i++) {
                if (Check-PauseStop) {
                    Write-Log "*** STOPPED - Archived $ok ***"
                    break
                }
                
                $f = $toArchive[$i]
                Update-Progress ([int](70 + (($i / $toArchive.Count) * 30)))
                Update-Status "Archiving $($i+1)/$($toArchive.Count)..."
                
                try {
                    $rel = $f.FullName.Substring($sourcePath.Length).TrimStart('\')
                    $dest = Join-Path $backup $rel
                    $dir = Split-Path $dest -Parent
                    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                    Move-Item -Path $f.FullName -Destination $dest -Force -ErrorAction Stop
                    $ok++
                    if ($i % 3 -eq 0) { Write-Log "Archived: $($f.Name)" }
                } catch {
                    $fail++
                    if ($fail -le 5) { Write-Log "ERROR: $($f.Name)" }
                }
            }
            
                        if (-not $script:stopRequested) {
                Update-Progress 95
                Write-Log ""
                Write-Log "=== COMPLETE ==="
                Write-Log "Success: $ok"
                if ($fail -gt 0) { Write-Log "Failed: $fail" }
                Write-Log ""
                
                # CLEAN UP EMPTY FOLDERS
                if ($chkCleanup.Checked -and -not $chkDryRun.Checked) {
                    Write-Log "Cleaning empty folders..."
                    Update-Status "Cleaning empty folders..."
                    $removed = Remove-EmptyFolders -Path $sourcePath
                    if ($removed -gt 0) {
                        Write-Log "Removed $removed empty folders"
                    } else {
                        Write-Log "No empty folders found"
                    }
                    Write-Log ""
                }
                
                # GENERATE CSV REPORT
                if ($chkCSV.Checked) {
                    Write-Log "Generating CSV report..."
                    Update-Status "Generating CSV report..."
                    $csvPath = Generate-CSVReport -AllFiles $allFiles -ArchivedFiles $toArchive -SourcePath $sourcePath -BackupPath $backup -KeepLanguages $keepLanguages -IsDryRun $chkDryRun.Checked
                    if ($csvPath) {
                        Write-Log "CSV saved: $csvPath"
                    } else {
                        Write-Log "CSV generation failed"
                    }
                    Write-Log ""
                }
                
                Update-Progress 100
                Update-Status "Complete - $ok archived"
                [System.Media.SystemSounds]::Asterisk.Play()
            }
        }
        
    } catch {
        Write-Log "ERROR: $_"
    } finally {
        # RE-ENABLE ALL CONTROLS
        $txtSource.Enabled = $true
        $btnBrowseSource.Enabled = $true
        $cmbDepth.Enabled = $true
        $cmbLanguage.Enabled = $true
        $txtAdditional.Enabled = $true
        $txtBackup.Enabled = $true
        $btnBrowseBackup.Enabled = $true
        $chkDryRun.Enabled = $true
        $chkCleanup.Enabled = $true
        $chkCSV.Enabled = $true
        
        $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnStart.ForeColor = [System.Drawing.Color]::White
        $btnStart.Text = "Start"
        $btnStart.Enabled = $true
        $btnPause.Enabled = $false
        $btnPause.Text = "Pause"
        $btnPause.BackColor = [System.Drawing.Color]::FromArgb(255, 215, 0)
        $btnStop.Enabled = $false
        $btnExit.Enabled = $true
        
        # RESET PROGRESS BAR ON STOP
        if ($script:stopRequested) {
            $progressBar.Value = 0
            Update-Status "Stopped"
        } elseif ($progressBar.Value -ne 100) {
            $progressBar.Value = 0
        }
        
        if ($lblStatus.Text -notmatch 'Complete|Stopped') {
            Update-Status "Ready"
        }
    }
})

[void]$form.ShowDialog()
