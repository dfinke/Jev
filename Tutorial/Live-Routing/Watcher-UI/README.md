# Live Routing WPF Dashboard

This WPF app watches the same live message stream as the console demo. Start
`Generate-Messages.ps1` in one PowerShell console, open this app in another,
then press **Start routing**. The dashboard reads the shared stream and shows
generated, completed, and waiting counts as the six queue bars animate. The
latest card shows the most recent decision. **Open queues** opens the JSONL
output folder, and **Stop** stops routing while leaving the generator running.

**Generated** counts messages written by `Generate-Messages.ps1`.
**Completed** counts decisions written to a queue or the failed file.
**Waiting** is the difference between generated and completed, making a growing
backlog visible.
Each decision still makes one Jev request; the throttle controls how many can
be in flight at once. The queue bars scale to the busiest queue, so their
relative volumes are easy to compare.

Run from any PowerShell 7 console on Windows:

```powershell
./Tutorial/Live-Routing/Watcher-UI/Watcher-UI.ps1
```

The app uses the local `Jev.psd1` in the repository. Both scripts use
`$env:TEMP\Jev-Live-Routing` by default, so the UI watches the exact file and
queues used by the console generator. Do not run the console watcher at the
same time as the WPF watcher; both would write to the same queue and status
files.
Change the default request concurrency with `-ThrottleLimit` (1–32):

```powershell
./Tutorial/Live-Routing/Watcher-UI/Watcher-UI.ps1 -ThrottleLimit 8
```

You can also pass the same `-RunDirectory` to both scripts to use another
folder. Closing the window stops its watcher; the generator keeps running in
its console.
