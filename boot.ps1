$CsvPath = "C:\BootLog\bootlog.csv"

function Get-EventDataValue {
    param(
        $EventXml,
        [string]$Name
    )

    ($EventXml.Event.EventData.Data |
        Where-Object Name -eq $Name).'#text'
}


# Latest Event 100 (boot)
$BootEvent = Get-WinEvent `
    -FilterHashtable @{
        LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
        Id = 100
    } `
    -MaxEvents 1 `
    -ErrorAction SilentlyContinue

if(-not $BootEvent)
{
    Write-Error "No Event 100 found after waiting."
    exit 1
}


[xml]$BootXml = $BootEvent.ToXml()

$CurrentBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$EventBootStart = [datetime](Get-EventDataValue $BootXml 'BootStartTime')
$DifferenceMinutes = [math]::Abs(
    ($EventBootStart - $CurrentBootTime).TotalMinutes
)

if($DifferenceMinutes -gt 5)
{
    Write-Host ""
    Write-Host "Latest Event 100 belongs to an older boot." -ForegroundColor Red
    Write-Host "Event Boot Start : $EventBootStart"
    Write-Host "Current Boot     : $CurrentBootTime"
    Write-Host ""

    Read-Host "Press Enter to close"
    exit 1
}


$BootTimeMs       = [double](Get-EventDataValue $BootXml 'BootTime')
$MainPathMs       = [double](Get-EventDataValue $BootXml 'MainPathBootTime')
$PostBootMs       = [double](Get-EventDataValue $BootXml 'BootPostBootTime')
$BootStartTime    = Get-EventDataValue $BootXml 'BootStartTime'

# Get Event 101 entries for this specific boot
$SlowApps = Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
    Id = 101
} -MaxEvents 100 |
Where-Object {

    [xml]$Xml = $_.ToXml()

    ((Get-EventDataValue $Xml 'StartTime') -eq $BootStartTime)

} |
ForEach-Object {

    [xml]$Xml = $_.ToXml()

    [PSCustomObject]@{
        Name = Get-EventDataValue $Xml 'Name'
        DegradationMS = [double](Get-EventDataValue $Xml 'DegradationTime')
    }

} |
Sort-Object DegradationMS -Descending

$Top1 = $SlowApps | Select-Object -Skip 0 -First 1
$Top2 = $SlowApps | Select-Object -Skip 1 -First 1
$Top3 = $SlowApps | Select-Object -Skip 2 -First 1

$Row = [PSCustomObject]@{

    Timestamp = $BootEvent.TimeCreated

    BootSeconds = [math]::Round($BootTimeMs / 1000, 1)

    MainPathSeconds = [math]::Round($MainPathMs / 1000, 1)

    PostBootSeconds = [math]::Round($PostBootMs / 1000, 1)

    Top1 = $Top1.Name
    Delay1 = if ($Top1) {
        [math]::Round($Top1.DegradationMS / 1000, 1)
    } else {
        0
    }

    Top2 = $Top2.Name
    Delay2 = if ($Top2) {
        [math]::Round($Top2.DegradationMS / 1000, 1)
    } else {
        0
    }

    Top3 = $Top3.Name
    Delay3 = if ($Top3) {
        [math]::Round($Top3.DegradationMS / 1000, 1)
    } else {
        0
    }
}


if(-not $BootEvent)
{
    Add-Content `
        -Path "C:\BootLog\boot.err" `
        -Value "$(Get-Date -Format s) No Event 100 found"
}

if (-not (Test-Path $CsvPath)) {
    $Row | Export-Csv $CsvPath -NoTypeInformation
}
else {
    $Row | Export-Csv $CsvPath -NoTypeInformation -Append
}

$Row
