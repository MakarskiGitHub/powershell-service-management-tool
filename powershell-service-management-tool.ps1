# -------------------------------------------- #
# | CONFIGURATION - Change only this section | #
# -------------------------------------------- # 

# Regions - put the name of the servers in specific region
$serverMap = @{
    'EMEA' = @('Server1', 'Server2')  
    'AMERICA' = @('Server3')            
    'ASIA' = @('Server4','Server5','Server6')                 
}

# Environments - put the name(s) of the services that you want to be controlled by the script
$envMap = @{ 
    'TEST' = @('ServiceName_TEST*')
    'TRAIN' = @('ServiceName_TRAIN*')
    'UAT' = @('ServiceName_UAT*')
}

# Untouchable Services - the script will skip those services
$excludeServices = @(
    'ServiceName1', 'ServiceName2', 'ServiceName3', 'ServiceName4'
)

# -------------------------------- #
# | SCRIPT - do not change below | #
# -------------------------------- # 

function Read-MenuSelection {
    param (
        [string]$Title,
        [hashtable]$Items,
        [switch]$AllowAll
    )

    do {
        Write-Host "`n=== $Title ===" -ForegroundColor Cyan
        $index = 1
        $menuMap = @{}

        foreach ($key in $Items.Keys) {
            $preview = $Items[$key] -join ', '
            if ($preview.Length -gt 40) { $preview = $preview.Substring(0,37)+'...' }
            Write-Host "$index) $key ($preview)"
            $menuMap[$index.ToString()] = $key
            $index++
        }

        if ($AllowAll) {
            Write-Host "$index) All"
            $menuMap[$index.ToString()] = 'ALL'
        }

        $input = Read-Host "`nEnter (e.g. '1', '1,3,$index')"
        if ([string]::IsNullOrWhiteSpace($input)) {
            Write-Host "Selection cannot be empty." -ForegroundColor Red
            $isValid = $false
            continue
        }

        $tokens = $input -split ',' | ForEach-Object { $_.Trim() }
        $invalid = $tokens | Where-Object { -not $menuMap.ContainsKey($_) }

        if ($invalid) {
            Write-Host "Invalid selection. Allowed: $($menuMap.Keys -join ', ')" -ForegroundColor Red
            $isValid = $false
        } else { $isValid = $true }

    } while (-not $isValid)

    # map to selected keys
    $selected = @()
    foreach ($token in $tokens) {
        if ($menuMap[$token] -eq 'ALL') {
            $selected = $Items.Keys
            break
        } else {
            $selected += $menuMap[$token]
        }
    }

    return $selected | Select-Object -Unique
}

# === REGIONS MENU ===
$selectedRegions = Read-MenuSelection -Title "SELECT THE REGIONS (Enter numbers separated by commas)" -Items $serverMap -AllowAll

# === ENVIRONMENTS MENU ===
$selectedEnvs = Read-MenuSelection -Title "SELECT THE ENVIRONMENTS (Enter numbers separated by commas)" -Items $envMap -AllowAll

# === ACTION MENU ===
$actionList = @(
    @{ Key = '1'; Name = 'START' },
    @{ Key = '2'; Name = 'STOP' },
    @{ Key = '3'; Name = 'RESTART' }
)

do {
    Write-Host "`n=== SELECT ACTION (Enter number): ===" -ForegroundColor Cyan
    $menuMap = @{}
    foreach ($item in $actionList) {
        Write-Host "$($item.Key)) $($item.Name) services"
        $menuMap[$item.Key] = $item.Name
    }

    $actionInput = Read-Host "`nEnter choice"
    if ([string]::IsNullOrWhiteSpace($actionInput) -or -not $menuMap.ContainsKey($actionInput)) {
        Write-Host "Invalid selection. Allowed: $($menuMap.Keys -join ', ')" -ForegroundColor Red
        $isValid = $false
    } else {
        $isValid = $true
    }

} while (-not $isValid)

$action = $menuMap[$actionInput]

# === BUILD SERVER LIST === #
$servers = @()
foreach ($region in $selectedRegions) { $servers += $serverMap[$region] }
$servers = $servers | Select-Object -Unique
 
# === BUILD SERVICES LIST === #
$servicesToProcess = @()
foreach ($env in $selectedEnvs) { $servicesToProcess += $envMap[$env] }
$servicesToProcess = $servicesToProcess | Select-Object -Unique

# ===== SAFETY CHECK: no services selected (to prevent unwanted actions) ===== #
if (-not $servicesToProcess -or ($servicesToProcess | Where-Object { $_ -and $_.Trim() -ne '' }).Count -eq 0) {
    Write-Host "`nERROR: No services selected. Script execution aborted." -ForegroundColor Red
    exit 1
}

# === SUMMARY ===
Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Action: $action"
Write-Host "Regions: $($selectedRegions -join ', ')"
Write-Host "Environments: $($selectedEnvs -join ', ')"
Write-Host "Servers ($($servers.Count)): $($servers -join ', ')"
Write-Host "Services: $($servicesToProcess -join ', ')"

$confirm = Read-Host "`nExecute? (y/n)"
if ($confirm -ne 'y') { exit }

# === EXECUTION ===
$cred = Get-Credential -Message "Please put credentials for selected servers"
foreach ($server in $servers) {
    Write-Host "`n→ $server" -ForegroundColor Green
    Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {
        param($svcNames, $excludeList, $action)
        foreach ($svcPattern in $svcNames) {
            $services = Get-Service -Name $svcPattern -ErrorAction SilentlyContinue
            foreach ($svc in $services) {
                if ($svc.Name -notin $excludeList) {
                    switch ($action) {
                        'START' { Start-Service -Name $svc.Name -ErrorAction SilentlyContinue; Write-Host "Started: $($svc.Name)" -ForegroundColor Green }
                        'STOP' { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue; Write-Host "Stopped: $($svc.Name)" -ForegroundColor Green }
                        'RESTART' { Restart-Service -Name $svc.Name -ErrorAction SilentlyContinue; Write-Host "Restarted: $($svc.Name)" -ForegroundColor Green }
                    }
                } else {
                    Write-Host "SKIPPED: $($svc.Name)" -ForegroundColor DarkYellow
                }
            }
        }
    } -ArgumentList $servicesToProcess, $excludeServices, $action
}

Write-Host "`nDONE!" -ForegroundColor DarkCyan

