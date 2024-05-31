package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
)

const (
	// Specify the API endpoint
	apiURL = "https://api.openai.com/v1/chat/completions"
	apiKey = "..."
)

type Language struct {
	Name string
	Code string
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatGptReq struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Temperature float64   `json:"temperature"`
}

type ChatGptResp struct {
	ID      string   `json:"id"`
	Model   string   `json:"model"`
	Choices []Choice `json:"choices"`
}

type Choice struct {
	Index        int     `json:"index"`
	Message      Message `json:"message"`
	FinishReason string  `json:"finish_reason"`
}

func translate(lang Language) error {

	req := ChatGptReq{
		Model:       "gpt-4",
		Temperature: 0,
		Messages: []Message{
			{
				Role: "system",
				Content: `You're a native ` + lang.Name + ` translator. You translate JSON files from english to ` + lang.Name + `. Translations must be kids-friendly, direct, and as short as possible (never longer than 10% over english version). Translations are for a gaming mobile application like Roblox (audience between 12 and 16 yo). Output has to sound natural and casual for kids. Use natural spoken language, modifying sentence structures if needed.

Here's our the input JSON is structured:

{
	"key_a" = "value_a"
	"key_b" = {
		"context1" = "value_b1",
		"context2" = "value_b2"
	}
}

The value is a table when the top level key could be translated in different ways depending on the context. Each sub-key then describes the context that should be use to translate the top level key. The context itself should not be translated.`,
			},
			{
				Role: "user",
				Content: `{
    "day": "",
    "days": "",
    "month": "",
    "year": "",
    "years": "",
    "password": "",
    "login": "",
    "need help?": "",
    "username": "",
    "don't use your real name!": "",
    "sign up": {
        "button": "",
        "title": ""
    },
    "can't be changed!": "",
    "date of birth": "",
    "can't be changed": "",
    "must start with a-z": "",
    "a-z 0-9 only": "",
    "too long": "",
    "already taken": "",
    "server error": "",
    "not appropriate": "",
    "checking": "",
    "required": "",
    "january": "",
    "february": "",
    "march": "",
    "april": "",
    "may": "",
    "june": "",
    "july": "",
    "august": "",
    "september": "",
    "october": "",
    "november": "",
    "december": "",
    "⚠️ Be safe online! ⚠️\n\nDo NOT share personal details, watch out for phishing, scams and always think about who you're talking to.\n\nIf anything goes wrong, talk to someone you trust. 🙂": "",
    "Yes sure!": "",
    "I'm not ready.": "",
    "By clicking Sign Up, you are agreeing to the Terms of Use and aknowledging the Privacy Policy.": "",
    "%s joined!": "",
    "%s just left!": "",
    "Hey! Edit your avatar in the Profile Menu, or use the changing room! 👕👖🥾": "",
    "Looking for friends? Add some through the Friends menu!": "",
    "There are many Worlds to explore in Cubzh, step inside and use my teleporter or the Main menu!": "",
    "Ready to customize your avatar? 👕": "",
    "Let's do this!": "",
    "Ready to explore other Worlds? 🌎": "",
    "Let's go!": "",
    "Might wanna join Cubzh's Discord to meet other players & creators?": "",
    "Sure!": "",
    "You can customize your avatar anytime!": "",
    "Ok!": "",
    "Add friends and play with them!": "",
    "Maintain jump key to start gliding!": "",
    "%d / %d collected": {
        "number of collected glider parts": ""
    },
    "Hey there! 🙂 You seem like a kind-hearted soul. I'm sure you would take good care of a pet! ✨": "",
    "➡️ Yes of course!": "",
    "➡️ No thank you": "",
    "This machine here can spawn a random egg for you!": "",
    "➡️ Ok!": "",
    "I'm currently fixing it, come back in a few days!": "",
    "➡️ I'll be back!": "",
    "Glider unlocked!": "",
    "Oh, I could swear you would like to adopt a cute pet. Come back if you change your mind!": ""
}
`,
			},
		},
	}

	// Convert the request to JSON
	reqBodyBytes, err := json.Marshal(req)
	if err != nil {
		return err
	}

	bodyReader := bytes.NewReader(reqBodyBytes)

	// Prepare the request
	httpReq, err := http.NewRequest("POST", apiURL, bodyReader)
	if err != nil {
		return err
	}

	// Set your OpenAI API key as a bearer token
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	httpReq.Header.Set("Content-Type", "application/json")

	// Send the request
	client := &http.Client{}
	resp, err := client.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	// Print the response body
	fmt.Println("Response:", string(body))

	// Parse response
	var respData ChatGptResp
	err = json.Unmarshal(body, &respData)
	if err != nil {
		return err
	}

	if len(respData.Choices) != 1 {
		return errors.New("invalid response")
	}

	respStr := respData.Choices[0].Message.Content
	respBytes := []byte(respStr)

	fmt.Println(respStr)

	// write to file
	err = os.WriteFile("../"+lang.Code+".json", respBytes, 0644)
	if err != nil {
		return err
	}

	return nil
}

func main() {

	languages := []Language{
		// {
		// 	Name: "English",
		// 	Code: "en",
		// },
		{
			Name: "French",
			Code: "fr",
		},
		{
			Name: "Spanish",
			Code: "es",
		},
		{
			Name: "Italian",
			Code: "it",
		},
		{
			Name: "Portuguese",
			Code: "pt",
		},
		{
			Name: "Ukrainian",
			Code: "ua",
		},
		{
			Name: "Polish",
			Code: "pl",
		},
		{
			Name: "Russian",
			Code: "ru",
		},
	}

	for _, lang := range languages {
		fmt.Println("Translating to", lang)
		err := translate(lang)
		if err != nil {
			fmt.Println("Error:", err.Error())
		}
	}

}
