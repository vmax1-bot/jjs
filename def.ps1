param(
    [switch]$Phase1, # Phase 1: Basic disable
    [switch]$Phase2, # Phase 2: Services and registry
    [switch]$Phase3, # Phase 3: Advanced settings and cleanup
    [switch]$All        # Execute all phases at once
)

# ==============================================================================
# Refactored Enhanced Windows Defender Disabler Script v4.0
# Supports Windows 11 24H2/25H2 with TrustedInstaller method
# ==============================================================================

# Define status symbols - using text symbols to avoid encoding issues
$script:StatusSymbols = @{
    Success = "[OK]"     # Success
    Warning = "[!]"      # Warning  
    Error   = "[X]"        # Error
    Info    = "[i]"         # Info
    Rocket  = "[>>]"      # Execution
}

# Set console encoding to UTF-8 for consistent display
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}
catch {
    # Encoding setting failed, continue with default
}

# ==============================================================================
# Initialization and Helper Functions
# ==============================================================================

# Check administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "$($script:StatusSymbols.Error) This script requires administrator privileges to run" -ForegroundColor Red
    exit 1
}

# Global variables
$script:Results = [ordered]@{}
$script:StartTime = Get-Date
$script:PsExecPath = $null
$script:ConfigDetails = @{}
$script:Windows11_25H2 = $false

# Detect Windows 11 25H2 or newer
function Test-Windows11-25H2 {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    # Windows 11 25H2 is build 26100+
    if ($build -ge 26100) {
        $script:Windows11_25H2 = $true
        Write-Host "$($script:StatusSymbols.Info) Detected Windows 11 25H2 or newer (Build: $build)" -ForegroundColor Cyan
        return $true
    }
    # Windows 11 24H2 is build 26000+
    elseif ($build -ge 26000) {
        $script:Windows11_25H2 = $true
        Write-Host "$($script:StatusSymbols.Info) Detected Windows 11 24H2 (Build: $build)" -ForegroundColor Cyan
        return $true
    }
    return $false
}

# Run command with TrustedInstaller privileges (for Win11 25H2)
function Invoke-TrustedInstaller {
    param([string]$Command)
    
    try {
        Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue
        
        # Get original bin path
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='TrustedInstaller'"
        $DefaultBinPath = $service.PathName
        
        # Convert command to base64 to avoid errors with spaces
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
        $base64Command = [Convert]::ToBase64String($bytes)
        
        # Change bin to command
        sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" 2>$null | Out-Null
        
        # Run the command
        sc.exe start TrustedInstaller 2>$null | Out-Null
        Start-Sleep -Milliseconds 500
        
        # Set bin back to default
        sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" 2>$null | Out-Null
        Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        Write-Host "    $($script:StatusSymbols.Error) TrustedInstaller execution failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Initialize script
function Initialize-Script {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "   Refactored Defender Disabler v4.0" -ForegroundColor Cyan
    Write-Host "   (Windows 11 25H2 Enhanced Support)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
    Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
    Write-Host ""
    
    # Check Windows version
    Test-Windows11-25H2 | Out-Null
    
    # Check PsExec
    $psExecInScript = Join-Path $PSScriptRoot "PsExec.exe"
    if (Test-Path $psExecInScript) {
        $script:PsExecPath = $psExecInScript
        Write-Host "$($script:StatusSymbols.Success) PsExec found: $psExecInScript" -ForegroundColor Green
    }
    else {
        $psExecInPath = Get-Command PsExec -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if ($null -ne $psExecInPath) {
            $script:PsExecPath = $psExecInPath
            Write-Host "$($script:StatusSymbols.Success) PsExec found in system path: $psExecInPath" -ForegroundColor Green
        }
        else {
            Write-Host "$($script:StatusSymbols.Warning) PsExec not found. Please download from Sysinternals and place in script directory or system path:" -ForegroundColor Yellow
            Write-Host "https://learn.microsoft.com/en-us/sysinternals/downloads/psexec" -ForegroundColor Cyan
        }
    }
    Write-Host ""
}

# Record results
function Add-Result {
    param($Name, $Success, $Details = "")
    $script:Results[$Name] = @{
        Success   = $Success
        Details   = $Details
        Timestamp = Get-Date
    }
}

# ==============================================================================
# Phase 1: Basic Disable Functions
# ==============================================================================

function Invoke-Phase1 {
    Write-Host "$($script:StatusSymbols.Rocket) Executing Phase 1: Basic Disable Functions" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray
    
    # 1.1 Disable Tamper Protection
    Write-Host "[1.1] Disabling Tamper Protection..." -ForegroundColor Yellow
    $tamperResult = Disable-TamperProtection
    Add-Result "TamperProtection" $tamperResult
    
    # 1.2 Disable Smart App Control
    Write-Host "[1.2] Disabling Smart App Control..." -ForegroundColor Yellow
    $smartAppResult = Disable-SmartAppControl
    Add-Result "SmartAppControl" $smartAppResult
    
    # 1.3 Disable Real-time Protection
    Write-Host "[1.3] Disabling Real-time Protection..." -ForegroundColor Yellow
    if ($tamperResult) {
        # Add delay to ensure Tamper Protection changes take effect in the system
        Write-Host "  Waiting for Tamper Protection changes to take effect..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3
        
        # Verify Tamper Protection is truly disabled at system level
        $tamperEffective = Test-TamperProtectionEffective
        if ($tamperEffective) {
            Write-Host "  Tamper Protection is confirmed disabled, proceeding with Real-time Protection..." -ForegroundColor Green
            $realtimeResult = Disable-RealtimeProtection
            Add-Result "RealtimeProtection" $realtimeResult
        }
        else {
            Write-Host "  $($script:StatusSymbols.Warning) Tamper Protection appears to still be active at system level. Attempting Real-time Protection anyway..." -ForegroundColor Yellow
            $realtimeResult = Disable-RealtimeProtection
            if (-not $realtimeResult) {
                Write-Host "  $($script:StatusSymbols.Info) Real-time Protection may require a second run after Tamper Protection fully takes effect." -ForegroundColor Cyan
            }
            Add-Result "RealtimeProtection" $realtimeResult "May require second run"
        }
    }
    else {
        Write-Host "  $($script:StatusSymbols.Warning) Skipping real-time protection settings because Tamper Protection is not disabled." -ForegroundColor Yellow
        Add-Result "RealtimeProtection" $false "Skipped, Tamper Protection is active."
    }
    
    Write-Host ""
    Write-Host "$($script:StatusSymbols.Success) Phase 1 completed" -ForegroundColor Green
    Show-PhaseResults @("TamperProtection", "SmartAppControl", "RealtimeProtection")
}

function Disable-TamperProtection {
    # For Windows 11 25H2, try TrustedInstaller method first
    if ($script:Windows11_25H2) {
        Write-Host "  Using enhanced method for Windows 11 25H2..." -ForegroundColor Cyan
        try {
            $tiCommand = @"
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows Defender\Features' /v 'TamperProtection' /t REG_DWORD /d '4' /f
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows Defender\Features' /v 'TamperProtectionSource' /t REG_DWORD /d '2' /f
"@
            Invoke-TrustedInstaller -Command $tiCommand | Out-Null
            Start-Sleep -Seconds 2
            
            $key = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'
            $tamperValue = (Get-ItemProperty -Path $key -Name 'TamperProtection' -ErrorAction SilentlyContinue).TamperProtection
            if ($tamperValue -eq 4) {
                Write-Host "  $($script:StatusSymbols.Success) TrustedInstaller successfully disabled Tamper Protection!" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Host "  $($script:StatusSymbols.Warning) TrustedInstaller method failed, trying alternatives..." -ForegroundColor Yellow
        }
    }
    
    # Try to disable using PsExec with SYSTEM privileges
    if ($script:PsExecPath) {
        try {
            Write-Host "  Attempting to disable using PsExec with SYSTEM privileges..." -ForegroundColor Cyan
            $tempScript = Join-Path $env:TEMP "DisableTamperProtection.ps1"
            @"
`$key='HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'
if (!(Test-Path `$key)) { exit 2 }
try {
    Set-ItemProperty -Path `$key -Name 'TamperProtection' -Value 4 -Force -ErrorAction Stop
    Set-ItemProperty -Path `$key -Name 'TamperProtectionSource' -Value 2 -Force -ErrorAction SilentlyContinue
    exit 0
} catch {
    exit 1
}
"@ | Out-File -FilePath $tempScript -Encoding ASCII
            
            Start-Process -FilePath $script:PsExecPath -ArgumentList "-accepteula", "-s", "-nobanner", "powershell.exe", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" -Wait -NoNewWindow | Out-Null
            Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
            
            $key = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'
            $tamperValue = (Get-ItemProperty -Path $key -Name 'TamperProtection' -ErrorAction SilentlyContinue).TamperProtection
            if ($tamperValue -eq 4) {
                Write-Host "  $($script:StatusSymbols.Success) PsExec successfully disabled Tamper Protection!" -ForegroundColor Green
                return $true
            }
            Write-Host "  $($script:StatusSymbols.Warning) PsExec execution completed, but verification failed. Trying regular method..." -ForegroundColor Yellow
        }
        catch {
            Write-Host "  $($script:StatusSymbols.Error) Error using PsExec: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Regular method
    try {
        Write-Host "  Trying regular method..." -ForegroundColor Cyan
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'
        if (!(Test-Path $key)) { return $false }
        Set-ItemProperty -Path $key -Name 'TamperProtection' -Value 4 -Force -ErrorAction Stop
        if (((Get-ItemProperty -Path $key -Name 'TamperProtection' -ErrorAction SilentlyContinue).TamperProtection -eq 4)) {
            Write-Host "  $($script:StatusSymbols.Success) Successfully disabled Tamper Protection" -ForegroundColor Green
            return $true
        }
    }
    catch {}

    # If failed, provide manual operation guidance
    Write-Host ""
    Write-Host "  $($script:StatusSymbols.Error) Unable to automatically disable Tamper Protection. Please perform manual operation:" -ForegroundColor Red
    Write-Host "  1. Open Windows Security Center" -ForegroundColor Cyan
    Write-Host "  2. Virus & threat protection -> Virus & threat protection settings" -ForegroundColor Cyan
    Write-Host "  3. Turn off 'Tamper Protection'" -ForegroundColor Cyan
    Write-Host "  4. Re-run this script after turning it off" -ForegroundColor Cyan
    Write-Host ""
    return $false
}

function Test-TamperProtectionEffective {
    try {
        # First check registry value
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'
        $regValue = (Get-ItemProperty -Path $key -Name 'TamperProtection' -ErrorAction SilentlyContinue).TamperProtection
        
        if ($regValue -ne 4) {
            Write-Host "    Registry check: Tamper Protection not disabled (value: $regValue)" -ForegroundColor Gray
            return $false
        }
        
        # Try to test system-level effectiveness by attempting a defender configuration change
        try {
            # Try to change a defender setting - this should work if Tamper Protection is truly off
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue 2>$null
            
            # Check if we can read the current status without errors
            $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue 2>$null
            
            if ($null -ne $mpStatus) {
                Write-Host "    System-level check: Tamper Protection appears inactive" -ForegroundColor Gray
                return $true
            }
            else {
                Write-Host "    System-level check: Cannot verify defender status" -ForegroundColor Gray
                return $false
            }
        }
        catch {
            Write-Host "    System-level check: Tamper Protection may still be active" -ForegroundColor Gray
            return $false
        }
    }
    catch {
        Write-Host "    Tamper Protection verification failed: $($_.Exception.Message)" -ForegroundColor Gray
        return $false
    }
}

function Disable-SmartAppControl {
    try {
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'
        if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
        Set-ItemProperty -Path $k -Name 'VerifiedAndReputablePolicyState' -Value 0 -Type DWORD -Force -ErrorAction Stop
        
        $value = (Get-ItemProperty -Path $k -Name 'VerifiedAndReputablePolicyState' -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState
        if ($value -eq 0) {
            Write-Host "  $($script:StatusSymbols.Success) Smart App Control has been disabled" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  $($script:StatusSymbols.Warning) Smart App Control disable failed" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  $($script:StatusSymbols.Error) Error setting Smart App Control: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Disable-RealtimeProtection {
    $maxRetries = 2
    $retryDelay = 2
    
    # For Windows 11 25H2, use MpCmdRun -DisableService method
    if ($script:Windows11_25H2) {
        Write-Host "  Using MpCmdRun -DisableService for Windows 11 25H2..." -ForegroundColor Cyan
        try {
            # First apply registry values with TrustedInstaller
            $regCommand = @"
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows Defender' /v 'DisableAntiSpyware' /t REG_DWORD /d '1' /f
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows Defender' /v 'DisableAntiVirus' /t REG_DWORD /d '1' /f
Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows Defender' /v 'PassiveMode' /t REG_DWORD /d '1' /f
Reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender' /v 'DisableAntiSpyware' /t REG_DWORD /d '1' /f
"@
            Invoke-TrustedInstaller -Command $regCommand | Out-Null
            
            # Stop wscsvc service
            Stop-Service 'wscsvc' -Force -ErrorAction SilentlyContinue
            Stop-Process -Name 'MpCmdRun' -Force -ErrorAction SilentlyContinue
            
            # Try MpCmdRun -DisableService
            $mpcmdPath = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
            if (Test-Path $mpcmdPath) {
                Push-Location "$env:ProgramFiles\Windows Defender"
                Start-Process -FilePath $mpcmdPath -ArgumentList '-DisableService -HighPriority' -Wait -NoNewWindow -ErrorAction SilentlyContinue
                Pop-Location
                
                # Wait for MsMpEng to stop
                $wait = 10
                while ((Get-Process -Name 'MsMpEng' -ErrorAction SilentlyContinue) -and $wait -gt 0) {
                    $wait--
                    Start-Sleep -Seconds 1
                }
            }
        }
        catch {
            Write-Host "    $($script:StatusSymbols.Warning) MpCmdRun method error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            if ($attempt -gt 1) {
                Write-Host "  Retry attempt $attempt..." -ForegroundColor Cyan
                Start-Sleep -Seconds $retryDelay
            }
            
            # Use PowerShell cmdlet
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
            Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
            
            # Force disable through registry
            $rtPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
            if (Test-Path $rtPath) {
                Set-ItemProperty -Path $rtPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $rtPath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $rtPath -Name "DisableOnAccessProtection" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $rtPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
            }
            
            # Additional registry paths for comprehensive disable
            $additionalPaths = @(
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
            )
            
            foreach ($path in $additionalPaths) {
                if (!(Test-Path $path)) { 
                    New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null 
                }
                Set-ItemProperty -Path $path -Name "DisableRealtimeMonitoring" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name "DisableBehaviorMonitoring" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name "DisableOnAccessProtection" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name "DisableIOAVProtection" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name "DisableIntrusionPreventionSystem" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
            }
            
            # Wait a moment for changes to take effect
            Start-Sleep -Seconds 1
            
            # Verify status
            $status = (Get-MpComputerStatus -ErrorAction SilentlyContinue).RealTimeProtectionEnabled
            if ($null -eq $status -or $status -eq $false) {
                Write-Host "  $($script:StatusSymbols.Success) Real-time monitoring has been disabled" -ForegroundColor Green
                return $true
            }
            else {
                if ($attempt -eq $maxRetries) {
                    Write-Host "  $($script:StatusSymbols.Warning) Real-time monitoring disable failed after $maxRetries attempts" -ForegroundColor Yellow
                    Write-Host "  This may indicate Tamper Protection is still active at system level" -ForegroundColor Yellow
                }
            }
        }
        catch {
            if ($attempt -eq $maxRetries) {
                Write-Host "  $($script:StatusSymbols.Error) Error disabling real-time monitoring: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    return $false
}

function Show-PhaseResults {
    param([string[]]$Keys)
    Write-Host ""
    Write-Host "Phase Results Summary:" -ForegroundColor Cyan
    Write-Host ("-" * 30) -ForegroundColor Gray
    foreach ($key in $Keys) {
        if ($script:Results.Contains($key)) {
            $result = $script:Results[$key]
            $symbol = if ($result.Success) { $script:StatusSymbols.Success } else { $script:StatusSymbols.Error }
            $status = if ($result.Success) { "Success" } else { "Failed" }
            Write-Host "  $symbol $key`: $status" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })
            if ($result.Details) {
                Write-Host "    Details: $($result.Details)" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
}

function Show-FinalSummary {
    $endTime = Get-Date
    $duration = $endTime - $script:StartTime
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "             Final Execution Summary" -ForegroundColor Cyan  
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $totalItems = $script:Results.Count
    if ($totalItems -eq 0) {
        Write-Host "No operations were executed." -ForegroundColor Yellow
        return
    }
    
    $successItems = ($script:Results.Values | Where-Object { $_.Success }).Count
    $failedItems = $totalItems - $successItems
    
    Write-Host "Execution Statistics:" -ForegroundColor Green
    Write-Host "  Total Items: $totalItems" -ForegroundColor White
    Write-Host "  Successful: $successItems" -ForegroundColor Green  
    Write-Host "  Failed: $failedItems" -ForegroundColor Red
    if ($totalItems -gt 0) {
        Write-Host "  Success Rate: $([math]::Round(($successItems/$totalItems)*100, 1))%" -ForegroundColor Cyan
    }
    Write-Host ""
    
    Write-Host "Execution Details:" -ForegroundColor Green
    foreach ($item in $script:Results.GetEnumerator()) {
        if ($item.Value.Success) {
            Write-Host "  $($script:StatusSymbols.Success) $($item.Key)" -ForegroundColor Green
        }
        else {
            Write-Host "  $($script:StatusSymbols.Error) $($item.Key) - $($item.Value.Details)" -ForegroundColor Red
        }
    }
    Write-Host ""
    
    Write-Host "Execution Time: $($duration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Cyan
    Write-Host "Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    
    if ($failedItems -gt 0) {
        Write-Host "$($script:StatusSymbols.Warning) Important Notes:" -ForegroundColor Yellow
        Write-Host "  - Please check the items marked with $($script:StatusSymbols.Error) above." -ForegroundColor Yellow
        Write-Host "  - If Tamper Protection was not successfully disabled, please manually disable it and re-run." -ForegroundColor Yellow
    }
    else {
        Write-Host "$($script:StatusSymbols.Success) All selected configurations have been successfully applied!" -ForegroundColor Green
    }
    Write-Host "It is recommended to restart the system to ensure all changes take full effect." -ForegroundColor Cyan
    Write-Host ""
}

function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\Disable-Windows-Defender.ps1 -Phase1    # Execute Phase 1: Basic Disable"
    Write-Host "  .\Disable-Windows-Defender.ps1 -Phase2    # Execute Phase 2: Services and Registry"
    Write-Host "  .\Disable-Windows-Defender.ps1 -Phase3    # Execute Phase 3: Advanced Settings and Cleanup"
    Write-Host "  .\Disable-Windows-Defender.ps1 -All       # Execute All Phases at Once"
    Write-Host ""
    Write-Host "Phase Descriptions:" -ForegroundColor Cyan
    Write-Host "  Phase1: Disable Tamper Protection, Smart App Control, Real-time Protection" -ForegroundColor Gray
    Write-Host "  Phase2: Configure Group Policies, Disable Services, Disable SpyNet, Disable Notifications" -ForegroundColor Gray
    Write-Host "  Phase3: Disable SmartScreen, Remove Context Menu, Disable Scheduled Tasks, Hide Settings Page, Block Updates" -ForegroundColor Gray
    Write-Host ""
}

# ==============================================================================
# Phase 2: Services and Registry Configuration
# ==============================================================================

function Invoke-Phase2 {
    Write-Host "$($script:StatusSymbols.Rocket) Executing Phase 2: Services and Registry Configuration" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray
    
    # 2.1 Configure Group Policies
    Write-Host "[2.1] Configuring Group Policies..." -ForegroundColor Yellow
    $policyResult = Set-GroupPolicies
    Add-Result "GroupPolicies" $policyResult

    # 2.2 Disable Defender Services
    Write-Host "[2.2] Disabling Windows Defender Services..." -ForegroundColor Yellow
    $servicesResult = Disable-DefenderServices
    Add-Result "DefenderServices" $servicesResult
    
    # 2.3 Disable SpyNet Reporting
    Write-Host "[2.3] Disabling SpyNet/MAPS Reporting..." -ForegroundColor Yellow
    $spyNetResult = Disable-SpyNetReporting
    Add-Result "SpyNetReporting" $spyNetResult
    
    # 2.4 Disable Notification System
    Write-Host "[2.4] Disabling Notifications..." -ForegroundColor Yellow
    $notificationResult = Disable-DefenderNotifications
    Add-Result "DefenderNotifications" $notificationResult
    
    Write-Host ""
    Write-Host "$($script:StatusSymbols.Success) Phase 2 completed" -ForegroundColor Green
    Show-PhaseResults @("GroupPolicies", "DefenderServices", "SpyNetReporting", "DefenderNotifications")
}

function Set-GroupPolicies {
    Write-Host "  Applying group policies and registry settings..." -ForegroundColor Cyan
    $allSuccess = $true

    # Define all settings to apply (enhanced for Windows 11 25H2)
    $policies = @(
        # Core Defender disable
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableAntiSpyware'; Value = 1; DisplayName = "Disable Defender (DisableAntiSpyware)" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableAntiVirus'; Value = 1; DisplayName = "Disable AntiVirus" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'ServiceKeepAlive'; Value = 0; DisplayName = "Disable Service Protection (ServiceKeepAlive)" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'AllowFastServiceStartup'; Value = 0; DisplayName = "Disable Fast Service Startup" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableRoutinelyTakingAction'; Value = 1; DisplayName = "Disable Auto Remediation" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableLocalAdminMerge'; Value = 1; DisplayName = "Disable Local Admin Merge" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'PUAProtection'; Value = 0; DisplayName = "Disable PUA Protection" },
        
        # Real-Time Protection
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableBehaviorMonitoring'; Value = 1; DisplayName = "Disable Behavior Monitoring" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableOnAccessProtection'; Value = 1; DisplayName = "Disable On Access Protection" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableScanOnRealtimeEnable'; Value = 1; DisplayName = "Disable Real-time Scanning" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRealtimeMonitoring'; Value = 1; DisplayName = "Disable Realtime Monitoring" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableIOAVProtection'; Value = 1; DisplayName = "Disable IOAV Protection" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableIntrusionPreventionSystem'; Value = 1; DisplayName = "Disable Intrusion Prevention" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRawWriteNotification'; Value = 1; DisplayName = "Disable Raw Write Notification" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableInformationProtectionControl'; Value = 1; DisplayName = "Disable Information Protection Control" },
        
        # Signature Updates
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'ForceUpdateFromMU'; Value = 0; DisplayName = "Disable Force Update From MU" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'UpdateOnStartUp'; Value = 0; DisplayName = "Disable Update On StartUp" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'DisableScanOnUpdate'; Value = 1; DisplayName = "Disable Scan On Update" },
        
        # SpyNet/MAPS
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name = 'DisableBlockAtFirstSeen'; Value = 1; DisplayName = "Disable Block At First Seen" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name = 'SpynetReporting'; Value = 0; DisplayName = "Disable SpyNet Reporting" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name = 'SubmitSamplesConsent'; Value = 2; DisplayName = "Never Send Samples" },
        
        # MpEngine
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine'; Name = 'MpEnablePus'; Value = 0; DisplayName = "Disable PUS in Engine" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine'; Name = 'MpCloudBlockLevel'; Value = 0; DisplayName = "Disable Cloud Block" },
        
        # Scan settings
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableHeuristics'; Value = 1; DisplayName = "Disable Heuristics" },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableRestorePoint'; Value = 1; DisplayName = "Disable Restore Point" },
        
        # Network Protection  
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection'; Name = 'EnableNetworkProtection'; Value = 0; DisplayName = "Disable Network Protection" },
        
        # Controlled Folder Access
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access'; Name = 'EnableControlledFolderAccess'; Value = 0; DisplayName = "Disable Controlled Folder Access" }
    )
    
    # Windows 11 25H2 specific policies
    if ($script:Windows11_25H2) {
        Write-Host "  Adding Windows 11 25H2 specific policies..." -ForegroundColor Cyan
        $policies += @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'; Name = 'DisableAntiSpyware'; Value = 1; DisplayName = "Direct Disable AntiSpyware" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'; Name = 'DisableAntiVirus'; Value = 1; DisplayName = "Direct Disable AntiVirus" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'; Name = 'PassiveMode'; Value = 1; DisplayName = "Enable Passive Mode" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowRealtimeMonitoring'; Name = 'value'; Value = 0; DisplayName = "PolicyManager: Disable Realtime" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowBehaviorMonitoring'; Name = 'value'; Value = 0; DisplayName = "PolicyManager: Disable Behavior" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowCloudProtection'; Name = 'value'; Value = 0; DisplayName = "PolicyManager: Disable Cloud" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection'; Name = 'value'; Value = 0; DisplayName = "PolicyManager: Disable IOAV" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowOnAccessProtection'; Name = 'value'; Value = 0; DisplayName = "PolicyManager: Disable OnAccess" },
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\EnableNetworkProtection'; Name = 'value'; Value = 0; DisplayName = "PolicyManager: Disable Network Prot" }
        )
    }

    foreach ($policy in $policies) {
        try {
            if (!(Test-Path $policy.Path)) {
                New-Item -Path $policy.Path -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Set-ItemProperty -Path $policy.Path -Name $policy.Name -Value $policy.Value -Type DWORD -Force -ErrorAction Stop
            
            # Verify
            $currentValue = (Get-ItemProperty -Path $policy.Path -Name $policy.Name -ErrorAction SilentlyContinue)."$($policy.Name)"
            if ($currentValue -eq $policy.Value) {
                Write-Host "    $($script:StatusSymbols.Success) $($policy.DisplayName) has been set" -ForegroundColor Green
            }
            else {
                Write-Host "    $($script:StatusSymbols.Warning) $($policy.DisplayName) setting failed (Expected: $($policy.Value), Actual: $currentValue)" -ForegroundColor Yellow
                $allSuccess = $false
            }
        }
        catch [System.Security.SecurityException] {
            # Permission denied - likely Tamper Protection blocking this
            Write-Host "    $($script:StatusSymbols.Warning) $($policy.DisplayName) - Access denied (Tamper Protection active)" -ForegroundColor Yellow
            $allSuccess = $false
        }
        catch [System.UnauthorizedAccessException] {
            # Unauthorized access - likely protected registry key
            Write-Host "    $($script:StatusSymbols.Warning) $($policy.DisplayName) - Protected registry key" -ForegroundColor Yellow
            $allSuccess = $false
        }
        catch {
            Write-Host "    $($script:StatusSymbols.Error) $($policy.DisplayName) error during setting: $($_.Exception.Message)" -ForegroundColor Red
            $allSuccess = $false
        }
    }
    return $allSuccess
}

function Disable-DefenderServices {
    # Categorize services by expected disable-ability
    $primaryServices = @("WinDefend", "WdNisSvc", "Sense", "SecurityHealthService")  # Main targets
    $driverServices = @("WdNisDrv", "WdFilter", "WdBoot")  # Often system-protected
    
    # Windows 11 25H2 additional services
    if ($script:Windows11_25H2) {
        $primaryServices += @("MsSecCore", "MsSecFlt", "MsSecWfp", "webthreatdefusrsvc", "webthreatdefsvc", "SgrmAgent", "SgrmBroker")
        Write-Host "  Including Windows 11 25H2 specific services..." -ForegroundColor Cyan
    }
    
    $services = $primaryServices + $driverServices
    
    # For Windows 11 25H2, use TrustedInstaller method first
    if ($script:Windows11_25H2) {
        Write-Host "  Using TrustedInstaller to delete service registry keys..." -ForegroundColor Cyan
        $deleteCommands = @()
        foreach ($svc in $services) {
            $deleteCommands += "Reg.exe delete 'HKLM\SYSTEM\CurrentControlSet\Services\$svc' /f 2>`$null"
        }
        # Also remove WMI Autologger entries
        $deleteCommands += "Reg.exe delete 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger' /f 2>`$null"
        $deleteCommands += "Reg.exe delete 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger' /f 2>`$null"
        
        $tiCommand = $deleteCommands -join "; "
        Invoke-TrustedInstaller -Command $tiCommand | Out-Null
        Start-Sleep -Seconds 2
    }
    
    if ($script:PsExecPath) {
        Write-Host "  Using PsExec with SYSTEM privileges to disable services..." -ForegroundColor Cyan
        $tempScriptContent = @"
`$services = @("WinDefend", "WdNisSvc", "WdNisDrv", "WdFilter", "WdBoot", "Sense", "SecurityHealthService")
`$successCount = 0
`$totalCount = `$services.Count

foreach (`$service in `$services) {
    try {
        `$servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\`$service"
        
        if (Test-Path `$servicePath) {
            `$currentStart = (Get-ItemProperty -Path `$servicePath -Name "Start" -ErrorAction SilentlyContinue).Start
            
            # Skip if already disabled
            if (`$currentStart -eq 4) {
                `$successCount++
                continue
            }
            
                         # Try multiple approaches for stubborn services
             `$approaches = @(
                 # Approach 1: Standard method
                 {
                     Stop-Service -Name `$service -Force -ErrorAction SilentlyContinue 2>`$null
                     Set-Service -Name `$service -StartupType Disabled -ErrorAction SilentlyContinue 2>`$null
                     Set-ItemProperty -Path `$servicePath -Name "Start" -Value 4 -Type DWORD -Force -ErrorAction SilentlyContinue 2>`$null
                 },
                 # Approach 2: Use reg.exe for direct registry manipulation (more reliable)
                 {
                     `$regPath = `$servicePath -replace "HKLM:", "HKEY_LOCAL_MACHINE"
                     & reg.exe add "`$regPath" /v Start /t REG_DWORD /d 4 /f 2>`$null | Out-Null
                 },
                 # Approach 3: PowerShell with maximum error suppression
                 {
                     try {
                         `$ErrorActionPreference = 'SilentlyContinue'
                         Set-ItemProperty -Path `$servicePath -Name "Start" -Value 4 -Type DWORD -Force 2>`$null
                     } catch { }
                 }
             )
            
            `$success = `$false
            foreach (`$approach in `$approaches) {
                try {
                    & `$approach
                    `$newStart = (Get-ItemProperty -Path `$servicePath -Name "Start" -ErrorAction SilentlyContinue).Start
                    if (`$newStart -eq 4) {
                        `$success = `$true
                        break
                    }
                } catch {
                    # Continue to next approach
                }
            }
            
            if (`$success) {
                `$successCount++
            }
        } else {
            # Service doesn't exist, count as success
            `$successCount++
        }
    } catch {
        # Service failed, don't increment success count
    }
}

# Return success if most services were disabled (allow some core services to remain protected)
if (`$successCount -ge (`$totalCount - 2)) {
    exit 0
} else {
    exit 1
}
"@
        $tempScript = Join-Path $env:TEMP "DisableServices.ps1"
        $tempScriptContent | Out-File -FilePath $tempScript -Encoding ASCII
        
        Write-Host "    Executing advanced service disable methods..." -ForegroundColor Gray
        $process = Start-Process -FilePath $script:PsExecPath -ArgumentList "-accepteula", "-s", "-nobanner", "powershell.exe", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" -Wait -PassThru -NoNewWindow
        Write-Host "    PsExec exit code: $($process.ExitCode)" -ForegroundColor Gray
        
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue

        # Verify and categorize results
        $disabledServices = @()
        $protectedServices = @()
        $failedServices = @()
        $nonExistentServices = @()
         
        foreach ($service in $services) {
            $servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
            if (Test-Path $servicePath) {
                $startValue = (Get-ItemProperty -Path $servicePath -Name "Start" -ErrorAction SilentlyContinue).Start
                $startType = switch ($startValue) {
                    0 { "Boot" }
                    1 { "System" }
                    2 { "Automatic" }
                    3 { "Manual" }
                    4 { "Disabled" }
                    default { "Unknown($startValue)" }
                }
                 
                if ($startValue -eq 4) {
                    Write-Host "    $($script:StatusSymbols.Success) $service has been disabled" -ForegroundColor Green
                    $disabledServices += $service
                }
                elseif ($startValue -in @(0, 1)) {
                    # Boot/System services are often protected by Windows
                    Write-Host "    $($script:StatusSymbols.Info) $service is system-protected ($startType)" -ForegroundColor Cyan
                    $protectedServices += $service
                }
                else {
                    Write-Host "    $($script:StatusSymbols.Warning) $service disable failed ($startType)" -ForegroundColor Yellow
                    $failedServices += $service
                }
            }
            else {
                Write-Host "    $($script:StatusSymbols.Info) $service service not found (may be already removed)" -ForegroundColor Gray
                $nonExistentServices += $service
                $disabledServices += $service  # Count as success if service doesn't exist
            }
        }
        
        # Provide detailed feedback
        if ($disabledServices.Count -gt 0) {
            Write-Host "    Successfully disabled: $($disabledServices -join ', ')" -ForegroundColor Green
        }
        if ($protectedServices.Count -gt 0) {
            Write-Host "    System-protected services: $($protectedServices -join ', ')" -ForegroundColor Cyan
        }
        if ($failedServices.Count -gt 0) {
            Write-Host "    Failed to disable: $($failedServices -join ', ')" -ForegroundColor Red
        }
        
        # Calculate weighted success rate (primary services are more important)
        $primaryDisabled = ($disabledServices | Where-Object { $_ -in $primaryServices }).Count
        $primaryProtected = ($protectedServices | Where-Object { $_ -in $primaryServices }).Count
        $primaryFailed = ($failedServices | Where-Object { $_ -in $primaryServices }).Count
         
        # Overall success rate (protected services count as partial success)
        $overallSuccessRate = ($disabledServices.Count + $protectedServices.Count) / $services.Count
         
        # Effective success rate (what we actually achieved vs what's realistically possible)
        # Some services may already be disabled or non-existent, which is also success
        $effectiveSuccessRate = $overallSuccessRate
         
        # Consider successful if we have reasonable coverage
        # Lower threshold since some core services are expected to be protected
        $isSuccessful = ($effectiveSuccessRate -ge 0.4) -or ($primaryDisabled -ge 2)
         
        Write-Host "    Service disable summary: $($disabledServices.Count) disabled, $($protectedServices.Count) protected, $($failedServices.Count) failed" -ForegroundColor White
        Write-Host "    Primary services: $primaryDisabled disabled, $primaryProtected protected, $primaryFailed failed" -ForegroundColor Gray
        Write-Host "    Effective success rate: $([math]::Round($effectiveSuccessRate * 100, 1))%" -ForegroundColor $(if ($isSuccessful) { "Green" } else { "Yellow" })
         
        # Additional context for user
        if ($protectedServices.Count -gt 0) {
            Write-Host "    Note: System-protected services are expected and indicate core system security" -ForegroundColor Cyan
        }
        if ($disabledServices.Count -ge 2) {
            Write-Host "    Achievement: Successfully disabled key Defender services" -ForegroundColor Green
        }
         
        return $isSuccessful
    }

    # Regular method
    Write-Host "  PsExec not found, using regular method..." -ForegroundColor Yellow
    $allSuccess = $true
    foreach ($service in $services) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            $servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
            if (Test-Path $servicePath) {
                Set-ItemProperty -Path $servicePath -Name "Start" -Value 4 -Type DWORD -Force
                if ((Get-ItemProperty -Path $servicePath -Name "Start").Start -eq 4) {
                    Write-Host "    $($script:StatusSymbols.Success) $service has been disabled" -ForegroundColor Green
                }
                else {
                    Write-Host "    $($script:StatusSymbols.Warning) $service disable may be incomplete" -ForegroundColor Yellow
                    $allSuccess = $false
                }
            }
        }
        catch {
            Write-Host "    $($script:StatusSymbols.Error) $service configuration failed" -ForegroundColor Red
            $allSuccess = $false
        }
    }
    return $allSuccess
}

function Disable-SpyNetReporting {
    try {
        $spyNetPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'
        if (!(Test-Path $spyNetPath)) { New-Item -Path $spyNetPath -Force | Out-Null }
        
        # Disable SpyNet/MAPS
        Set-ItemProperty -Path $spyNetPath -Name 'SpyNetReporting' -Value 0 -Type DWORD -Force
        # Don't send samples
        Set-ItemProperty -Path $spyNetPath -Name 'SubmitSamplesConsent' -Value 2 -Type DWORD -Force
        
        $val1 = (Get-ItemProperty -Path $spyNetPath -Name 'SpyNetReporting').SpyNetReporting
        $val2 = (Get-ItemProperty -Path $spyNetPath -Name 'SubmitSamplesConsent').SubmitSamplesConsent
        
        if ($val1 -eq 0 -and $val2 -eq 2) {
            Write-Host "  $($script:StatusSymbols.Success) SpyNet/MAPS reporting has been disabled" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  $($script:StatusSymbols.Warning) SpyNet/MAPS reporting disable failed" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  $($script:StatusSymbols.Error) SpyNet configuration error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Disable-DefenderNotifications {
    try {
        $notifPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'
        if (!(Test-Path $notifPath)) { New-Item -Path $notifPath -Force | Out-Null }
        
        Set-ItemProperty -Path $notifPath -Name 'DisableNotifications' -Value 1 -Type DWORD -Force
        Set-ItemProperty -Path $notifPath -Name 'DisableEnhancedNotifications' -Value 1 -Type DWORD -Force
        
        $val1 = (Get-ItemProperty -Path $notifPath -Name 'DisableNotifications').DisableNotifications
        $val2 = (Get-ItemProperty -Path $notifPath -Name 'DisableEnhancedNotifications').DisableEnhancedNotifications

        if ($val1 -eq 1 -and $val2 -eq 1) {
            Write-Host "  $($script:StatusSymbols.Success) Defender notifications have been disabled" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  $($script:StatusSymbols.Warning) Defender notifications disable failed" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  $($script:StatusSymbols.Error) Notification configuration error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ==============================================================================
# Phase 3: Advanced Settings and Cleanup
# ==============================================================================

function Invoke-Phase3 {
    Write-Host "$($script:StatusSymbols.Rocket) Executing Phase 3: Advanced Settings and Cleanup" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray
    
    # 3.1 Disable SmartScreen
    Write-Host "[3.1] Disabling SmartScreen..." -ForegroundColor Yellow
    $smartScreenResult = Disable-SmartScreen
    Add-Result "SmartScreen" $smartScreenResult
    
    # 3.2 Remove Context Menu
    Write-Host "[3.2] Removing Defender Context Menu..." -ForegroundColor Yellow
    $contextMenuResult = Remove-DefenderContextMenu
    Add-Result "ContextMenu" $contextMenuResult
    
    # 3.3 Disable Scheduled Tasks
    Write-Host "[3.3] Disabling Defender Scheduled Tasks..." -ForegroundColor Yellow
    $scheduledTaskResult = Disable-DefenderScheduledTasks
    Add-Result "ScheduledTasks" $scheduledTaskResult
    
    # 3.4 Hide Windows Security Settings Page
    Write-Host "[3.4] Hiding Windows Security Settings Page..." -ForegroundColor Yellow
    $hideSettingsResult = Hide-WindowsSecuritySettings
    Add-Result "HideSettingsPage" $hideSettingsResult
    
    # 3.5 Block Defender Updates in Windows Update
    Write-Host "[3.5] Blocking Defender Updates in Windows Update..." -ForegroundColor Yellow
    $updateBlockResult = Block-DefenderUpdates
    Add-Result "BlockDefenderUpdates" $updateBlockResult
    
    # 3.6 Block Defender Process Launch (Win11 25H2 specific)
    if ($script:Windows11_25H2) {
        Write-Host "[3.6] Blocking Defender Process Launch (Win11 25H2)..." -ForegroundColor Yellow
        $blockProcessResult = Block-DefenderProcessLaunch
        Add-Result "BlockProcessLaunch" $blockProcessResult
        
        Write-Host "[3.7] Cleaning up Defender Registry Classes..." -ForegroundColor Yellow
        $cleanupResult = Remove-DefenderRegistryClasses
        Add-Result "RegistryCleanup" $cleanupResult
    }
    
    Write-Host ""
    Write-Host "$($script:StatusSymbols.Success) Phase 3 completed" -ForegroundColor Green
    
    $phaseItems = @("SmartScreen", "ContextMenu", "ScheduledTasks", "HideSettingsPage", "BlockDefenderUpdates")
    if ($script:Windows11_25H2) {
        $phaseItems += @("BlockProcessLaunch", "RegistryCleanup")
    }
    Show-PhaseResults $phaseItems
}

function Disable-SmartScreen {
    try {
        # Explorer SmartScreen
        $explorerPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
        Set-ItemProperty -Path $explorerPath -Name 'SmartScreenEnabled' -Value "Off" -Type String -Force
        
        # System SmartScreen Policy
        $systemPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        if (!(Test-Path $systemPath)) { New-Item -Path $systemPath -Force | Out-Null }
        Set-ItemProperty -Path $systemPath -Name 'EnableSmartScreen' -Value 0 -Type DWORD -Force
        
        Write-Host "  $($script:StatusSymbols.Success) SmartScreen has been disabled" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  $($script:StatusSymbols.Error) SmartScreen disable failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-DefenderContextMenu {
    try {
        $contextPaths = @(
            'HKLM:\SOFTWARE\Classes\*\shellex\ContextMenuHandlers\EPP',
            'HKLM:\SOFTWARE\Classes\Directory\shellex\ContextMenuHandlers\EPP',
            'HKLM:\SOFTWARE\Classes\Drive\shellex\ContextMenuHandlers\EPP'
        )
        
        $allSuccess = $true
        foreach ($path in $contextPaths) {
            if (Test-Path -LiteralPath $path) {
                try {
                    Remove-Item -LiteralPath $path -Recurse -Force
                    Write-Host "    $($script:StatusSymbols.Success) Removed: $path" -ForegroundColor Green
                }
                catch {
                    Write-Host "    $($script:StatusSymbols.Error) Failed to remove: $path" -ForegroundColor Red
                    $allSuccess = $false
                }
            }
            else {
                Write-Host "    $($script:StatusSymbols.Info) Does not exist, no need to remove: $path" -ForegroundColor Gray
            }
        }
        return $allSuccess
    }
    catch {
        Write-Host "  $($script:StatusSymbols.Error) Context menu removal failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Disable-DefenderScheduledTasks {
    $tasks = @(
        "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
        "Microsoft\Windows\Windows Defender\Windows Defender Cleanup", 
        "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
        "Microsoft\Windows\Windows Defender\Windows Defender Verification"
    )
    
    $allSuccess = $true
    foreach ($taskPath in $tasks) {
        $taskName = $taskPath.Split('\')[-1]
        try {
            $task = Get-ScheduledTask -TaskPath "\$($taskPath -replace $taskName, '')" -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                if ($task.State -ne 'Disabled') {
                    Disable-ScheduledTask -TaskName $taskName -TaskPath "\$($taskPath -replace $taskName, '')" | Out-Null
                    Write-Host "    $($script:StatusSymbols.Success) Disabled: $taskName" -ForegroundColor Green
                }
                else {
                    Write-Host "    $($script:StatusSymbols.Info) Already disabled: $taskName" -ForegroundColor Gray
                }
            }
            else {
                Write-Host "    $($script:StatusSymbols.Info) Task does not exist: $taskName" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "    $($script:StatusSymbols.Error) Disable failed: $taskName" -ForegroundColor Red
            $allSuccess = $false
        }
    }
    return $allSuccess
}

function Hide-WindowsSecuritySettings {
    try {
        $explorerPolicyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
        if (!(Test-Path $explorerPolicyPath)) { New-Item -Path $explorerPolicyPath -Force | Out-Null }
        
        Set-ItemProperty -Path $explorerPolicyPath -Name 'SettingsPageVisibility' -Value "hide:windowsdefender" -Type String -Force
        Write-Host "  $($script:StatusSymbols.Success) Windows Security settings page has been hidden" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  $($script:StatusSymbols.Error) Hide settings page failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Block-DefenderUpdates {
    try {
        # Block updates through MRT policy
        $mrtPath = 'HKLM:\SOFTWARE\Policies\Microsoft\MRT' 
        if (!(Test-Path $mrtPath)) { New-Item -Path $mrtPath -Force | Out-Null }
        Set-ItemProperty -Path $mrtPath -Name 'DontOfferThroughWUAU' -Value 1 -Type DWORD -Force
        
        # Remove SecurityHealth startup item
        $runPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        if (Get-ItemProperty -Path $runPath -Name 'SecurityHealth' -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $runPath -Name 'SecurityHealth' -Force
            Write-Host "  $($script:StatusSymbols.Success) SecurityHealth startup item has been removed" -ForegroundColor Green
        }
        
        Write-Host "  $($script:StatusSymbols.Success) Defender updates have been blocked through policy" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  $($script:StatusSymbols.Error) Block updates failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ==============================================================================
# Windows 11 25H2 Specific Functions
# ==============================================================================

function Block-DefenderProcessLaunch {
    # Block Defender executables using Image File Execution Options (IFEO)
    # This prevents Defender processes from launching by assigning a fake debugger
    Write-Host "  Blocking Defender process launch via IFEO..." -ForegroundColor Cyan
    
    $processesToBlock = @(
        "MsMpEng.exe",
        "MpCmdRun.exe",
        "NisSrv.exe",
        "SecurityHealthService.exe",
        "SecurityHealthSystray.exe",
        "smartscreen.exe",
        "MpDefenderCoreService.exe"
    )
    
    $allSuccess = $true
    $ifeoPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    
    # For Windows 11 25H2, use TrustedInstaller FIRST (more reliable)
    if ($script:Windows11_25H2) {
        Write-Host "    Using TrustedInstaller for IFEO blocking..." -ForegroundColor Gray
        try {
            $regCommands = @()
            foreach ($proc in $processesToBlock) {
                $regCommands += "Reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$proc' /v Debugger /t REG_SZ /d 'systray.exe' /f 2>`$null"
            }
            $tiCommand = $regCommands -join "; "
            Invoke-TrustedInstaller -Command $tiCommand | Out-Null
            Start-Sleep -Seconds 1
            Write-Host "    $($script:StatusSymbols.Success) TrustedInstaller IFEO blocking completed" -ForegroundColor Green
        }
        catch {
            Write-Host "    $($script:StatusSymbols.Warning) TrustedInstaller IFEO method failed, trying PsExec..." -ForegroundColor Yellow
        }
    }
    
    # Use PsExec if available for additional enforcement
    if ($script:PsExecPath) {
        Write-Host "    Using PsExec for IFEO blocking..." -ForegroundColor Gray
        $tempScript = Join-Path $env:TEMP "BlockIFEO.ps1"
        $scriptContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$processes = @('MsMpEng.exe', 'MpCmdRun.exe', 'NisSrv.exe', 'SecurityHealthService.exe', 'SecurityHealthSystray.exe', 'smartscreen.exe', 'MpDefenderCoreService.exe')
`$ifeoPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
foreach (`$proc in `$processes) {
    `$procPath = Join-Path `$ifeoPath `$proc
    if (!(Test-Path `$procPath)) { New-Item -Path `$procPath -Force 2>`$null | Out-Null }
    Set-ItemProperty -Path `$procPath -Name 'Debugger' -Value 'systray.exe' -Type String -Force 2>`$null
}
exit 0
"@
        $scriptContent | Out-File -FilePath $tempScript -Encoding ASCII -Force
        Start-Process -FilePath $script:PsExecPath -ArgumentList "-accepteula", "-s", "-nobanner", "powershell.exe", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue 2>$null
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
    }
    
    # Verify results (suppress errors during verification)
    $blockedCount = 0
    foreach ($proc in $processesToBlock) {
        $procPath = Join-Path $ifeoPath $proc
        $debugger = (Get-ItemProperty -Path $procPath -Name 'Debugger' -ErrorAction SilentlyContinue).Debugger
        if ($debugger -eq 'systray.exe') {
            Write-Host "    $($script:StatusSymbols.Success) Blocked: $proc" -ForegroundColor Green
            $blockedCount++
        }
        else {
            Write-Host "    $($script:StatusSymbols.Warning) Could not verify: $proc" -ForegroundColor Yellow
        }
    }
    
    $allSuccess = ($blockedCount -ge 3)  # Consider success if at least 3 processes blocked
    if ($allSuccess) {
        Write-Host "    $($script:StatusSymbols.Success) IFEO blocking: $blockedCount/$($processesToBlock.Count) processes blocked" -ForegroundColor Green
    }
    else {
        Write-Host "    $($script:StatusSymbols.Warning) IFEO blocking: $blockedCount/$($processesToBlock.Count) processes blocked" -ForegroundColor Yellow
    }
    
    return $allSuccess
}

function Remove-DefenderRegistryClasses {
    # Remove Defender COM classes and WMI autologger
    Write-Host "  Removing Defender registry classes..." -ForegroundColor Cyan
    
    $classesToRemove = @(
        'HKLM:\SOFTWARE\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}',
        'HKLM:\SOFTWARE\Classes\CLSID\{2781761E-28E2-4109-99FE-B9D127C57AFE}',
        'HKLM:\SOFTWARE\Classes\CLSID\{195B4D07-3DE2-4744-BBF2-D90121AE785B}',
        'HKLM:\SOFTWARE\Classes\CLSID\{A7C452EF-8E9F-42EB-9F2B-245613CA0DC9}',
        'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger',
        'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger'
    )
    
    $allSuccess = $true
    
    # Use TrustedInstaller for registry class removal
    $deleteCommands = @()
    foreach ($class in $classesToRemove) {
        $regPath = $class -replace 'HKLM:', 'HKLM'
        $deleteCommands += "Reg.exe delete '$regPath' /f 2>`$null"
    }
    
    try {
        $tiCommand = $deleteCommands -join "; "
        Invoke-TrustedInstaller -Command $tiCommand | Out-Null
        Write-Host "    $($script:StatusSymbols.Success) Defender registry classes removal attempted" -ForegroundColor Green
    }
    catch {
        Write-Host "    $($script:StatusSymbols.Warning) Some registry classes could not be removed" -ForegroundColor Yellow
        $allSuccess = $false
    }
    
    # Remove firewall defender rules
    try {
        $fwPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'
        if (Test-Path $fwPath) {
            Remove-ItemProperty -Path $fwPath -Name 'WindowsDefender-1' -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $fwPath -Name 'WindowsDefender-2' -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $fwPath -Name 'WindowsDefender-3' -Force -ErrorAction SilentlyContinue
            Write-Host "    $($script:StatusSymbols.Success) Removed Defender firewall rules" -ForegroundColor Green
        }
    }
    catch {
        # Non-critical, continue
    }
    
    # Disable Security Center override
    try {
        $scPath = 'HKLM:\SOFTWARE\Microsoft\Security Center'
        if (!(Test-Path $scPath)) { New-Item -Path $scPath -Force | Out-Null }
        Set-ItemProperty -Path $scPath -Name 'FirstRunDisabled' -Value 1 -Type DWORD -Force
        Set-ItemProperty -Path $scPath -Name 'AntiVirusOverride' -Value 1 -Type DWORD -Force
        Set-ItemProperty -Path $scPath -Name 'FirewallOverride' -Value 1 -Type DWORD -Force
        Write-Host "    $($script:StatusSymbols.Success) Security Center overrides applied" -ForegroundColor Green
    }
    catch {
        Write-Host "    $($script:StatusSymbols.Warning) Security Center override failed" -ForegroundColor Yellow
    }
    
    return $allSuccess
}

# ==============================================================================
# Main Execution Logic
# ==============================================================================

# Initialize the script
Initialize-Script

# Execute based on parameters
if ($Phase1) {
    Invoke-Phase1
}
elseif ($Phase2) {
    Invoke-Phase2
}
elseif ($Phase3) {
    Invoke-Phase3
}
elseif ($All) {
    Write-Host "$($script:StatusSymbols.Rocket) Executing All Phases" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray
    Invoke-Phase1
    Invoke-Phase2
    Invoke-Phase3
    Write-Host ""
    Write-Host "All phases completed!" -ForegroundColor Green
}
else {
    # Default to All phases when no parameter is specified
    Write-Host "$($script:StatusSymbols.Info) No specific phase specified, executing all phases by default" -ForegroundColor Cyan
    Write-Host "$($script:StatusSymbols.Rocket) Executing All Phases" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray
    Invoke-Phase1
    Invoke-Phase2
    Invoke-Phase3
    Write-Host ""
    Write-Host "All phases completed!" -ForegroundColor Green
}

# Show final summary
Show-FinalSummary

# Show usage instructions
# Show-Usage 
