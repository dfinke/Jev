param()

# WPF requires an STA thread. Relaunch in STA when needed.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $powerShellExe = (Get-Process -Id $PID).Path
    $scriptArgument = '"{0}"' -f $PSCommandPath
    Start-Process -FilePath $powerShellExe -ArgumentList @('-NoProfile', '-STA', '-File', $scriptArgument)
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$script:tutorialRoot = $PSScriptRoot

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Jev Tutorial Lab" Height="900" Width="1320"
        MinHeight="720" MinWidth="1040" WindowStartupLocation="CenterScreen" WindowState="Maximized"
        Background="#0B1020" FontFamily="Segoe UI" Foreground="#E5EAF5">
    <Window.Resources>
        <SolidColorBrush x:Key="PanelBrush" Color="#111A2D" />
        <SolidColorBrush x:Key="PanelBorderBrush" Color="#26344D" />
        <SolidColorBrush x:Key="MutedBrush" Color="#8FA0BA" />
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="#07111F" />
            <Setter Property="Background" Value="#7CC4FF" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Padding" Value="18,11" />
            <Setter Property="FontSize" Value="14" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.86" />
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="ButtonBorder" Property="Opacity" Value="0.42" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="QuietButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Foreground" Value="#D6E0F0" />
            <Setter Property="Background" Value="#1B2940" />
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="Padding" Value="12,11" />
            <Setter Property="Margin" Value="0,3" />
            <Setter Property="Background" Value="#111A2D" />
            <Setter Property="Foreground" Value="#D6E0F0" />
            <Setter Property="HorizontalContentAlignment" Value="Stretch" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="ItemBorder" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#1A3554" />
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ItemBorder" Property="BorderBrush" Value="#385A7C" />
                                <Setter TargetName="ItemBorder" Property="BorderThickness" Value="1" />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="22">
        <Grid.RowDefinitions>
            <RowDefinition Height="82" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>
        <Grid Grid.Row="0" Margin="0,0,0,18">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>
            <StackPanel VerticalAlignment="Center">
                <TextBlock Text="Jev Tutorial Lab" FontSize="27" FontWeight="Bold" />
                <TextBlock Text="Explore each lesson, inspect the PowerShell, then run it against Jev." FontSize="13" Foreground="{StaticResource MutedBrush}" Margin="1,4,0,0" />
            </StackPanel>
            <Border Grid.Column="1" Background="#132B2A" BorderBrush="#24544B" BorderThickness="1" CornerRadius="18" Padding="13,8" VerticalAlignment="Center">
                <StackPanel Orientation="Horizontal">
                    <Ellipse x:Name="ApiStatusDot" Width="8" Height="8" Fill="#5DD6A0" VerticalAlignment="Center" Margin="0,0,8,0" />
                    <TextBlock x:Name="ApiStatusText" Text="API KEY READY" FontSize="11" FontWeight="Bold" Foreground="#8DE3BD" />
                </StackPanel>
            </Border>
        </Grid>
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="260" />
                <ColumnDefinition Width="18" />
                <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="{StaticResource PanelBrush}" BorderBrush="{StaticResource PanelBorderBrush}" BorderThickness="1" CornerRadius="14" Padding="14">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top" Margin="2,2,2,12">
                        <TextBlock Text="LESSONS" FontSize="11" FontWeight="Bold" Foreground="{StaticResource MutedBrush}" />
                        <TextBlock Text="Eight short, runnable examples" FontSize="12" Foreground="#C1CCE0" Margin="0,5,0,0" />
                    </StackPanel>
                    <ListBox x:Name="LessonList" Background="Transparent" BorderThickness="0" ScrollViewer.VerticalScrollBarVisibility="Auto" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <StackPanel>
                                    <TextBlock Text="{Binding Heading}" FontSize="10" FontWeight="Bold" Foreground="#71BFFF" />
                                    <TextBlock Text="{Binding Title}" FontSize="14" FontWeight="SemiBold" Margin="0,3,0,0" />
                                    <TextBlock Text="{Binding Summary}" FontSize="11" Foreground="#9AAAC1" TextWrapping="Wrap" Margin="0,4,0,0" />
                                </StackPanel>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                </DockPanel>
            </Border>
            <Grid Grid.Column="2">
                <Grid.RowDefinitions>
                    <RowDefinition Height="58" />
                    <RowDefinition Height="*" />
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,11">
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="SelectedTitle" Text="Choose a lesson" FontSize="19" FontWeight="Bold" />
                        <TextBlock x:Name="SelectedDescription" Text="Select a lesson from the list." FontSize="12" Foreground="{StaticResource MutedBrush}" Margin="0,3,0,0" />
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <Button x:Name="ClearButton" Content="Clear results" ToolTip="Clear results (Ctrl+Shift+X)" Style="{StaticResource QuietButton}" Margin="0,0,9,0" />
                        <Button x:Name="RunButton" Content="Run lesson" ToolTip="Run this lesson (Ctrl+Enter)" />
                    </StackPanel>
                </Grid>
                <Grid Grid.Row="1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.35*" />
                        <ColumnDefinition Width="14" />
                        <ColumnDefinition Width="1*" />
                    </Grid.ColumnDefinitions>
                    <Grid Grid.Column="0">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="1.45*" />
                            <RowDefinition Height="14" />
                            <RowDefinition Height="1*" />
                        </Grid.RowDefinitions>
                        <Border Grid.Row="0" Background="{StaticResource PanelBrush}" BorderBrush="{StaticResource PanelBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="15">
                            <DockPanel>
                                <Grid DockPanel.Dock="Top" Margin="1,0,0,9">
                                    <TextBlock Text="SCRIPT · EDITABLE" FontSize="10" FontWeight="Bold" Foreground="{StaticResource MutedBrush}" />
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                        <TextBlock x:Name="ScriptFileLabel" VerticalAlignment="Center" FontSize="10" Foreground="#71829D" Margin="0,0,8,0" />
                                        <Button x:Name="ExpandScriptButton" Content="&#xE740;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="28" Height="25" Padding="0" Style="{StaticResource QuietButton}" ToolTip="Expand script preview" />
                                    </StackPanel>
                                </Grid>
                                <TextBox x:Name="ScriptPreview" IsReadOnly="False" AcceptsReturn="True" AcceptsTab="True" FontFamily="Cascadia Code,Consolas" FontSize="13" Foreground="#D9E7F8" Background="#0B1220" BorderThickness="0" Padding="13" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap" />
                            </DockPanel>
                        </Border>
                        <Border Grid.Row="2" Background="{StaticResource PanelBrush}" BorderBrush="{StaticResource PanelBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="15">
                            <DockPanel>
                                <Grid DockPanel.Dock="Top" Margin="1,0,0,9">
                                    <TextBlock Text="RESULT" FontSize="10" FontWeight="Bold" Foreground="{StaticResource MutedBrush}" />
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                        <TextBlock x:Name="RunStatus" Text="Ready" VerticalAlignment="Center" FontSize="11" FontWeight="SemiBold" Foreground="#8ECFFF" Margin="0,0,8,0" />
                                        <Button x:Name="ExpandResultButton" Content="&#xE740;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="28" Height="25" Padding="0" Style="{StaticResource QuietButton}" ToolTip="Expand results" />
                                    </StackPanel>
                                </Grid>
                                <TextBox x:Name="ResultPreview" IsReadOnly="True" AcceptsReturn="True" FontFamily="Cascadia Code,Consolas" FontSize="12" Foreground="#D6E3F3" Background="#0B1220" BorderThickness="0" Padding="12" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap" Text="Choose a lesson, then run it to see the live result here." />
                            </DockPanel>
                        </Border>
                    </Grid>
                    <Border Grid.Column="2" Background="{StaticResource PanelBrush}" BorderBrush="{StaticResource PanelBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="15">
                        <DockPanel>
                            <Grid DockPanel.Dock="Top" Margin="1,0,0,9">
                                <TextBlock x:Name="InputPanelTitle" Text="SAMPLE INPUT · EDITABLE" FontSize="10" FontWeight="Bold" Foreground="{StaticResource MutedBrush}" />
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                    <TextBlock x:Name="InputFileLabel" VerticalAlignment="Center" FontSize="10" Foreground="#71829D" Margin="0,0,8,0" />
                                    <Button x:Name="ExpandInputButton" Content="&#xE740;" FontFamily="Segoe MDL2 Assets" FontSize="13" Width="28" Height="25" Padding="0" Style="{StaticResource QuietButton}" ToolTip="Expand sample input" />
                                </StackPanel>
                            </Grid>
                            <TextBox x:Name="InputPreview" IsReadOnly="False" AcceptsReturn="True" FontFamily="Cascadia Code,Consolas" FontSize="12" Foreground="#BBD0E8" Background="#0B1220" BorderThickness="0" Padding="12" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" />
                        </DockPanel>
                    </Border>
                </Grid>
                <Border x:Name="ExpandOverlay" Grid.Row="1" Panel.ZIndex="10" Visibility="Collapsed" Background="{StaticResource PanelBrush}" BorderBrush="{StaticResource PanelBorderBrush}" BorderThickness="1" CornerRadius="12" Padding="16">
                    <DockPanel>
                        <Grid DockPanel.Dock="Top" Margin="1,0,0,12">
                            <TextBlock x:Name="ExpandedTitle" Text="Expanded view" FontSize="12" FontWeight="Bold" Foreground="{StaticResource MutedBrush}" VerticalAlignment="Center" />
                            <Button x:Name="CollapseButton" Content="&#xE73F;" FontFamily="Segoe MDL2 Assets" FontSize="14" Width="32" Height="29" Padding="0" HorizontalAlignment="Right" Style="{StaticResource QuietButton}" ToolTip="Restore normal layout" />
                        </Grid>
        <TextBox x:Name="ExpandedPreview" IsReadOnly="True" AcceptsReturn="True" AcceptsTab="True" FontFamily="Cascadia Code,Consolas" FontSize="14" Foreground="#D9E7F8" Background="#0B1220" BorderThickness="0" Padding="15" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap" />
                    </DockPanel>
                </Border>
            </Grid>
        </Grid>
    </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Load([System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml)))
$controlNames = @(
    'ApiStatusDot', 'ApiStatusText', 'LessonList', 'SelectedTitle', 'SelectedDescription',
    'ClearButton', 'RunButton', 'ScriptFileLabel', 'ScriptPreview', 'ExpandScriptButton',
    'InputPanelTitle', 'InputFileLabel', 'InputPreview', 'ExpandInputButton', 'RunStatus', 'ResultPreview',
    'ExpandResultButton', 'ExpandOverlay', 'ExpandedTitle', 'ExpandedPreview', 'CollapseButton'
)
foreach ($name in $controlNames) {
    Set-Variable -Name $name -Value $window.FindName($name) -Scope Script
}

$script:lessons = @(
    [pscustomobject]@{ Heading = '01 | NOUL'; Title = 'Ask one yes-or-no question'; Summary = 'Give Jev one state and get a Boolean answer.'; Script = '01-Ask-YesNo.ps1'; Input = $null }
    [pscustomobject]@{ Heading = '02 | CHOICE'; Title = 'Route a support ticket'; Summary = 'Compare a real-world issue against three queue descriptions.'; Script = '02-Route-Ticket.ps1'; Input = $null }
    [pscustomobject]@{ Heading = '03 | FILTER'; Title = 'Select matching messages'; Summary = 'Keep the original inputs that meet a threshold.'; Script = '03-Select-Messages.ps1'; Input = 'messages.txt' }
    [pscustomobject]@{ Heading = '04 | FIND'; Title = 'Find the best match'; Summary = 'Compare candidates together in one Choice request.'; Script = '04-Find-BestMatch.ps1'; Input = 'messages.txt' }
    [pscustomobject]@{ Heading = '05 | RANK'; Title = 'Rank by urgency'; Summary = 'Judge each item, then sort the original inputs.'; Script = '05-Rank-ByUrgency.ps1'; Input = 'messages.txt' }
    [pscustomobject]@{ Heading = '06 | ANNOTATE'; Title = 'Annotate and route'; Summary = 'Add a category, then use a PowerShell switch.'; Script = '06-Annotate-And-Route.ps1'; Input = 'messages.txt' }
    [pscustomobject]@{ Heading = '07 | SCORE'; Title = 'Score urgency'; Summary = 'Use an ordered scale and sort the worklist.'; Script = '07-Score-Urgency.ps1'; Input = 'messages.txt' }
    [pscustomobject]@{ Heading = '08 | TAG'; Title = 'Apply overlapping tags'; Summary = 'Let several independent labels match at once.'; Script = '08-Tag-Messages.ps1'; Input = 'messages.txt' }
    [pscustomobject]@{ Heading = '09 | GUARDRAIL'; Title = 'Preview a guarded action'; Summary = 'Interpret intent, then apply local policy.'; Script = '09-Guarded-Tool-Preview.ps1'; Input = 'guarded-request.json' }
)

$script:activeJob = $null
$script:runStopwatch = $null
$script:expandedSource = $null
$script:timer = [Windows.Threading.DispatcherTimer]::new()
$script:timer.Interval = [TimeSpan]::FromMilliseconds(100)

$script:LessonList.ItemsSource = $script:lessons
$script:LessonList.SelectedIndex = 0

if ([string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)) {
    $script:ApiStatusDot.Fill = [Windows.Media.BrushConverter]::new().ConvertFromString('#F2B35E')
    $script:ApiStatusText.Text = 'SET TYPESAFE_API_KEY TO RUN'
    $script:ApiStatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#F2B35E')
    $script:RunButton.IsEnabled = $false
    $script:RunStatus.Text = 'API key required to run live examples'
}

$updateSelection = {
    $lesson = $script:LessonList.SelectedItem
    if ($null -eq $lesson) { return }

    $script:SelectedTitle.Text = $lesson.Title
    $script:SelectedDescription.Text = $lesson.Summary
    $script:ScriptFileLabel.Text = $lesson.Script
    $script:InputPanelTitle.Text = if ($lesson.Input) { 'SAMPLE INPUT · EDITABLE' } else { 'STATE & QUESTION IN SCRIPT' }
    $script:InputFileLabel.Text = if ($lesson.Input) { $lesson.Input } else { 'inline in script' }
    $script:ScriptPreview.Text = Get-Content -LiteralPath (Join-Path $script:tutorialRoot $lesson.Script) -Raw
    if ($lesson.Input) {
        $script:InputPreview.IsReadOnly = $false
        $script:InputPreview.Text = Get-Content -LiteralPath (Join-Path $script:tutorialRoot $lesson.Input) -Raw
    }
    else {
        $script:InputPreview.IsReadOnly = $true
        $script:InputPreview.Text = 'This first example keeps both $state and $question in the script. Edit them in the Script pane.'
    }
    if ($script:activeJob -eq $null) {
        $script:RunStatus.Text = 'Ready'
    }
}

$script:LessonList.Add_SelectionChanged($updateSelection)
$script:LessonList.SelectedIndex = 0

$script:expandPanel = {
    param($sourceTextBox, [string] $title)
    $script:expandedSource = $sourceTextBox
    $script:ExpandedPreview.IsReadOnly = $sourceTextBox.IsReadOnly
    $script:ExpandedTitle.Text = if ($sourceTextBox.IsReadOnly) { $title } else { "$title · EDITABLE" }
    $script:ExpandedPreview.Text = $sourceTextBox.Text
    $script:ExpandOverlay.Visibility = [System.Windows.Visibility]::Visible
    $script:ExpandedPreview.Focus() | Out-Null
}

$script:collapsePanel = {
    $script:ExpandOverlay.Visibility = [System.Windows.Visibility]::Collapsed
    $script:expandedSource = $null
}

$script:clearResults = {
    $script:ResultPreview.Clear()
    if ($null -eq $script:activeJob) { $script:RunStatus.Text = 'Ready' }
}

$script:ExpandScriptButton.Add_Click({ & $script:expandPanel $script:ScriptPreview 'Script' })
$script:ExpandInputButton.Add_Click({ & $script:expandPanel $script:InputPreview 'Sample Input' })
$script:ExpandResultButton.Add_Click({ & $script:expandPanel $script:ResultPreview 'Results' })
$script:CollapseButton.Add_Click({ & $script:collapsePanel })

$script:ScriptPreview.Add_TextChanged({
    if ($script:expandedSource -eq $script:ScriptPreview) { $script:ExpandedPreview.Text = $script:ScriptPreview.Text }
})
$script:InputPreview.Add_TextChanged({
    if ($script:expandedSource -eq $script:InputPreview) { $script:ExpandedPreview.Text = $script:InputPreview.Text }
})
$script:ResultPreview.Add_TextChanged({
    if ($script:expandedSource -eq $script:ResultPreview) { $script:ExpandedPreview.Text = $script:ResultPreview.Text }
})
$script:ExpandedPreview.Add_TextChanged({
    if ($null -ne $script:expandedSource -and $script:expandedSource.IsReadOnly -eq $false -and $script:expandedSource.Text -cne $script:ExpandedPreview.Text) {
        $script:expandedSource.Text = $script:ExpandedPreview.Text
    }
})

$script:timer.Add_Tick({
    if ($null -eq $script:activeJob) { return }
    if ($script:activeJob.State -notin @('Completed', 'Failed', 'Stopped')) {
        $elapsed = $script:runStopwatch.Elapsed.TotalSeconds
        $script:RunStatus.Text = 'Running - {0:N1}s' -f $elapsed
        return
    }

    $jobState = $script:activeJob.State
    $script:runStopwatch.Stop()
    $elapsed = '{0:N2}s' -f $script:runStopwatch.Elapsed.TotalSeconds
    $output = @(Receive-Job -Job $script:activeJob -ErrorAction SilentlyContinue)
    if ($output.Count -gt 0) {
        $resultText = ($output | ForEach-Object { [string] $_ }) -join [Environment]::NewLine
        $script:ResultPreview.Text = $resultText
        if ($resultText -match '(?m)^ERROR:') { $jobState = 'Failed' }
    }
    elseif ($jobState -eq 'Completed') {
        $script:ResultPreview.Text = 'The script completed without writing output.'
    }

    $script:RunStatus.Text = switch ($jobState) {
        Completed { "Complete - $elapsed" }
        Failed    { "Failed - $elapsed" }
        Stopped   { "Stopped - $elapsed" }
    }
    Remove-Job -Job $script:activeJob -Force -ErrorAction SilentlyContinue
    $script:activeJob = $null
    $script:RunButton.IsEnabled = -not [string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)
})

$script:runSelectedLesson = {
    if ($null -ne $script:activeJob) { return }
    $lesson = $script:LessonList.SelectedItem
    if ($null -eq $lesson) { return }

    $script:ResultPreview.Text = 'Running the selected lesson against Jev...'
    $script:RunButton.IsEnabled = $false
    $script:runStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $script:RunStatus.Text = 'Running - 0.0s'
    $scriptPath = $lesson.Script
    $inputPath = $lesson.Input
    $scriptText = $script:ScriptPreview.Text
    $inputText = $script:InputPreview.Text
    $jevModulePath = (Resolve-Path (Join-Path $script:tutorialRoot '..\Jev.psd1')).Path
    $script:activeJob = Start-Job -ArgumentList $scriptPath, $inputPath, $scriptText, $inputText, $jevModulePath -ScriptBlock {
        param($scriptName, $inputName, $editedScript, $editedInput, $modulePath)
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('JevTutorial-' + [guid]::NewGuid().ToString('N'))
        $tempTutorial = Join-Path $tempRoot 'Tutorial'
        try {
            New-Item -ItemType Directory -Path $tempTutorial -Force -ErrorAction Stop | Out-Null
            $utf8WithBom = [System.Text.UTF8Encoding]::new($true)
            [System.IO.File]::WriteAllText((Join-Path $tempTutorial $scriptName), $editedScript, $utf8WithBom)
            if (-not [string]::IsNullOrWhiteSpace($inputName)) {
                [System.IO.File]::WriteAllText((Join-Path $tempTutorial $inputName), $editedInput, $utf8WithBom)
            }
            Import-Module $modulePath -Force -ErrorAction Stop
            $text = & (Join-Path $tempTutorial $scriptName) 2>&1 | Out-String -Width 180
            if ([string]::IsNullOrWhiteSpace($text)) { 'Completed without output.' } else { $text.TrimEnd() }
        }
        catch {
            "ERROR: $($_.Exception.Message)"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $script:timer.Start()
}

$script:RunButton.Add_Click($script:runSelectedLesson)
$window.Add_PreviewKeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::Escape -and $script:ExpandOverlay.Visibility -eq [System.Windows.Visibility]::Visible) {
        $eventArgs.Handled = $true
        & $script:collapsePanel
        return
    }
    $controlPressed = [bool]([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)
    $shiftPressed = [bool]([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift)
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::X -and $controlPressed -and $shiftPressed) {
        $eventArgs.Handled = $true
        & $script:clearResults
        return
    }
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::Enter -and $controlPressed) {
        $eventArgs.Handled = $true
        & $script:runSelectedLesson
    }
})

$script:ClearButton.Add_Click($script:clearResults)

$window.Add_Closing({
    $script:timer.Stop()
    if ($null -ne $script:runStopwatch) { $script:runStopwatch.Stop() }
    if ($null -ne $script:activeJob) {
        Stop-Job -Job $script:activeJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:activeJob -Force -ErrorAction SilentlyContinue
    }
})

& $updateSelection
$window.ShowDialog() | Out-Null
