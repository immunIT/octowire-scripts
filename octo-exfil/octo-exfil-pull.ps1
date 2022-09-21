# Octowire MicroSD Exfiltration Script
# Written by Paul Duncan <eresse@dooba.io>
# Pulls file directly from MicroSD card blocks (starting @ STARTBLK) using Octowire on COM port <COMPORT>
# Usage: octo-exfil-pull.ps1 <COMPORT> <STARTBLK>

# Block Size
$CS = 512

# Read Block
function OctoReadBlk {
    $bytes = [System.Collections.ArrayList]::new()
    for($i = 0; $i -lt ($CS / 16); $i = $i + 1) {
        $bytes = $bytes + $uart.ReadLine().Split(" ")[0 .. 15]
    }
    return $bytes
}

# Check Args
if($args.count -lt 2) { write-host "Usage: ./octo-exfil-pull.ps1 <COMPORT> <STARTBLK>"; exit }
$u = $args[0]
$b = [int]$args[1]

# Open UART
write-host "Connecting Serial Port (UART): [$u]..."
$uart = New-Object System.IO.Ports.SerialPort("$u",7372800, "None", 8, "one")
$uart.Open()
sleep 1
$junk = $uart.ReadExisting()
$uart.WriteLine("ver")
Start-Sleep -Milliseconds 150
$ver = $uart.ReadExisting().Replace("`r", '').Split("`n")[2]
write-host "Detected Octowire Version: [$ver]"

# Read Head Block, Extract File Name & Size
$blk = $b
$uart.WriteLine("mci rx $blk 1")
$junk = $uart.ReadLine()
$junk = $uart.ReadLine()
$r = OctoReadBlk
$fname = ""
$fsize_s = ""
for($i = 8; (($i -lt $r.count) -and ($r[$i] -ne "00")); $i = $i + 1) { $fname = $fname + [char][byte][convert]::ToInt32($r[$i], 16) }
for($i = 0; $i -lt 8; $i = $i + 1) { $fsize_s = $fsize_s + [char][byte][convert]::ToInt32($r[$i], 16) }
$fsize = [convert]::ToInt32($fsize_s, 16)
write-host "Found File [$fname] ($fsize bytes) @ Block $blk - Extracting..."
$blk = $blk + 1

# Extract File Data
$t = 0
$fdata = [System.Collections.ArrayList]::new()
for($i = 0; $i -lt $fsize; $i = $i + $CS) {
    $uart.WriteLine("mci rx $blk 1")
    $junk = $uart.ReadLine()
    $junk = $uart.ReadLine()
    $xs = $CS
    if(($fsize - $t) -lt $CS) { $xs = $fsize - $t }
    $t = $t + $xs
    write-host -NoNewline "`r * Reading block $blk - $t / $fsize bytes...   "
    $x = OctoReadBlk
    for($j = 0; $j -lt $x.count; $j = $j + 1) { $x[$j] = [byte][convert]::ToInt32($x[$j], 16) }
    $fdata = $fdata + $x
    $blk = $blk + 1
}

# Write File Data
[System.IO.File]::WriteAllBytes("$(Get-Location)\\$fname", $fdata[0 .. ($fsize - 1)])

# Close
$uart.Close()