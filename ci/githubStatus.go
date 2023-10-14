package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const (
	statusAPIURL   = "https://api.github.com/repos/%s/%s/statuses/%s"
	checkRunAPIURL = "https://api.github.com/repos/%s/%s/check-runs"
)

type GithubCheckRunOutput struct {
	Title   string `json:"title"`
	Summary string `json:"summary"`
	Text    string `json:"text"`
}

type GithubCheckRun struct {
	// REQUIRED
	Owner string `json:"owner"`
	Repo  string `json:"repo"`
	Name  string `json:"name"`
	Sha   string `json:"head_sha"`

	// OPTIONAL
	Status      string                `json:"status,omitempty"` // queued (default), in_progress, completed
	DetailsURL  string                `json:"details_url,omitempty"`
	ExternalID  string                `json:"external_id,omitempty"`
	StartedAt   string                `json:"started_at,omitempty"`   // iso8601 : YYYY-MM-DDTHH:MM:SSZ
	Conclusion  string                `json:"conclusion,omitempty"`   // action_required, cancelled, failure, neutral, success, skipped, stale, timed_out
	CompletedAt string                `json:"completed_at,omitempty"` // iso8601 : YYYY-MM-DDTHH:MM:SSZ
	Output      *GithubCheckRunOutput `json:"output,omitempty"`
}

func postGithubCheckRun(content GithubCheckRun, accessToken string) error {

	url := fmt.Sprintf(checkRunAPIURL, content.Owner, content.Repo)

	b, err := json.Marshal(content)
	if err != nil {
		return fmt.Errorf("unable to marshal check run: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(b))
	if err != nil {
		return fmt.Errorf("unable to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		bodyBytes, err := io.ReadAll(resp.Body)
		if err == nil {
			bodyString := string(bodyBytes)
			fmt.Println(bodyString)
		}
		return fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	return nil
}

type GithubStatusOpts struct {
	AccessToken string
	Owner       string
	Repo        string
	Sha         string
	State       string // error, failure, pending, success
	TargetURL   string
	Description string
	Context     string // "default" by default
}

type githubStatus struct {
	State       string `json:"state"`
	TargetURL   string `json:"target_url,omitempty"`
	Description string `json:"description,omitempty"`
	Context     string `json:"context,omitempty"`
}

func postGithubStatus(opts GithubStatusOpts) error {

	url := fmt.Sprintf(statusAPIURL, opts.Owner, opts.Repo, opts.Sha)

	status := githubStatus{
		State:       opts.State,
		TargetURL:   opts.TargetURL,
		Description: opts.Description,
		Context:     opts.Context,
	}

	validStates := map[string]bool{
		"error":   true,
		"failure": true,
		"pending": true,
		"success": true,
	}

	_, isStateValid := validStates[status.State]
	if isStateValid == false {
		return fmt.Errorf("state (%s) should be error, failure, pending or success", status.State)
	}

	if status.Context == "" {
		status.Context = "default"
	}

	// Marshal the status into JSON
	statusBytes, err := json.Marshal(status)
	if err != nil {
		return fmt.Errorf("unable to marshal status: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(statusBytes))
	if err != nil {
		return fmt.Errorf("unable to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+opts.AccessToken)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	return nil
}
