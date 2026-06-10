# Provision trycua computer-server inside a Windows guest (UTM or any VM).
# Run THIS SCRIPT INSIDE THE VM in an elevated PowerShell:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\provision-computer-server.ps1
#
# Requires Python 3.12+ on PATH (python.org installer with "Add python.exe
# to PATH" checked). Registers a logon Scheduled Task — NOT a service — so the
# server runs in the interactive desktop session; Session 0 services cannot
# capture the screen or send input. See the parent SKILL.md.

$ErrorActionPreference = 'Stop'

$Port = if ($env:CUA_SERVER_PORT) { [int]$env:CUA_SERVER_PORT } else { 8000 }
$Venv = Join-Path $env:USERPROFILE 'cua-server-env'
$TaskName = 'cua-computer-server'

Write-Host "==> Checking Python"
$pyVersion = & python --version
Write-Host "    $pyVersion"

Write-Host "==> Creating venv + installing cua-computer-server ($Venv)"
if (-not (Test-Path "$Venv\Scripts\python.exe")) {
    & python -m venv $Venv
}
& "$Venv\Scripts\python.exe" -m pip install --upgrade pip
& "$Venv\Scripts\python.exe" -m pip install --upgrade cua-computer-server
& "$Venv\Scripts\python.exe" -c "import computer_server; print('import OK')"

Write-Host "==> Allowing TCP $Port through Windows Defender Firewall"
netsh advfirewall firewall delete rule name=$TaskName | Out-Null
netsh advfirewall firewall add rule name=$TaskName dir=in action=allow protocol=TCP localport=$Port | Out-Null

Write-Host "==> Registering logon Scheduled Task ($TaskName)"
$Action = New-ScheduledTaskAction `
    -Execute "$Venv\Scripts\python.exe" `
    -Argument "-m computer_server --port $Port"
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
# Interactive principal: runs on the visible desktop of the logged-in user.
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $TaskName `
    -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

Write-Host "==> Starting it now"
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 6

Write-Host "==> Status:"
try {
    $status = Invoke-RestMethod -Uri "http://localhost:$Port/status" -TimeoutSec 5
    $status | ConvertTo-Json -Compress
} catch {
    Write-Warning "computer-server not answering yet: $_"
    Write-Warning "Check: Get-ScheduledTaskInfo -TaskName $TaskName"
}

Write-Host ""
Write-Host "Done. From the macOS host, verify with:"
Write-Host "  curl -s -m5 http://<guest-ip>:$Port/status   # guest IP from ipconfig"
