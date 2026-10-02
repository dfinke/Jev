package main

import (
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

type App struct {
	ctx     context.Context
	mu      sync.Mutex
	running bool
}

type CSVInfo struct {
	Path        string `json:"path"`
	RecordCount int    `json:"recordCount"`
}

var requiredColumns = []string{
	"RecommendationId",
	"ResourceType",
	"Environment",
	"Recommendation",
	"PotentialMonthlySavingsUsd",
	"OwnerNote",
}

func NewApp() *App { return &App{} }

func (a *App) startup(ctx context.Context) { a.ctx = ctx }

func (a *App) GetSampleCSV() (string, error) {
	path, err := findUp("advisor-recommendations.csv")
	if err != nil {
		return "", fmt.Errorf("could not find the sample CSV: %w", err)
	}
	return path, nil
}

func (a *App) SelectCSV() (string, error) {
	defaultDir, _ := a.GetSampleCSV()
	if defaultDir != "" {
		defaultDir = filepath.Dir(defaultDir)
	}
	return runtime.OpenFileDialog(a.ctx, runtime.OpenDialogOptions{
		Title:            "Choose an Azure Advisor recommendations CSV",
		DefaultDirectory: defaultDir,
		Filters: []runtime.FileFilter{{
			DisplayName: "CSV files (*.csv)",
			Pattern:     "*.csv",
		}},
	})
}

func (a *App) InspectCSV(path string) (CSVInfo, error) {
	return inspectCSV(path)
}

func inspectCSV(path string) (CSVInfo, error) {
	file, err := os.Open(path)
	if err != nil {
		return CSVInfo{}, err
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.FieldsPerRecord = -1
	header, err := reader.Read()
	if err != nil {
		return CSVInfo{}, fmt.Errorf("read CSV header: %w", err)
	}
	if len(header) > 0 {
		header[0] = strings.TrimPrefix(header[0], "\ufeff")
	}
	columnSet := make(map[string]bool, len(header))
	for _, name := range header {
		columnSet[strings.TrimSpace(name)] = true
	}
	missing := make([]string, 0)
	for _, name := range requiredColumns {
		if !columnSet[name] {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		return CSVInfo{}, fmt.Errorf("CSV is missing required columns: %s", strings.Join(missing, ", "))
	}

	count := 0
	for {
		_, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return CSVInfo{}, fmt.Errorf("read CSV row %d: %w", count+2, err)
		}
		count++
	}
	if count == 0 {
		return CSVInfo{}, fmt.Errorf("CSV contains no recommendation rows")
	}
	absolutePath, err := filepath.Abs(path)
	if err != nil {
		return CSVInfo{}, err
	}
	return CSVInfo{Path: absolutePath, RecordCount: count}, nil
}

func (a *App) RunDemo(csvPath string, delayMs int) error {
	a.mu.Lock()
	if a.running {
		a.mu.Unlock()
		return fmt.Errorf("a run is already in progress")
	}
	a.running = true
	a.mu.Unlock()

	resetRunning := func() {
		a.mu.Lock()
		a.running = false
		a.mu.Unlock()
	}
	if delayMs < 0 || delayMs > 2000 {
		resetRunning()
		return fmt.Errorf("delay must be between 0 and 2000 milliseconds")
	}

	csvInfo, err := inspectCSV(csvPath)
	if err != nil {
		resetRunning()
		return err
	}
	pwshPath, err := exec.LookPath("pwsh")
	if err != nil {
		resetRunning()
		return fmt.Errorf("PowerShell 7 (pwsh) was not found on PATH")
	}
	scriptPath, err := findUp("Invoke-AzureCostRecommendationRouter.ps1")
	if err != nil {
		resetRunning()
		return fmt.Errorf("could not find the PowerShell router script: %w", err)
	}

	eventFile, err := os.CreateTemp("", "jev-cost-flow-*.jsonl")
	if err != nil {
		resetRunning()
		return fmt.Errorf("create event stream: %w", err)
	}
	eventPath := eventFile.Name()
	if err := eventFile.Close(); err != nil {
		os.Remove(eventPath)
		resetRunning()
		return err
	}

	outputPath := filepath.Join(filepath.Dir(scriptPath), "output", "visualizer-results.csv")
	cmd := exec.Command(
		pwshPath,
		"-NoLogo",
		"-NoProfile",
		"-NonInteractive",
		"-File", scriptPath,
		"-InputPath", csvInfo.Path,
		"-OutputPath", outputPath,
		"-EventPath", eventPath,
		"-DelayMs", strconv.Itoa(delayMs),
	)
	cmd.Dir = filepath.Dir(scriptPath)
	cmd.Stdout = io.Discard
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		os.Remove(eventPath)
		resetRunning()
		return fmt.Errorf("start PowerShell: %w", err)
	}

	runtime.EventsEmit(a.ctx, "flow:event", map[string]any{
		"type":       "run_started",
		"total":      csvInfo.RecordCount,
		"outputPath": outputPath,
		"inputPath":  csvInfo.Path,
	})
	go a.watchRun(cmd, eventPath, outputPath, csvInfo.RecordCount, &stderr)
	return nil
}

func (a *App) watchRun(cmd *exec.Cmd, eventPath, outputPath string, total int, stderr *bytes.Buffer) {
	defer os.Remove(eventPath)
	var offset int64
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	ticker := time.NewTicker(60 * time.Millisecond)
	defer ticker.Stop()

	for {
		a.emitAvailableEvents(eventPath, &offset)
		select {
		case err := <-done:
			a.emitAvailableEvents(eventPath, &offset)
			payload := map[string]any{
				"type":       "run_finished",
				"total":      total,
				"outputPath": outputPath,
				"success":    err == nil,
			}
			if err != nil {
				message := strings.TrimSpace(stderr.String())
				if message == "" {
					message = err.Error()
				}
				payload["message"] = message
			}
			runtime.EventsEmit(a.ctx, "flow:event", payload)
			a.mu.Lock()
			a.running = false
			a.mu.Unlock()
			return
		case <-ticker.C:
		}
	}
}

func (a *App) emitAvailableEvents(path string, offset *int64) {
	contents, err := os.ReadFile(path)
	if err != nil || *offset >= int64(len(contents)) {
		return
	}
	remaining := contents[*offset:]
	consumed := 0
	for {
		newline := bytes.IndexByte(remaining[consumed:], '\n')
		if newline < 0 {
			break
		}
		end := consumed + newline
		line := bytes.TrimSpace(remaining[consumed:end])
		consumed = end + 1
		if len(line) == 0 {
			continue
		}
		var event map[string]any
		if json.Unmarshal(line, &event) == nil {
			runtime.EventsEmit(a.ctx, "flow:event", event)
		}
	}
	*offset += int64(consumed)
}

func findUp(filename string) (string, error) {
	starts := make([]string, 0, 2)
	if cwd, err := os.Getwd(); err == nil {
		starts = append(starts, cwd)
	}
	if executable, err := os.Executable(); err == nil {
		starts = append(starts, filepath.Dir(executable))
	}
	for _, start := range starts {
		current, err := filepath.Abs(start)
		if err != nil {
			continue
		}
		for {
			candidate := filepath.Join(current, filename)
			if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
				return candidate, nil
			}
			parent := filepath.Dir(current)
			if parent == current {
				break
			}
			current = parent
		}
	}
	return "", fmt.Errorf("%s not found above the current directory or application", filename)
}
