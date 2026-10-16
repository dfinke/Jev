param(
    [ValidateRange(1, 32)]
    [int] $ThrottleLimit = 4,

    [string] $RunDirectory = (Join-Path $env:TEMP 'Jev-Live-Routing')
)

if (-not $IsWindows) {
    throw 'Watcher-UI requires Windows because it uses WPF.'
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$modulePath = Join-Path $repoRoot 'Jev.psd1'
$watcherPath = Join-Path $PSScriptRoot '..\Watch-Routing.ps1'
$pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
$runDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$queueDirectory = Join-Path $runDirectory 'Queues'
$messagePath = Join-Path $runDirectory 'messages.jsonl'
$statusPath = Join-Path $runDirectory 'status.json'
$generatorStatusPath = Join-Path $runDirectory 'generator-status.json'

foreach ($path in @($modulePath, $watcherPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required demo file not found: $path"
    }
}

$windowXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Jev Live Routing" Width="1260" Height="850"
        MinWidth="980" MinHeight="720" WindowStartupLocation="CenterScreen"
        Background="#0A1020" Foreground="#EAF1FF" FontFamily="Segoe UI">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#F5F8FF" />
      <Setter Property="FontSize" Value="14" />
      <Setter Property="FontWeight" Value="SemiBold" />
      <Setter Property="Padding" Value="18,11" />
      <Setter Property="BorderThickness" Value="0" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.86" /></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.38" /></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="30">
    <Grid.RowDefinitions>
      <RowDefinition Height="78" />
      <RowDefinition Height="142" />
      <RowDefinition Height="*" />
      <RowDefinition Height="88" />
    </Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="0,0,0,18">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
      <StackPanel VerticalAlignment="Center">
        <TextBlock Text="JEV  /  LIVE ROUTING" Foreground="#71C7FF" FontSize="11" FontWeight="Bold" />
        <TextBlock Text="Watch messages find their queue." FontSize="27" FontWeight="SemiBold" Margin="0,5,0,0" />
      </StackPanel>
      <Border Grid.Column="1" Background="#122237" BorderBrush="#203B57" BorderThickness="1" CornerRadius="18" Padding="14,8" VerticalAlignment="Center">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#64748B" Margin="0,0,9,0" />
          <TextBlock x:Name="StatusText" Text="READY" FontSize="11" FontWeight="Bold" Foreground="#A8B8D0" />
        </StackPanel>
      </Border>
    </Grid>

    <Grid Grid.Row="1" Margin="0,0,0,18">
      <Grid.ColumnDefinitions><ColumnDefinition Width="1*" /><ColumnDefinition Width="1*" /><ColumnDefinition Width="1*" /><ColumnDefinition Width="1*" /></Grid.ColumnDefinitions>
      <Border Grid.Column="0" Background="#111D31" BorderBrush="#203149" BorderThickness="1" CornerRadius="16" Padding="18,16" Margin="0,0,10,0">
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="MESSAGES GENERATED" Foreground="#8EA2BE" FontSize="10" FontWeight="Bold" />
          <TextBlock x:Name="GeneratedText" Text="0" FontSize="36" FontWeight="SemiBold" Foreground="#38BDF8" FontFamily="Consolas" Margin="0,7,0,1" />
          <TextBlock Text="Written to the input stream" Foreground="#71839D" FontSize="11" />
        </StackPanel>
      </Border>
      <Border Grid.Column="1" Background="#111D31" BorderBrush="#203149" BorderThickness="1" CornerRadius="16" Padding="18,16" Margin="0,0,10,0">
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="DECISIONS COMPLETED" Foreground="#8EA2BE" FontSize="10" FontWeight="Bold" />
          <TextBlock x:Name="ProcessedText" Text="0" FontSize="36" FontWeight="SemiBold" Foreground="#73D5FF" FontFamily="Consolas" Margin="0,7,0,1" />
          <TextBlock Text="Routed or recorded as failed" Foreground="#71839D" FontSize="11" />
        </StackPanel>
      </Border>
      <Border Grid.Column="2" Background="#111D31" BorderBrush="#203149" BorderThickness="1" CornerRadius="16" Padding="18,16" Margin="0,0,10,0">
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="WAITING TO ROUTE" Foreground="#8EA2BE" FontSize="10" FontWeight="Bold" />
          <TextBlock x:Name="PendingText" Text="0" FontSize="36" FontWeight="SemiBold" Foreground="#C4B5FD" FontFamily="Consolas" Margin="0,7,0,1" />
          <TextBlock Text="Generated minus completed" Foreground="#71839D" FontSize="11" />
        </StackPanel>
      </Border>
      <Border Grid.Column="3" Background="#111D31" BorderBrush="#203149" BorderThickness="1" CornerRadius="16" Padding="18,16">
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="NEEDS ATTENTION" Foreground="#8EA2BE" FontSize="10" FontWeight="Bold" />
          <TextBlock x:Name="FailedText" Text="0" FontSize="36" FontWeight="SemiBold" Foreground="#FDBA74" FontFamily="Consolas" Margin="0,7,0,1" />
          <TextBlock Text="Requests or records that could not route" Foreground="#71839D" FontSize="11" TextWrapping="Wrap" />
        </StackPanel>
      </Border>
    </Grid>

    <Grid Grid.Row="2" Margin="0,0,0,18">
      <Grid.ColumnDefinitions><ColumnDefinition Width="1.18*" /><ColumnDefinition Width="0.82*" /></Grid.ColumnDefinitions>
      <Border Grid.Column="0" Background="#111D31" BorderBrush="#203149" BorderThickness="1" CornerRadius="16" Padding="24" Margin="0,0,12,0">
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="*" /><RowDefinition Height="Auto" /></Grid.RowDefinitions>
          <TextBlock Text="Queue traffic" FontSize="18" FontWeight="SemiBold" />
          <TextBlock Grid.Row="1" Text="Live volume by destination · bars scale to the busiest queue" Foreground="#8193AE" FontSize="12" Margin="0,5,0,20" />
          <StackPanel x:Name="QueueList" Grid.Row="2" VerticalAlignment="Center" />
          <TextBlock Grid.Row="3" Text="Each message is classified against all six queue descriptions." Foreground="#71839D" FontSize="11" Margin="0,15,0,0" />
        </Grid>
      </Border>

      <Border Grid.Column="1" Background="#111D31" BorderBrush="#203149" BorderThickness="1" CornerRadius="16" Padding="24">
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="Auto" /><RowDefinition Height="*" /><RowDefinition Height="Auto" /></Grid.RowDefinitions>
          <TextBlock Text="Latest decision" FontSize="18" FontWeight="SemiBold" />
          <TextBlock Grid.Row="1" Text="The most recently completed route" Foreground="#8193AE" FontSize="12" Margin="0,5,0,18" />
          <Border x:Name="LatestBadgeBorder" Grid.Row="2" Background="#1B2B42" BorderBrush="#29415E" BorderThickness="1" CornerRadius="12" Padding="17" VerticalAlignment="Top">
            <StackPanel>
              <Border x:Name="LatestBadge" Background="#203B57" CornerRadius="12" Padding="10,5" HorizontalAlignment="Left" Margin="0,0,0,14">
                <TextBlock x:Name="LatestBadgeText" Text="WAITING" FontSize="10" FontWeight="Bold" Foreground="#A8DFFF" />
              </Border>
              <TextBlock x:Name="LatestMessageText" Text="Start the generator in a console, then start routing here." Foreground="#E5EDFA" FontSize="16" TextWrapping="Wrap" LineHeight="24" />
              <TextBlock x:Name="LatestErrorText" Foreground="#FDBA74" FontSize="12" TextWrapping="Wrap" Margin="0,12,0,0" Visibility="Collapsed" />
            </StackPanel>
          </Border>
          <TextBlock Grid.Row="3" Text="Inspect saved routes in the queue folder." Foreground="#71839D" FontSize="11" Margin="0,15,0,0" />
        </Grid>
      </Border>
    </Grid>

    <Border Grid.Row="3" Background="#111D31" BorderBrush="#203149" BorderThickness="1" CornerRadius="16" Padding="18,12">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto" /><ColumnDefinition Width="250" /><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /><ColumnDefinition Width="Auto" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="2,0,15,0">
          <TextBlock Text="THROTTLE" Foreground="#8EA2BE" FontSize="10" FontWeight="Bold" />
          <TextBlock x:Name="ThrottleText" Text="4 requests at once" Foreground="#71839D" FontSize="10" Margin="0,2,0,0" />
        </StackPanel>
        <Slider x:Name="ThrottleSlider" Grid.Column="1" Minimum="1" Maximum="16" Value="4" TickFrequency="1" IsSnapToTickEnabled="True" VerticalAlignment="Center" />
        <TextBlock Grid.Column="2" x:Name="RunHintText" Text="Ready when you are" Foreground="#8193AE" FontSize="12" VerticalAlignment="Center" Margin="14,0,10,0" />
        <Button x:Name="BrowseButton" Grid.Column="3" Content="Open queues" Background="#24344C" Margin="0,0,9,0" />
        <Button x:Name="StopButton" Grid.Column="4" Content="Stop" Background="#3A2631" IsEnabled="False" Margin="0,0,9,0" />
        <Button x:Name="StartButton" Grid.Column="5" Content="Start routing" Background="#1679B9" />
      </Grid>
    </Border>
  </Grid>
</Window>
'@

$xmlReader = [System.Xml.XmlNodeReader]::new([xml] $windowXaml)
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

$script:ui = @{}
foreach ($name in @('StatusDot', 'StatusText', 'GeneratedText', 'ProcessedText', 'PendingText', 'FailedText', 'ThrottleText', 'QueueList', 'LatestBadgeBorder', 'LatestBadge', 'LatestBadgeText', 'LatestMessageText', 'LatestErrorText', 'ThrottleSlider', 'RunHintText', 'BrowseButton', 'StopButton', 'StartButton')) {
    $script:ui[$name] = $window.FindName($name)
}

$script:categoryRows = @{}
$queueDefinitions = @(
    [pscustomobject]@{ Key = 'billing'; Name = 'Billing'; Color = '#38BDF8' }
    [pscustomobject]@{ Key = 'account'; Name = 'Account access'; Color = '#A78BFA' }
    [pscustomobject]@{ Key = 'bug'; Name = 'Product bug'; Color = '#FB7185' }
    [pscustomobject]@{ Key = 'feature_request'; Name = 'Feature request'; Color = '#34D399' }
    [pscustomobject]@{ Key = 'how_to'; Name = 'How-to'; Color = '#FBBF24' }
    [pscustomobject]@{ Key = 'other'; Name = 'Other'; Color = '#94A3B8' }
)
$brushConverter = [System.Windows.Media.BrushConverter]::new()
foreach ($definition in $queueDefinitions) {
    $row = [System.Windows.Controls.StackPanel]::new()
    $row.Margin = [System.Windows.Thickness]::new(0, 0, 0, 15)

    $labelGrid = [System.Windows.Controls.Grid]::new()
    $labelGrid.Margin = [System.Windows.Thickness]::new(0, 0, 0, 7)
    $labelGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
    $countColumn = [System.Windows.Controls.ColumnDefinition]::new()
    $countColumn.Width = [System.Windows.GridLength]::new(72)
    $labelGrid.ColumnDefinitions.Add($countColumn)

    $label = [System.Windows.Controls.TextBlock]::new()
    $label.Text = $definition.Name
    $label.FontSize = 13
    $label.Foreground = $brushConverter.ConvertFromString('#C9D5E7')
    [System.Windows.Controls.Grid]::SetColumn($label, 0)
    $labelGrid.Children.Add($label) | Out-Null

    $count = [System.Windows.Controls.TextBlock]::new()
    $count.Text = '0'
    $count.FontFamily = [System.Windows.Media.FontFamily]::new('Consolas')
    $count.FontSize = 13
    $count.FontWeight = [System.Windows.FontWeights]::SemiBold
    $count.TextAlignment = [System.Windows.TextAlignment]::Right
    $count.Foreground = $brushConverter.ConvertFromString($definition.Color)
    [System.Windows.Controls.Grid]::SetColumn($count, 1)
    $labelGrid.Children.Add($count) | Out-Null
    $row.Children.Add($labelGrid) | Out-Null

    $track = [System.Windows.Controls.Border]::new()
    $track.Height = 9
    $track.CornerRadius = [System.Windows.CornerRadius]::new(5)
    $track.Background = $brushConverter.ConvertFromString('#1B2B42')
    $track.ClipToBounds = $true

    $fill = [System.Windows.Controls.Border]::new()
    $fill.Width = 0
    $fill.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $fill.CornerRadius = [System.Windows.CornerRadius]::new(5)
    $fill.Background = $brushConverter.ConvertFromString($definition.Color)
    $track.Child = $fill
    $row.Children.Add($track) | Out-Null
    $script:ui.QueueList.Children.Add($row) | Out-Null

    $script:categoryRows[$definition.Key] = [pscustomobject]@{
        Count = $count
        Track = $track
        Fill  = $fill
        Name  = $definition.Name
        Color = $definition.Color
    }
}

$script:runDirectory = $runDirectory
$script:queueDirectory = $queueDirectory
$script:messagePath = $messagePath
$script:statusPath = $statusPath
$script:generatorStatusPath = $generatorStatusPath
$script:watcherProcess = $null
$script:running = $false
$script:startedOnce = $false
$script:displayedTotal = 0
$script:targetTotal = 0
$script:generatedTotal = 0
$script:lastStatus = $null

function ConvertTo-PowerShellLiteral {
    param([string] $Value)
    "'" + $Value.Replace("'", "''") + "'"
}

function Start-HiddenPowerShell {
    param([Parameter(Mandatory)][string] $Command)

    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    Start-Process -FilePath $pwshPath -WindowStyle Hidden -ArgumentList @('-NoLogo', '-NoProfile', '-EncodedCommand', $encodedCommand) -PassThru
}

function Set-UiStatus {
    param([string] $Text, [string] $Color)
    $script:ui.StatusText.Text = $Text.ToUpperInvariant()
    $script:ui.StatusDot.Fill = $brushConverter.ConvertFromString($Color)
}

function Stop-DemoProcesses {
    if ($script:watcherProcess -and -not $script:watcherProcess.HasExited) {
        Stop-Process -Id $script:watcherProcess.Id -Force -ErrorAction SilentlyContinue
    }
    $script:watcherProcess = $null
    $script:running = $false
    $script:ui.StartButton.IsEnabled = -not $script:startedOnce
    $script:ui.StopButton.IsEnabled = $false
    Set-UiStatus -Text 'Stopped' -Color '#64748B'
}

function Start-WatcherProcess {
    $moduleLiteral = ConvertTo-PowerShellLiteral $modulePath
    $watcherLiteral = ConvertTo-PowerShellLiteral $watcherPath
    $runLiteral = ConvertTo-PowerShellLiteral $script:runDirectory
    $statusLiteral = ConvertTo-PowerShellLiteral $script:statusPath
    $limit = [int] $script:ui.ThrottleSlider.Value
    $command = "Import-Module -Name $moduleLiteral -Force -ErrorAction Stop; & $watcherLiteral -RunDirectory $runLiteral -ThrottleLimit $limit -StatusPath $statusLiteral"
    $script:watcherProcess = Start-HiddenPowerShell -Command $command
    $script:statusTimer.Start()
    $script:ui.RunHintText.Text = "Routing with up to $limit concurrent Jev requests"
    Set-UiStatus -Text 'Routing live' -Color '#34D399'
}

function Start-Demo {
    if ($script:running) { return }

    if (-not (Test-Path -LiteralPath $script:messagePath)) {
        Set-UiStatus -Text 'Waiting for stream' -Color '#FBBF24'
        $script:ui.RunHintText.Text = 'Run Generate-Messages.ps1 in another console, then start routing.'
        $script:ui.LatestMessageText.Text = 'The watcher UI reads the same messages.jsonl stream as the console generator.'
        return
    }

    if ($script:startedOnce) {
        $script:ui.RunHintText.Text = 'This stream has already been read. Restart the generator and reopen the UI for a fresh run.'
        return
    }

    $script:running = $true
    $script:startedOnce = $true
    $script:displayedTotal = 0
    $script:targetTotal = 0
    $script:lastStatus = $null
    $script:ui.ProcessedText.Text = '0'
    $script:ui.FailedText.Text = '0'
    $script:ui.LatestBadgeText.Text = 'STARTING'
    $script:ui.LatestBadgeBorder.Background = $brushConverter.ConvertFromString('#203B57')
    $script:ui.LatestMessageText.Text = 'Waiting for the first message and Jev decision...'
    $script:ui.LatestErrorText.Visibility = [System.Windows.Visibility]::Collapsed
    foreach ($row in $script:categoryRows.Values) {
        $row.Count.Text = '0'
        $row.Fill.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $null)
        $row.Fill.Width = 0
    }

    Remove-Item -LiteralPath $script:statusPath -Force -ErrorAction SilentlyContinue
    try {
        Start-WatcherProcess
        $script:ui.StartButton.IsEnabled = $false
        $script:ui.StopButton.IsEnabled = $true
    }
    catch {
        $script:running = $false
        $script:startedOnce = $false
        $script:ui.StartButton.IsEnabled = $true
        $script:ui.StopButton.IsEnabled = $false
        Set-UiStatus -Text 'Could not start' -Color '#FB7185'
        $script:ui.RunHintText.Text = $_.Exception.Message
    }
}

function Update-UiFromStatus {
    if (-not (Test-Path -LiteralPath $script:statusPath)) { return }
    try {
        $status = Get-Content -LiteralPath $script:statusPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch { return }

    $script:lastStatus = $status
    $script:targetTotal = [int] $status.totalProcessed
    $script:ui.FailedText.Text = ([int] $status.failed).ToString('N0')

    $maxCount = 1
    foreach ($key in $script:categoryRows.Keys) {
        $count = [int] $status.counts.$key
        $script:categoryRows[$key].Count.Text = $count.ToString('N0')
        if ($count -gt $maxCount) { $maxCount = $count }
    }

    foreach ($key in $script:categoryRows.Keys) {
        $row = $script:categoryRows[$key]
        $count = [int] $status.counts.$key
        $targetWidth = if ($count -gt 0) { [Math]::Max(6, $row.Track.ActualWidth * $count / $maxCount) } else { 0 }
        if ($row.Track.ActualWidth -gt 0 -and [Math]::Abs($row.Fill.Width - $targetWidth) -gt 2) {
            $animation = [System.Windows.Media.Animation.DoubleAnimation]::new()
            $animation.To = [double] $targetWidth
            $animation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(420))
            $animation.EasingFunction = [System.Windows.Media.Animation.CubicEase]::new()
            $animation.EasingFunction.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
            $row.Fill.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $animation)
        }
    }

    $category = [string] $status.latestCategory
    $message = [string] $status.latestMessage
    if ($category) {
        $badge = if ($script:categoryRows.ContainsKey($category)) { $script:categoryRows[$category] } else { $null }
        if ($category -eq 'failed') {
            $script:ui.LatestBadgeText.Text = 'NEEDS ATTENTION'
            $script:ui.LatestBadgeText.Foreground = $brushConverter.ConvertFromString('#FED7AA')
            $script:ui.LatestBadge.Background = $brushConverter.ConvertFromString('#492B25')
            $script:ui.LatestBadgeBorder.BorderBrush = $brushConverter.ConvertFromString('#704332')
        }
        elseif ($badge) {
            $script:ui.LatestBadgeText.Text = $badge.Name.ToUpperInvariant()
            $script:ui.LatestBadgeText.Foreground = $brushConverter.ConvertFromString($badge.Color)
            $script:ui.LatestBadge.Background = $brushConverter.ConvertFromString('#203B57')
            $script:ui.LatestBadgeBorder.BorderBrush = $brushConverter.ConvertFromString('#29415E')
        }
        $script:ui.LatestMessageText.Text = $message
        if ($status.latestError) {
            $script:ui.LatestErrorText.Text = [string] $status.latestError
            $script:ui.LatestErrorText.Visibility = [System.Windows.Visibility]::Visible
        }
        else {
            $script:ui.LatestErrorText.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}

function Update-UiFromGeneratorStatus {
    if (-not (Test-Path -LiteralPath $script:generatorStatusPath)) { return }
    try {
        $generatorStatus = Get-Content -LiteralPath $script:generatorStatusPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch { return }

    $script:generatedTotal = [int] $generatorStatus.totalGenerated
    $script:ui.GeneratedText.Text = $script:generatedTotal.ToString('N0')
    $pending = [Math]::Max(0, $script:generatedTotal - $script:targetTotal)
    $script:ui.PendingText.Text = $pending.ToString('N0')
}

$script:statusTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:statusTimer.Interval = [TimeSpan]::FromMilliseconds(350)
$script:statusTimer.Add_Tick({
    Update-UiFromGeneratorStatus
    if ($script:watcherProcess -and $script:watcherProcess.HasExited) {
        Update-UiFromStatus
        $script:watcherProcess = $null
        $script:running = $false
        Set-UiStatus -Text 'Watcher stopped' -Color '#FB7185'
        $script:ui.RunHintText.Text = 'The router process exited. Reopen the UI after starting a fresh generator stream.'
        $script:ui.StartButton.IsEnabled = $false
        $script:ui.StopButton.IsEnabled = $false
    }
    elseif ($script:watcherProcess) { Update-UiFromStatus }
})

$script:countTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:countTimer.Interval = [TimeSpan]::FromMilliseconds(24)
$script:countTimer.Add_Tick({
    if ($script:displayedTotal -ge $script:targetTotal) { return }
    $difference = $script:targetTotal - $script:displayedTotal
    $step = [Math]::Max(1, [Math]::Ceiling($difference / 7))
    $script:displayedTotal = [Math]::Min($script:targetTotal, $script:displayedTotal + $step)
    $script:ui.ProcessedText.Text = ([int] $script:displayedTotal).ToString('N0')
})
$script:countTimer.Start()

$script:ui.ThrottleSlider.Add_ValueChanged({
    $limit = [int] [Math]::Round($script:ui.ThrottleSlider.Value)
    $script:ui.ThrottleText.Text = "$limit requests at once"
    if (-not $script:running) {
        $script:ui.RunHintText.Text = "Ready · up to $limit Jev requests at once"
    }
})
$script:ui.StartButton.Add_Click({ Start-Demo })
$script:ui.StopButton.Add_Click({
    Stop-DemoProcesses
    $script:ui.RunHintText.Text = 'Router stopped. The generator in the other console is still running.'
})
$script:ui.BrowseButton.Add_Click({
    New-Item -ItemType Directory -Path $script:queueDirectory -Force | Out-Null
    Start-Process -FilePath explorer.exe -ArgumentList $script:queueDirectory
})
$window.Add_Closing({
    $script:countTimer.Stop()
    $script:statusTimer.Stop()
    Stop-DemoProcesses
})

$script:ui.ThrottleText.Text = "$( [int] $script:ui.ThrottleSlider.Value ) requests at once"
$script:statusTimer.Start()
[void] $window.ShowDialog()
