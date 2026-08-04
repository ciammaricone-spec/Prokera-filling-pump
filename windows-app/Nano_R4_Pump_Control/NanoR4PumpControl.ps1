Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Ports

$script:port = $null
$script:lastSteps = 32000
$script:lastSpeed = 210
$script:lastDone = 0
$script:purgeMode = $false
$appTitle = "V3-2 Nano R4 Peristaltic filling by G.C."

$colorBg = [System.Drawing.Color]::FromArgb(22, 25, 30)
$colorPanel = [System.Drawing.Color]::FromArgb(34, 39, 46)
$colorPanel2 = [System.Drawing.Color]::FromArgb(43, 49, 58)
$colorText = [System.Drawing.Color]::FromArgb(235, 240, 245)
$colorMuted = [System.Drawing.Color]::FromArgb(150, 162, 176)
$colorWhite = [System.Drawing.Color]::White
$colorGreen = [System.Drawing.Color]::FromArgb(46, 204, 113)
$colorYellow = [System.Drawing.Color]::FromArgb(245, 166, 35)
$colorOrange = [System.Drawing.Color]::FromArgb(242, 133, 30)
$colorRed = [System.Drawing.Color]::FromArgb(235, 87, 87)
$colorBlue = [System.Drawing.Color]::FromArgb(74, 144, 226)
$colorRunText = [System.Drawing.Color]::FromArgb(12, 25, 16)
$colorReadText = [System.Drawing.Color]::FromArgb(35, 24, 4)

function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [int]$Size = 10,
        [System.Drawing.Color]$Color = $colorText,
        [string]$Weight = "Regular"
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($W, $H)
    $label.ForeColor = $Color
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.Font = New-Object System.Drawing.Font("Segoe UI", $Size, ([System.Drawing.FontStyle]::$Weight))
    return $label
}

function Style-Button {
    param(
        [System.Windows.Forms.Button]$Button,
        [System.Drawing.Color]$Back,
        [System.Drawing.Color]$Fore = [System.Drawing.Color]::White,
        [int]$Size = 12,
        [string]$Weight = "Bold"
    )

    $Button.FlatStyle = "Flat"
    $Button.UseVisualStyleBackColor = $false
    $Button.FlatAppearance.BorderSize = 0
    $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Min(255, $Back.R + 18),
        [Math]::Min(255, $Back.G + 18),
        [Math]::Min(255, $Back.B + 18)
    )
    $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Max(0, $Back.R - 18),
        [Math]::Max(0, $Back.G - 18),
        [Math]::Max(0, $Back.B - 18)
    )
    $Button.BackColor = $Back
    $Button.ForeColor = $Fore
    $Button.Font = New-Object System.Drawing.Font("Segoe UI", $Size, ([System.Drawing.FontStyle]::$Weight))
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
}

function Style-Numeric {
    param([System.Windows.Forms.NumericUpDown]$Control)

    $Control.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 250)
    $Control.ForeColor = [System.Drawing.Color]::FromArgb(20, 25, 30)
    $Control.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $Control.TextAlign = "Center"
}

function Add-Log {
    param([string]$Text)
    $time = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$time] $Text`r`n")
}

function Set-DisplayState {
    param(
        [string]$State,
        [System.Drawing.Color]$Color
    )

    $lblState.Text = $State
    $lblState.ForeColor = $Color
    $displayPanel.BackColor = if ($State -eq "RUNNING") {
        [System.Drawing.Color]::FromArgb(48, 38, 20)
    }
    elseif ($State -eq "IDLE") {
        [System.Drawing.Color]::FromArgb(20, 44, 31)
    }
    else {
        [System.Drawing.Color]::FromArgb(44, 44, 44)
    }
}

function Update-DisplayValues {
    $lblStepsValue.Text = ("{0:N0}" -f $script:lastSteps)
    $lblSpeedValue.Text = ("{0:N0} us" -f $script:lastSpeed)
    $lblDoneValue.Text = ("{0:N0}" -f $script:lastDone)

    if ($script:lastSteps -gt 0) {
        $pct = [int][Math]::Min(100, [Math]::Round(($script:lastDone / $script:lastSteps) * 100))
        $progress.Value = [Math]::Max(0, $pct)
        $lblProgress.Text = "$pct%"
    }
    else {
        $progress.Value = 0
        $lblProgress.Text = "0%"
    }
}

function Get-SelectedPortName {
    if ($comboPorts.SelectedItem) {
        return [string]$comboPorts.SelectedItem
    }
    return ""
}

function Refresh-Ports {
    $selected = Get-SelectedPortName
    $comboPorts.Items.Clear()
    [System.IO.Ports.SerialPort]::GetPortNames() |
        Sort-Object |
        ForEach-Object { [void]$comboPorts.Items.Add($_) }

    if ($selected -and $comboPorts.Items.Contains($selected)) {
        $comboPorts.SelectedItem = $selected
    }
    elseif ($comboPorts.Items.Count -gt 0) {
        $comboPorts.SelectedIndex = 0
    }
}

function Reset-SerialConnection {
    param([string]$Reason)

    Add-Log $Reason

    try {
        if ($script:port -and $script:port.IsOpen) {
            $script:port.Close()
        }
    }
    catch {
    }

    try {
        if ($script:port) {
            $script:port.Dispose()
        }
    }
    catch {
    }

    $script:port = $null
    Set-ConnectedUi $false
    Refresh-Ports
}

function Send-Command {
    param(
        [string]$Command,
        [bool]$Quiet = $false
    )

    if (-not $script:port -or -not $script:port.IsOpen) {
        Add-Log "No conectado."
        return
    }

    try {
        $script:port.WriteLine($Command)
        if (-not $Quiet) {
            Add-Log "> $Command"
        }
    }
    catch {
        Reset-SerialConnection ("Error enviando comando: " + $_.Exception.Message + " Cierra otras apps que usen el COM y reconecta.")
    }
}

function Apply-StatusLine {
    param([string]$Line)

    if (-not $script:purgeMode -and $Line -match "STEPS=(\d+)") {
        $script:lastSteps = [int]$matches[1]
        if ($script:lastSteps -ge $numSteps.Minimum -and $script:lastSteps -le $numSteps.Maximum) {
            $numSteps.Value = [decimal]$script:lastSteps
        }
    }

    if ($Line -match "SPEED_US=(\d+)") {
        $script:lastSpeed = [int]$matches[1]
        if ($script:lastSpeed -ge $numSpeed.Minimum -and $script:lastSpeed -le $numSpeed.Maximum) {
            $numSpeed.Value = [decimal]$script:lastSpeed
        }
    }

    if ($Line -match "DONE=(\d+)") {
        $script:lastDone = [int]$matches[1]
    }

    if ($Line -match "STATUS IDLE|RUN COMPLETE|RUN STOP") {
        if ($Line -match "RUN COMPLETE") {
            $script:lastDone = $script:lastSteps
        }
        $script:purgeMode = $false
        Set-DisplayState "IDLE" $colorGreen
    }
    elseif ($Line -match "STATUS RUNNING|RUN START") {
        if ($Line -match "RUN START") {
            $script:lastDone = 0
        }
        Set-DisplayState "RUNNING" $colorYellow
    }
    elseif ($Line -match "^ERR") {
        Set-DisplayState "ERROR" $colorRed
    }

    Update-DisplayValues
}

function Read-Serial {
    if (-not $script:port -or -not $script:port.IsOpen) {
        return
    }

    try {
        while ($script:port.BytesToRead -gt 0) {
            $line = $script:port.ReadLine().Trim()

            if ($line.Length -gt 0) {
                Add-Log "< $line"
                Apply-StatusLine $line
            }
        }
    }
    catch [System.TimeoutException] {
    }
    catch {
        Reset-SerialConnection ("Error leyendo serial: " + $_.Exception.Message + " Cierra otras apps que usen el COM y reconecta.")
    }
}

function Set-ConnectedUi {
    param([bool]$Connected)

    $btnConnect.Enabled = -not $Connected
    $btnDisconnect.Enabled = $Connected
    $btnSet.Enabled = $Connected
    $btnGet.Enabled = $true
    $btnRun.Enabled = $true
    $btnPurge.Enabled = $true
    $btnStop.Enabled = $true
    $comboPorts.Enabled = -not $Connected
    $btnRefresh.Enabled = -not $Connected

    Style-Button $btnRun $colorGreen $colorRunText 18 "Bold"
    Style-Button $btnPurge $colorOrange $colorWhite 12 "Bold"
    Style-Button $btnGet $colorYellow $colorReadText 10 "Bold"
    Style-Button $btnStop $colorRed $colorWhite 12 "Bold"
    $btnRun.Invalidate()
    $btnPurge.Invalidate()
    $btnGet.Invalidate()
    $btnStop.Invalidate()

    if (-not $Connected) {
        Set-DisplayState "DISCONNECTED" $colorMuted
    }
}

function Connect-Port {
    $name = Get-SelectedPortName

    if (-not $name) {
        Add-Log "Selecciona un COM port."
        return
    }

    try {
        $script:port = New-Object System.IO.Ports.SerialPort $name, 115200, None, 8, One
        $script:port.NewLine = "`n"
        $script:port.ReadTimeout = 250
        $script:port.WriteTimeout = 2000
        $script:port.DtrEnable = $true
        $script:port.RtsEnable = $true
        $script:port.Open()
        $script:port.DiscardInBuffer()
        $script:port.DiscardOutBuffer()

        Set-ConnectedUi $true
        Set-DisplayState "CONNECTING" $colorBlue

        Add-Log "Conectado a $name."
        Start-Sleep -Milliseconds 2500
        Send-Command "GET"
    }
    catch {
        Add-Log "No se pudo conectar: $($_.Exception.Message)"
        if ($script:port) {
            $script:port.Dispose()
            $script:port = $null
        }
        Set-ConnectedUi $false
    }
}

function Disconnect-Port {
    try {
        if ($script:port -and $script:port.IsOpen) {
            $script:port.Close()
        }
        if ($script:port) {
            $script:port.Dispose()
            $script:port = $null
        }
        Add-Log "Desconectado."
    }
    catch {
        Add-Log "Error desconectando: $($_.Exception.Message)"
    }

    Set-ConnectedUi $false
}

$form = New-Object System.Windows.Forms.Form
$form.Text = $appTitle
$form.Size = New-Object System.Drawing.Size(980, 675)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(980, 675)
$form.BackColor = $colorBg
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(980, 62)
$header.BackColor = [System.Drawing.Color]::FromArgb(16, 18, 22)
$header.Anchor = "Top,Left,Right"
$form.Controls.Add($header)

$title = New-Label $appTitle 20 14 460 32 16 $colorText "Bold"
$header.Controls.Add($title)

$lblPort = New-Label "COM" 500 20 38 24 10 $colorMuted
$header.Controls.Add($lblPort)

$comboPorts = New-Object System.Windows.Forms.ComboBox
$comboPorts.DropDownStyle = "DropDownList"
$comboPorts.Location = New-Object System.Drawing.Point(540, 17)
$comboPorts.Size = New-Object System.Drawing.Size(100, 28)
$header.Controls.Add($comboPorts)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(648, 16)
$btnRefresh.Size = New-Object System.Drawing.Size(82, 30)
Style-Button $btnRefresh $colorPanel2 $colorText 9 "Regular"
$btnRefresh.Add_Click({ Refresh-Ports })
$header.Controls.Add($btnRefresh)

$btnConnect = New-Object System.Windows.Forms.Button
$btnConnect.Text = "Connect"
$btnConnect.Location = New-Object System.Drawing.Point(740, 16)
$btnConnect.Size = New-Object System.Drawing.Size(82, 30)
Style-Button $btnConnect $colorBlue
$btnConnect.Add_Click({ Connect-Port })
$header.Controls.Add($btnConnect)

$btnDisconnect = New-Object System.Windows.Forms.Button
$btnDisconnect.Text = "Disconnect"
$btnDisconnect.Location = New-Object System.Drawing.Point(830, 16)
$btnDisconnect.Size = New-Object System.Drawing.Size(90, 30)
Style-Button $btnDisconnect $colorOrange $colorWhite 9 "Bold"
$btnDisconnect.Enabled = $false
$btnDisconnect.Add_Click({ Disconnect-Port })
$header.Controls.Add($btnDisconnect)

$displayPanel = New-Object System.Windows.Forms.Panel
$displayPanel.Location = New-Object System.Drawing.Point(20, 82)
$displayPanel.Size = New-Object System.Drawing.Size(940, 132)
$displayPanel.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 44)
$displayPanel.Anchor = "Top,Left,Right"
$form.Controls.Add($displayPanel)

$lblDisplayTitle = New-Label "MACHINE STATE" 22 16 180 22 10 $colorMuted "Bold"
$displayPanel.Controls.Add($lblDisplayTitle)

$lblState = New-Label "DISCONNECTED" 20 42 430 58 32 $colorMuted "Bold"
$displayPanel.Controls.Add($lblState)

$lblProgressTitle = New-Label "Progress" 500 22 100 22 10 $colorMuted
$displayPanel.Controls.Add($lblProgressTitle)

$lblProgress = New-Label "0%" 635 18 70 30 16 $colorText "Bold"
$lblProgress.TextAlign = "MiddleRight"
$displayPanel.Controls.Add($lblProgress)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(500, 58)
$progress.Size = New-Object System.Drawing.Size(210, 28)
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Value = 0
$displayPanel.Controls.Add($progress)

$settingsPanel = New-Object System.Windows.Forms.Panel
$settingsPanel.Location = New-Object System.Drawing.Point(20, 232)
$settingsPanel.Size = New-Object System.Drawing.Size(360, 170)
$settingsPanel.BackColor = $colorPanel
$form.Controls.Add($settingsPanel)

$settingsTitle = New-Label "SETTINGS" 18 14 160 24 11 $colorMuted "Bold"
$settingsPanel.Controls.Add($settingsTitle)

$lblSteps = New-Label "Steps" 20 52 90 24 11 $colorText
$settingsPanel.Controls.Add($lblSteps)

$numSteps = New-Object System.Windows.Forms.NumericUpDown
$numSteps.Location = New-Object System.Drawing.Point(120, 45)
$numSteps.Size = New-Object System.Drawing.Size(200, 36)
$numSteps.Minimum = 10
$numSteps.Maximum = 50000
$numSteps.Increment = 100
$numSteps.Value = 32000
Style-Numeric $numSteps
$settingsPanel.Controls.Add($numSteps)

$lblSpeed = New-Label "Speed us" 20 104 90 24 11 $colorText
$settingsPanel.Controls.Add($lblSpeed)

$numSpeed = New-Object System.Windows.Forms.NumericUpDown
$numSpeed.Location = New-Object System.Drawing.Point(120, 97)
$numSpeed.Size = New-Object System.Drawing.Size(200, 36)
$numSpeed.Minimum = 210
$numSpeed.Maximum = 5000
$numSpeed.Increment = 10
$numSpeed.Value = 210
Style-Numeric $numSpeed
$settingsPanel.Controls.Add($numSpeed)

$readoutPanel = New-Object System.Windows.Forms.Panel
$readoutPanel.Location = New-Object System.Drawing.Point(400, 232)
$readoutPanel.Size = New-Object System.Drawing.Size(360, 170)
$readoutPanel.BackColor = $colorPanel
$form.Controls.Add($readoutPanel)

$readoutTitle = New-Label "DISPLAY" 18 14 160 24 11 $colorMuted "Bold"
$readoutPanel.Controls.Add($readoutTitle)

$lblStepsName = New-Label "Steps" 20 48 82 22 10 $colorMuted
$readoutPanel.Controls.Add($lblStepsName)
$lblStepsValue = New-Label "32,000" 110 42 210 34 18 $colorText "Bold"
$lblStepsValue.TextAlign = "MiddleRight"
$readoutPanel.Controls.Add($lblStepsValue)

$lblSpeedName = New-Label "Speed" 20 88 82 22 10 $colorMuted
$readoutPanel.Controls.Add($lblSpeedName)
$lblSpeedValue = New-Label "210 us" 110 82 210 34 18 $colorText "Bold"
$lblSpeedValue.TextAlign = "MiddleRight"
$readoutPanel.Controls.Add($lblSpeedValue)

$lblDoneName = New-Label "Done" 20 128 82 22 10 $colorMuted
$readoutPanel.Controls.Add($lblDoneName)
$lblDoneValue = New-Label "0" 110 122 210 34 18 $colorText "Bold"
$lblDoneValue.TextAlign = "MiddleRight"
$readoutPanel.Controls.Add($lblDoneValue)

$buttonsPanel = New-Object System.Windows.Forms.Panel
$buttonsPanel.Location = New-Object System.Drawing.Point(20, 420)
$buttonsPanel.Size = New-Object System.Drawing.Size(940, 76)
$buttonsPanel.BackColor = $colorPanel
$form.Controls.Add($buttonsPanel)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "RUN"
$btnRun.Location = New-Object System.Drawing.Point(18, 14)
$btnRun.Size = New-Object System.Drawing.Size(128, 48)
Style-Button $btnRun $colorGreen $colorRunText 18 "Bold"
$btnRun.Enabled = $false
$btnRun.Add_Click({
    $script:lastSteps = [int]$numSteps.Value
    $script:lastSpeed = [int]$numSpeed.Value
    $script:lastDone = 0
    Update-DisplayValues
    Send-Command ("RUN " + [int]$numSteps.Value + " " + [int]$numSpeed.Value)
})
$buttonsPanel.Controls.Add($btnRun)

$btnPurge = New-Object System.Windows.Forms.Button
$btnPurge.Text = "PURGE"
$btnPurge.Location = New-Object System.Drawing.Point(160, 14)
$btnPurge.Size = New-Object System.Drawing.Size(128, 48)
Style-Button $btnPurge $colorOrange $colorWhite 12 "Bold"
$btnPurge.Enabled = $false
$btnPurge.Add_Click({
    $script:purgeMode = $true
    $script:lastSteps = 15000
    $script:lastSpeed = [int]$numSpeed.Value
    $script:lastDone = 0
    Update-DisplayValues
    Send-Command ("SET SPEED " + [int]$numSpeed.Value)
    Start-Sleep -Milliseconds 100
    Send-Command "PURGE"
})
$buttonsPanel.Controls.Add($btnPurge)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "STOP"
$btnStop.Location = New-Object System.Drawing.Point(302, 14)
$btnStop.Size = New-Object System.Drawing.Size(128, 48)
Style-Button $btnStop $colorRed
$btnStop.Enabled = $false
$btnStop.Add_Click({ Send-Command "STOP" })
$buttonsPanel.Controls.Add($btnStop)

$btnSet = New-Object System.Windows.Forms.Button
$btnSet.Text = "Save"
$btnSet.Location = New-Object System.Drawing.Point(448, 18)
$btnSet.Size = New-Object System.Drawing.Size(78, 40)
Style-Button $btnSet $colorBlue
$btnSet.Enabled = $false
$btnSet.Add_Click({
    Send-Command ("SET STEPS " + [int]$numSteps.Value)
    Start-Sleep -Milliseconds 100
    Send-Command ("SET SPEED " + [int]$numSpeed.Value)
})
$buttonsPanel.Controls.Add($btnSet)

$btnGet = New-Object System.Windows.Forms.Button
$btnGet.Text = "Read Nano R4"
$btnGet.Location = New-Object System.Drawing.Point(540, 18)
$btnGet.Size = New-Object System.Drawing.Size(96, 40)
Style-Button $btnGet $colorYellow $colorReadText 10 "Bold"
$btnGet.Enabled = $false
$btnGet.Add_Click({ Send-Command "GET" })
$buttonsPanel.Controls.Add($btnGet)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear Log"
$btnClear.Location = New-Object System.Drawing.Point(650, 18)
$btnClear.Size = New-Object System.Drawing.Size(78, 40)
Style-Button $btnClear $colorPanel2 $colorText 10 "Regular"
$btnClear.Add_Click({ $logBox.Clear() })
$buttonsPanel.Controls.Add($btnClear)

$lblSignature = New-Label ("--- " + $appTitle) 500 500 260 22 10 $colorMuted "Regular"
$lblSignature.TextAlign = "MiddleRight"
$lblSignature.Anchor = "Right,Bottom"
$form.Controls.Add($lblSignature)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 512)
$logBox.Size = New-Object System.Drawing.Size(940, 0)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.BackColor = [System.Drawing.Color]::FromArgb(12, 14, 18)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(185, 195, 205)
$logBox.BorderStyle = "FixedSingle"
$logBox.Anchor = "Left,Right,Bottom"
$form.Controls.Add($logBox)

$form.Add_Shown({
    $form.Height = 675
    $lblSignature.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 320), 500)
    $logBox.Location = New-Object System.Drawing.Point(20, 512)
    $logBox.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 40), 112)
})

$form.Add_Resize({
    $header.Width = $form.ClientSize.Width
    $displayPanel.Width = $form.ClientSize.Width - 40
    $buttonsPanel.Width = $form.ClientSize.Width - 40
    $lblSignature.Location = New-Object System.Drawing.Point(($form.ClientSize.Width - 320), 500)
    $logBox.Width = $form.ClientSize.Width - 40
    $logBox.Height = [Math]::Max(80, $form.ClientSize.Height - 532)
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({
    Read-Serial
    if ($script:port -and $script:port.IsOpen -and $lblState.Text -eq "RUNNING") {
        Send-Command "GET" $true
    }
})
$timer.Start()

$form.Add_FormClosing({
    Disconnect-Port
    $timer.Stop()
    $timer.Dispose()
})

Refresh-Ports
Update-DisplayValues
Set-ConnectedUi $false
Add-Log "Selecciona el COM del Arduino Nano R4 y presiona Connect."

[void]$form.ShowDialog()
