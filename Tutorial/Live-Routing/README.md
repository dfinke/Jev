# Live Message Routing

Two PowerShell consoles make a small message router visible while it runs.
One script writes a random burst of realistic messages, then pauses for a
random number of seconds. The other watches the JSONL stream, asks Jev to pick
a queue, writes each result to a queue file, and redraws a console dashboard.

Jev sees only the message and chooses one of six queues. The script describes
what belongs in each queue, so Jev is choosing among clear categories rather
than guessing from label names: billing, account access, product bugs, feature
requests, how-to questions, or other. Each input makes one Jev request. A
request or parsing failure goes to `_failed.jsonl`; it is not counted as
`other`.

## Run it

From the Jev repository root, open two PowerShell consoles and load the module
in both:

```powershell
Import-Module ./Jev.psd1 -Force
```

In the first console, start the generator:

```powershell
./Tutorial/Live-Routing/Generate-Messages.ps1
```

It prints each burst size, running total, and randomly selected pause. In the
second console, start the router:

```powershell
./Tutorial/Live-Routing/Watch-Routing.ps1
```

The router reads any messages already written and keeps watching for new ones.
It runs up to four Jev requests at once by default; results may appear in a
different order than the messages arrived. Queue writes and dashboard counts
are applied one at a time after each decision completes. Set
`-ThrottleLimit` from 1 to 32 to tune concurrency. PowerShell 7 or later is
required. For example, start up to eight Jev requests at once with
`./Tutorial/Live-Routing/Watch-Routing.ps1 -ThrottleLimit 8`. Press Ctrl+C in
either console to stop that process.

For a visual dashboard with animated queue bars and a count-up total, start
`Generate-Messages.ps1` in one console, then run the
[Watcher-UI WPF app](Watcher-UI/README.md) in another and press **Start
routing**. The WPF app watches the same stream; it does not start a second
generator. Do not run the console watcher at the same time as the WPF watcher.

Messages and queue files are written under `$env:TEMP\Jev-Live-Routing`.
Starting a new generator resets the input stream, the six queue files, and the
failed-message file in that demo folder. Run one generator at a time.

## Adjust the rhythm

Both ends of each random range can be changed. This example generates bursts
of 5–15 messages and pauses for 2–8 seconds:

```powershell
./Tutorial/Live-Routing/Generate-Messages.ps1 `
    -MinBurstSize 5 -MaxBurstSize 15 `
    -MinPauseSeconds 2 -MaxPauseSeconds 8
```

The default burst range is 3–10 messages, with pauses of 3–10 seconds. The
generator samples from messages in each queue so all categories appear over
time.

## Inspect a queue

Each queue is a JSONL file containing the original message and Jev's selected
label. To inspect a queue:

```powershell
Get-Content -Encoding UTF8 "$env:TEMP\Jev-Live-Routing\Queues\billing.jsonl" |
    ForEach-Object { $_ | ConvertFrom-Json }
```

If you set `-RunDirectory` on the generator, pass the same path to
`Watch-Routing.ps1`. The watcher starts from the beginning of the current
message stream, so restart the generator before restarting the watcher to
avoid routing the same events twice.
