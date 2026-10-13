Clear-Host

# One ticket state, six typed questions, and a PowerShell-owned routing policy.
# Keep this block first so the decision model is easy to explain with the UI open.
$questions = @(
    New-JevQuestion -Name department -Type Choice `
        -Instructions 'Which queue should own this ticket?' `
        -Criteria @{
            bug_triage        = 'A defect in a specific feature, reproducible, goes into the backlog'
            incident_response = 'A live breakage affecting multiple users right now, needs a responder today'
            customer_success  = 'The account needs managing, not the code'
        }

    New-JevQuestion -Name goodwill_risk -Type Score `
        -Instructions 'How much patience does this customer have left?' `
        -Criteria @(
            'Reporting a problem, no sign of frustration'
            'Mildly annoyed, still collaborative'
            'Visibly out of patience, mentions the cost to their work'
            'At the point of escalating over our heads or leaving'
        )

    New-JevQuestion -Name is_time_sensitive -Type Noul `
        -Instructions 'Does this ticket need prompt attention to prevent or limit customer or business impact?' `
        -Criteria @{
            true  = 'An active outage, customers blocked from important work or purchases, ongoing business impact, or a specific near-term deadline or event'
            false = 'No current customer or business impact and no concrete deadline; the issue can wait without meaningful harm'
        }

    New-JevQuestion -Name has_reproduction -Type Noul `
        -Instructions 'Does the ticket contain enough detail to reproduce the problem?'

    New-JevQuestion -Name mentions_money -Type Noul `
        -Instructions 'Does the ticket mention lost revenue, refunds, or cancelling?'

    New-JevQuestion -Name is_automated -Type Noul `
        -Instructions 'Is this a machine-generated notification rather than a person writing in?'
)

# These are local policy thresholds, not Jev settings.
$autoRouteConfidence = 0.75
$yesThreshold = 0.8
$frustratedScore = 2.0

# Relaunch in STA when needed because WPF must run on a single-threaded apartment.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $powerShellExe = (Get-Process -Id $PID).Path
    $scriptArgument = '"{0}"' -f $PSCommandPath
    Start-Process -FilePath $powerShellExe -ArgumentList @('-NoProfile', '-STA', '-File', $scriptArgument)
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$ticketExamplesPath = Join-Path $PSScriptRoot 'ticket-examples.json'
$ticketExamples = @(Get-Content -LiteralPath $ticketExamplesPath -Raw | ConvertFrom-Json)
$jevModule = Get-Module -Name Jev | Select-Object -First 1
$jevModulePath = if ($jevModule) { $jevModule.Path } else { $null }
$questionsJson = ConvertTo-Json -InputObject $questions -Depth 20 -Compress

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Building a Ticket Router in One Jev Call"
        Height="900" Width="1440" MinHeight="720" MinWidth="1120"
        WindowStartupLocation="CenterScreen" WindowState="Maximized"
        Background="#F4F6F8" Foreground="#172B4D" FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="Ink" Color="#172B4D" />
        <SolidColorBrush x:Key="Muted" Color="#667085" />
        <SolidColorBrush x:Key="CardBorder" Color="#DDE3EA" />
        <Style TargetType="Button">
            <Setter Property="Background" Value="#3178C6" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="FontSize" Value="14" />
            <Setter Property="FontWeight" Value="SemiBold" />
            <Setter Property="Padding" Value="18,10" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="ButtonSurface" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonSurface" Property="Opacity" Value="0.88" /></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonSurface" Property="Opacity" Value="0.45" /></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="Padding" Value="12,10" />
            <Setter Property="Margin" Value="0,3" />
            <Setter Property="Background" Value="White" />
            <Setter Property="HorizontalContentAlignment" Value="Stretch" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="ItemSurface" Background="{TemplateBinding Background}" BorderBrush="#E5E9EF" BorderThickness="1" CornerRadius="7" Padding="{TemplateBinding Padding}">
                            <ContentPresenter />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True"><Setter TargetName="ItemSurface" Property="Background" Value="#EAF3FC" /><Setter TargetName="ItemSurface" Property="BorderBrush" Value="#76A9DC" /></Trigger>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ItemSurface" Property="BorderBrush" Value="#9CBADB" /></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="92" />
            <RowDefinition Height="*" />
            <RowDefinition Height="270" />
        </Grid.RowDefinitions>
        <Grid Grid.Row="0" Margin="0,0,0,16">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*" /><ColumnDefinition Width="Auto" /></Grid.ColumnDefinitions>
            <StackPanel VerticalAlignment="Center">
                <TextBlock Text="BUILDING A TICKET ROUTER IN ONE JEV CALL" FontSize="11" FontWeight="Bold" Foreground="#3178C6" />
                <TextBlock Text="Jev judges. PowerShell routes." FontSize="27" FontWeight="Bold" Margin="0,4,0,0" />
                <TextBlock Text="One support ticket, six typed questions, one local policy." FontSize="13" Foreground="{StaticResource Muted}" Margin="1,3,0,0" />
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Right" Margin="0,0,14,0">
                    <TextBlock x:Name="RunStatus" Text="Ready" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right" />
                    <TextBlock x:Name="RunTime" Text="" FontSize="11" Foreground="{StaticResource Muted}" HorizontalAlignment="Right" Margin="0,3,0,0" />
                </StackPanel>
                <Button x:Name="ClearButton" Content="Clear results" Background="#E8EDF3" Foreground="#344054" Margin="0,0,8,0" ToolTip="Clear the last result" />
                <Button x:Name="RunButton" Content="Run all six questions" ToolTip="Ctrl+Enter" />
            </StackPanel>
        </Grid>
        <Grid Grid.Row="1" Margin="0,0,0,16">
            <Grid.ColumnDefinitions><ColumnDefinition Width="300" /><ColumnDefinition Width="16" /><ColumnDefinition Width="1.15*" /><ColumnDefinition Width="16" /><ColumnDefinition Width="1*" /></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="White" BorderBrush="{StaticResource CardBorder}" BorderThickness="1" CornerRadius="10" Padding="15">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                        <TextBlock Text="SUPPORT TICKETS" FontSize="11" FontWeight="Bold" Foreground="#667085" />
                        <TextBlock Text="Choose a raw example" FontSize="13" Foreground="#344054" Margin="0,4,0,0" />
                    </StackPanel>
                    <ListBox x:Name="TicketList" BorderThickness="0" Background="Transparent" ScrollViewer.VerticalScrollBarVisibility="Auto">
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <StackPanel>
                                    <TextBlock Text="{Binding Title}" FontSize="13" FontWeight="SemiBold" Foreground="#172B4D" />
                                    <TextBlock Text="{Binding Preview}" FontSize="11" Foreground="#667085" TextWrapping="Wrap" Margin="0,4,0,0" />
                                </StackPanel>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                </DockPanel>
            </Border>
            <Border Grid.Column="2" Background="White" BorderBrush="{StaticResource CardBorder}" BorderThickness="1" CornerRadius="10" Padding="17">
                <DockPanel>
                    <Grid DockPanel.Dock="Top" Margin="0,0,0,10">
                        <StackPanel>
                            <TextBlock Text="SUPPORT TICKET · RAW TEXT" FontSize="11" FontWeight="Bold" Foreground="#667085" />
                            <TextBlock x:Name="SelectedTicketTitle" Text="" FontSize="13" FontWeight="SemiBold" Foreground="#344054" Margin="0,4,0,0" />
                        </StackPanel>
                        <TextBlock Text="Editable" FontSize="10" Foreground="#667085" HorizontalAlignment="Right" VerticalAlignment="Center" />
                    </Grid>
                    <TextBox x:Name="TicketText" AcceptsReturn="True" AcceptsTab="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontFamily="Cascadia Code,Consolas" FontSize="13" Foreground="#E6EDF5" Background="#1E293B" BorderThickness="0" Padding="15" />
                </DockPanel>
            </Border>
            <Border Grid.Column="4" Background="White" BorderBrush="{StaticResource CardBorder}" BorderThickness="1" CornerRadius="10" Padding="17">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top" Margin="0,0,0,12">
                        <TextBlock Text="QUESTIONS IN THIS CALL" FontSize="11" FontWeight="Bold" Foreground="#667085" />
                        <TextBlock Text="All six judge the same ticket." FontSize="13" Foreground="#344054" Margin="0,4,0,0" />
                    </StackPanel>
                    <StackPanel>
                        <Border Background="#F7F9FB" CornerRadius="7" Padding="10" Margin="0,2"><TextBlock Text="CHOICE   department · Which queue should own this ticket?" TextWrapping="Wrap" FontSize="12" /></Border>
                        <Border Background="#F7F9FB" CornerRadius="7" Padding="10" Margin="0,2"><TextBlock Text="SCORE   goodwill_risk · How much patience is left?" TextWrapping="Wrap" FontSize="12" /></Border>
                        <Border Background="#F7F9FB" CornerRadius="7" Padding="10" Margin="0,2"><TextBlock Text="NOUL   is_time_sensitive · Does this need prompt attention?" TextWrapping="Wrap" FontSize="12" /></Border>
                        <Border Background="#F7F9FB" CornerRadius="7" Padding="10" Margin="0,2"><TextBlock Text="NOUL   has_reproduction · Is there enough detail to reproduce it?" TextWrapping="Wrap" FontSize="12" /></Border>
                        <Border Background="#F7F9FB" CornerRadius="7" Padding="10" Margin="0,2"><TextBlock Text="NOUL   mentions_money · Is money at stake?" TextWrapping="Wrap" FontSize="12" /></Border>
                        <Border Background="#F7F9FB" CornerRadius="7" Padding="10" Margin="0,2"><TextBlock Text="NOUL   is_automated · Is this machine-generated?" TextWrapping="Wrap" FontSize="12" /></Border>
                    </StackPanel>
                </DockPanel>
            </Border>
        </Grid>
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions><ColumnDefinition Width="1.35*" /><ColumnDefinition Width="16" /><ColumnDefinition Width="1*" /></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="White" BorderBrush="{StaticResource CardBorder}" BorderThickness="1" CornerRadius="10" Padding="17">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top" Margin="0,0,0,9">
                        <TextBlock Text="JEV ANSWERS" FontSize="11" FontWeight="Bold" Foreground="#667085" />
                        <TextBlock Text="Typed values and confidence returned for the selected ticket" FontSize="12" Foreground="#344054" Margin="0,4,0,0" />
                    </StackPanel>
                    <TextBox x:Name="AnswersText" IsReadOnly="True" AcceptsReturn="True" FontFamily="Cascadia Code,Consolas" FontSize="12" Foreground="#24364B" Background="#F7F9FB" BorderThickness="0" Padding="11" VerticalScrollBarVisibility="Auto" TextWrapping="NoWrap" Text="Choose a ticket, then run the questions to see Jev's answers here." />
                </DockPanel>
            </Border>
            <Border Grid.Column="2" Background="#EAF3FC" BorderBrush="#B7D1EA" BorderThickness="1" CornerRadius="10" Padding="19">
                <DockPanel>
                    <StackPanel DockPanel.Dock="Top">
                        <TextBlock Text="POWERSHELL ROUTE" FontSize="11" FontWeight="Bold" Foreground="#3178C6" />
                        <TextBlock Text="Your policy decides what happens next." FontSize="12" Foreground="#344054" Margin="0,4,0,10" />
                    </StackPanel>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock x:Name="RouteDepartment" Text="Run the questions to preview a route" FontSize="23" FontWeight="Bold" Foreground="#172B4D" TextWrapping="Wrap" />
                        <TextBlock x:Name="RouteHandling" Text="" FontSize="14" FontWeight="SemiBold" Foreground="#344054" Margin="0,9,0,0" />
                        <TextBlock x:Name="RoutePriority" Text="" FontSize="13" Foreground="#667085" Margin="0,4,0,0" />
                        <TextBlock x:Name="ModelText" Text="" FontSize="10" Foreground="#667085" Margin="0,12,0,0" />
                    </StackPanel>
                </DockPanel>
            </Border>
        </Grid>
    </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Load([System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml)))
foreach ($controlName in @('TicketList', 'TicketText', 'SelectedTicketTitle', 'RunButton', 'ClearButton', 'RunStatus', 'RunTime', 'AnswersText', 'RouteDepartment', 'RouteHandling', 'RoutePriority', 'ModelText')) {
    Set-Variable -Name $controlName -Value $window.FindName($controlName) -Scope Script
}

$script:ticketExamples = $ticketExamples
$script:questionsJson = $questionsJson
$script:modulePath = $jevModulePath
$script:activeJob = $null
$script:stopwatch = $null
$script:timer = [Windows.Threading.DispatcherTimer]::new()
$script:timer.Interval = [TimeSpan]::FromMilliseconds(100)
$script:TicketList.ItemsSource = $script:ticketExamples
$script:TicketList.SelectedIndex = 0

if ([string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)) {
    $script:RunButton.IsEnabled = $false
    $script:RunStatus.Text = 'Set TYPESAFE_API_KEY to run'
}

$script:TicketList.Add_SelectionChanged({
    $selected = $script:TicketList.SelectedItem
    if ($null -eq $selected) { return }
    $script:SelectedTicketTitle.Text = $selected.Title
    $script:TicketText.Text = $selected.Text
    $script:AnswersText.Text = 'Ready. Run all six questions for this ticket.'
    $script:RouteDepartment.Text = 'Run the questions to preview a route'
    $script:RouteHandling.Text = ''
    $script:RoutePriority.Text = ''
    $script:ModelText.Text = ''
})

$script:runTicket = {
    if ($null -ne $script:activeJob -or [string]::IsNullOrWhiteSpace($script:TicketText.Text)) { return }
    $script:AnswersText.Text = 'Sending one request with six questions...'
    $script:RouteDepartment.Text = 'Evaluating ticket'
    $script:RouteHandling.Text = ''
    $script:RoutePriority.Text = ''
    $script:RunButton.IsEnabled = $false
    $script:RunStatus.Text = 'Jev is judging the ticket'
    $script:RunTime.Text = '0.0s'
    $script:stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $script:activeJob = Start-Job -ArgumentList $script:TicketText.Text, $script:questionsJson, $script:modulePath, $autoRouteConfidence, $yesThreshold, $frustratedScore -ScriptBlock {
        param($state, $jsonQuestions, $modulePath, $confidenceFloor, $yes, $frustrated)
        try {
            if ([string]::IsNullOrWhiteSpace($modulePath)) { Import-Module Jev -ErrorAction Stop }
            else { Import-Module $modulePath -Force -ErrorAction Stop }
            $questionSet = @(ConvertFrom-Json -InputObject $jsonQuestions)
            $result = Invoke-Jev -State $state -Question $questionSet
            $answer = $result.answers
            $routeQueue = $answer.department.choice
            $handling = 'Automatic'
            $priority = 'Normal'

            if ($result.is_automated -gt $yes) {
                $routeQueue = 'archive'
                $handling = 'Automatic'
            }
            elseif ($result.goodwill_risk -ge $frustrated -and $result.mentions_money -gt $yes) {
                $routeQueue = 'customer_success'
                $handling = 'Human first'
            }
            elseif ($answer.department.confidence -lt $confidenceFloor) {
                $handling = 'Human review'
            }
            if ($result.is_time_sensitive -gt $yes) { $priority = 'Today' }

            $probabilityLines = foreach ($probability in $answer.department.probabilities.PSObject.Properties) {
                '  {0,-20} {1,5:P0}' -f $probability.Name, [double] $probability.Value
            }
            $answerText = @(
                ('Department       {0}' -f $answer.department.choice)
                ('Confidence       {0:P0}' -f [double] $answer.department.confidence)
                'Choice probabilities'
                $probabilityLines
                ('Goodwill risk    {0:N2} / 3' -f [double] $result.goodwill_risk)
                ('Time-sensitive   {0}  (P(yes) {1:P0})' -f ($result.is_time_sensitive -gt $yes), [double] $result.is_time_sensitive)
                ('Reproducible     {0}  (P(yes) {1:P0})' -f ($result.has_reproduction -gt $yes), [double] $result.has_reproduction)
                ('Mentions money   {0}  (P(yes) {1:P0})' -f ($result.mentions_money -gt $yes), [double] $result.mentions_money)
                ('Automated        {0}  (P(yes) {1:P0})' -f ($result.is_automated -gt $yes), [double] $result.is_automated)
            ) -join [Environment]::NewLine

            [pscustomobject]@{
                Answers = $answerText
                Queue   = $routeQueue
                Handling = $handling
                Priority = $priority
                Model    = [string] $result.model
                Error    = $null
            }
        }
        catch {
            [pscustomobject]@{ Answers = ''; Queue = ''; Handling = ''; Priority = ''; Model = ''; Error = $_.Exception.Message }
        }
    }
    $script:timer.Start()
}

$script:RunButton.Add_Click($script:runTicket)
$script:ClearButton.Add_Click({
    $script:AnswersText.Clear()
    $script:RouteDepartment.Text = 'Run the questions to preview a route'
    $script:RouteHandling.Text = ''
    $script:RoutePriority.Text = ''
    $script:ModelText.Text = ''
    if ($null -eq $script:activeJob) { $script:RunStatus.Text = 'Ready'; $script:RunTime.Text = '' }
})

$script:timer.Add_Tick({
    if ($null -eq $script:activeJob) { return }
    if ($script:activeJob.State -notin @('Completed', 'Failed', 'Stopped')) {
        $script:RunTime.Text = '{0:N1}s elapsed' -f $script:stopwatch.Elapsed.TotalSeconds
        return
    }

    $jobState = $script:activeJob.State
    $script:stopwatch.Stop()
    $output = @(Receive-Job -Job $script:activeJob -ErrorAction SilentlyContinue)
    if ($output.Count -gt 0) {
        $response = $output[-1]
        if ($response.Error) {
            $script:AnswersText.Text = "Request failed: $($response.Error)"
            $script:RouteDepartment.Text = 'No route produced'
            $script:RunStatus.Text = 'Request failed'
        }
        else {
            $script:AnswersText.Text = [string] $response.Answers
            $script:RouteDepartment.Text = [string] $response.Queue
            $script:RouteHandling.Text = [string] $response.Handling
            $script:RoutePriority.Text = "Priority: $($response.Priority)"
            $script:ModelText.Text = "Model: $($response.Model)"
            $script:RunStatus.Text = 'Complete'
        }
    }
    else {
        $script:AnswersText.Text = 'The request ended without a result.'
        $script:RunStatus.Text = "Job $jobState"
    }
    $script:RunTime.Text = '{0:N2}s total' -f $script:stopwatch.Elapsed.TotalSeconds
    Remove-Job -Job $script:activeJob -Force -ErrorAction SilentlyContinue
    $script:activeJob = $null
    $script:RunButton.IsEnabled = -not [string]::IsNullOrWhiteSpace($env:TYPESAFE_API_KEY)
})

$window.Add_PreviewKeyDown({
    param($sender, $eventArgs)
    $controlPressed = [bool]([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)
    if ($eventArgs.Key -eq [System.Windows.Input.Key]::Enter -and $controlPressed) {
        $eventArgs.Handled = $true
        & $script:runTicket
    }
})

$window.Add_Closing({
    $script:timer.Stop()
    if ($null -ne $script:stopwatch) { $script:stopwatch.Stop() }
    if ($null -ne $script:activeJob) {
        Stop-Job -Job $script:activeJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:activeJob -Force -ErrorAction SilentlyContinue
    }
})

$window.ShowDialog() | Out-Null
