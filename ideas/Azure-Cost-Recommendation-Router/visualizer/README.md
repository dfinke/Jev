# Azure Cost Flow visualizer

A small Wails desktop app that animates the existing Azure cost-recommendation router. It reads a CSV, runs the same PowerShell script and Jev question used by the command-line example, and lights up each step as a recommendation moves into a review lane.

## What it demonstrates

- Each CSV row is sent to Jev as one bounded `Choice` classification.
- PowerShell's `switch` maps the returned lane to a route.
- A live flowchart, current-record panel, and run totals show what happened. The current record and routed-items summary appear above the compact flowchart, where a red marker travels through the active path into its review lane.
- Fast, walkthrough, and slow modes control the pause between visible steps.
- A light/dark mode toggle remembers the selected theme.

The sample CSV includes 19 fictional recommendations across development, test, production, and unclear-owner scenarios.

This is an educational review aid. It does not connect to Azure or change resources. Each row makes a live Jev API request; the app does not mock responses. PowerShell inherits `TYPESAFE_API_KEY` from the environment, and the app does not display or pass the key as a command-line argument.

## Requirements

- Windows with WebView2 installed
- Go and Wails CLI v2 to develop or build the app
- PowerShell 7 (`pwsh`) on `PATH`
- The Jev module in this repository and a valid `TYPESAFE_API_KEY`

## Run the visualizer

From this folder, start the desktop app in development mode:

```powershell
wails dev
```

To create the Windows executable:

```powershell
wails build
```

The executable is written to `build/bin/visualizer.exe`. Keep it within this repository checkout: at startup, it locates the router script and sample CSV by searching its current directory and parent folders. The app needs the PowerShell script, Jev module, and CSV to remain available in the repository.

Set the API key in the environment before running the app:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
```

The sample file is selected automatically. Use **Choose CSV** to select another file with these exact columns:

`RecommendationId`, `ResourceType`, `Environment`, `Recommendation`, `PotentialMonthlySavingsUsd`, `OwnerNote`

The run writes `output/visualizer-results.csv` beside `Invoke-AzureCostRecommendationRouter.ps1`. The regular PowerShell example writes `output/cost-recommendation-triage.csv`.
