# BootLog

A lightweight PowerShell-based Windows boot monitoring solution.

The script records Windows boot performance metrics from the built-in **Microsoft-Windows-Diagnostics-Performance/Operational** event log and appends them to a CSV file for long-term trend analysis.

---

## Purpose

This project was created to monitor Windows boot performance over time and identify startup regressions, slow services, and slow applications.

My PC was taking 2 minutes to boot, with Windows Defender showing as the main delay at 67 seconds in the third section of the boot, however, the issue wasn't windows Defender directly but a conflict between defender and Dell Support Assist.
To fix my PC, I removed a few of Dell's reporting applications, but key Support Assists on a delayed start, however, finding out what to do was the painful bit, hence I created this script and scheduled it to get insight.

Rather than measuring boot duration manually, the script uses the performance data collected by Windows in the event log. This is not written instantly so the script will only be run after login and a short delay.

I used pwsh.exe to run the script because I have the latest powershell installed. If you have not updated powershell, just use powershell.exe instead - see Scheduled Task

Note that I have used a task parameters to prevent a popup window fro mthe powershell script but also checked the "hidden" box i nthe scheduled task to prevent the task from generatign a popup. 
I recommend doing both to ensure no user interuption. This is important because the task runs a few miutes after you log in and so these prevent the PC shifting focus away from whatever else you are running.

---

## setup

### Files
Create a folder and put the boot.ps1 in it

#### Sheduled Task
Open Windows task sheduler and create a new task. Ensure the user of the task is someone with administrator privilege.

#### General
- check the radio button "Run only when user is logged in"
- check the box "Run with highest privileges"
- check the box for "Hidden"
- Configure for "Windows 10" or higher. (Note that on Windows 11 machines, Windows 10 may be the only option).

#### Trigger
- Choose  "at log on"
- Check the radio for "Any user"
- Advanced settings. Add an additional 2 or 3 minute delay. 

#### Actions
- Create a start program action
- Set the program as pwsh.exe or powershell.exe
- Add arguments to hide the output, ignore the profile, and locate the script
-- NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\BootLog\boot.ps1"


Note that you cannot trigger this task "at startup" for several reasons.
- We are reding the windows diagnostic logs which will not yet have been written
- At startup, sone of the offending components we are interested in may not have run yet or may still be running
- We don't want this script to interfer with the processes we are trying to monitor

By default the script creates a file in a folder off the root of the system drive, but if you don't have permission write in this location, change this line at the top of the script
$CsvPath = "C:\BootLog\bootlog.csv"
to
$CsvPath = "$env:USERPROFILE\Documents\BootHistory.csv"

This wil lcreate the bootlog in your documents folder which, given you just logged in, you will definitely have access to.

---

## Understanding Windows Boot Timing

Windows records three high-level phases of startup.

### 1. Main Path Boot

The **Main Path Boot** phase covers the journey from power-on until Windows reaches a usable desktop.

It includes activities such as:

- Kernel initialization
- Driver initialization
- Service startup
- User profile loading
- Explorer startup
- Logon processing

Windows records this as:

```text
MainPathBootTime
```

---

### 2. Post Boot Activity

After the desktop appears, Windows continues loading background components.

Typical examples include:

- Startup applications
- Background services
- Update agents
- Cloud sync clients
- Device management software

Windows considers the system fully booted only after this activity completes.

Windows records this as:

```text
BootPostBootTime
```

---

### 3. Total Boot Time

Total Boot Time is simply:

```text
Main Path Boot
+
Post Boot Activity
=
Total Boot Time
```

Windows records this as:

```text
BootTime
```

This is the headline figure reported by the script.

---

## Data Sources

The script reads from:

```text
Microsoft-Windows-Diagnostics-Performance/Operational
```

and uses:

| Event ID | Purpose |
|-----------|----------|
| 100 | Overall boot performance |
| 101 | Slow startup applications |
| 103 | Slow startup services |

These events are generated automatically by Windows after each boot.

---

## What the Script Does

At login, the script:

1. Retrieves the latest Event 100 boot record.
2. Extracts:
   - Total Boot Time
   - Main Path Boot Time
   - Post Boot Time
3. Retrieves Event 101 records associated with the same boot.
4. Identifies the three applications with the highest startup degradation time.
5. Appends the results to a CSV file.

---

## CSV Output

Example:

```csv
Timestamp,BootSeconds,MainPathSeconds,PostBootSeconds,Top1,Delay1,Top2,Delay2,Top3,Delay3
19/11/2026 11:57:06,66.4,41.5,24.9,svchost.exe,17.5,WmiPrvSE.exe,6.7,TiWorker.exe,3.2
```

### Columns

| Column | Description |
|----------|----------|
| Timestamp | Time of the Event 100 record |
| BootSeconds | Total boot duration |
| MainPathSeconds | Windows startup time before post-boot activity |
| PostBootSeconds | Background startup activity duration |
| Top1-Top3 | Worst startup applications reported by Event 101 |
| Delay1-Delay3 | Startup degradation time for each application |

---

## Requirements

- Windows 11
- PowerShell 7+ (recommended)
- Access to the Diagnostics Performance event log
- Scheduled Task configured to run with elevated privileges

---

## Typical Uses

- Detect gradual boot degradation over time
- Identify slow startup applications
- Compare system changes before and after software installations
- Measure the impact of startup services and security software
- Provide historical boot performance data for troubleshooting

---

## Notes

The script relies entirely on Windows performance telemetry and does not perform its own timing measurements.

As a result, the recorded values closely match those displayed by Windows Performance Diagnostics and are generally more reliable than measuring startup duration manually.