package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

const (
	API_URL = "https://api.cu.bzh"
	DEBUG   = false
)

var (
	indexTmpl         *template.Template
	internalErrorTmpl *template.Template
	notFoundTmpl      *template.Template
)

type DashboardInfo struct {
	CreatedAt                      *time.Time `json:"createdAt"`
	ChildAge                       *int       `json:"childAge"`
	ParentalControlApproved        *bool      `json:"parentalControlApproved"`
	ParentalControlChatAllowed     *bool      `json:"parentalControlChatAllowed"`
	ParentalControlMessagesAllowed *bool      `json:"parentalControlMessagesAllowed"`
}

type DashboardContent struct {
	Link            string
	ChildAge        int
	Approved        bool
	Chat            bool
	PrivateMessages bool
	CreationDate    string
}

func main() {
	var err error

	r := chi.NewRouter()

	// Middlewares
	// r.Use(middleware.RequestID)
	// r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	// r.Use(middleware.Recoverer)

	indexTmpl, err = template.New("index.html").ParseFiles("templates/index.html")
	if err != nil {
		log.Fatalln("can't load index template")
		return
	}

	notFoundTmpl, err = template.New("404.html").ParseFiles("templates/404.html")
	if err != nil {
		log.Fatalln("can't load 404 template")
		return
	}

	internalErrorTmpl, err = template.New("500.html").ParseFiles("templates/500.html")
	if err != nil {
		log.Fatalln("can't load 500 template")
		return
	}

	fs := http.FileServer(http.Dir("static"))
	r.Handle("/img/*", fs)
	r.Handle("/style.css", fs)

	r.Post("/{dashboardID}/{key}", func(w http.ResponseWriter, r *http.Request) {
		dashboardID := chi.URLParam(r, "dashboardID")
		key := chi.URLParam(r, "key")

		approve := r.URL.Query().Get("approve")
		chat := r.URL.Query().Get("chat")
		privateMessages := r.URL.Query().Get("private-messages")

		info := DashboardInfo{
			ParentalControlApproved:        nil,
			ParentalControlChatAllowed:     nil,
			ParentalControlMessagesAllowed: nil,
		}

		yes := true
		no := false

		if approve == "yes" {
			info.ParentalControlApproved = &yes
		} else if approve == "no" {
			info.ParentalControlApproved = &no
		}

		if chat == "yes" {
			info.ParentalControlChatAllowed = &yes
		} else if chat == "no" {
			info.ParentalControlChatAllowed = &no
		}

		if privateMessages == "yes" {
			info.ParentalControlMessagesAllowed = &yes
		} else if privateMessages == "no" {
			info.ParentalControlMessagesAllowed = &no
		}

		jsonData, err := json.Marshal(info)
		if err != nil {
			internalError(w)
			return
		}

		url := API_URL + "/dashboards/" + dashboardID + "/" + key

		req, err := http.NewRequest("PATCH", url, bytes.NewBuffer(jsonData))
		if err != nil {
			internalError(w)
			return
		}

		req.Header.Set("Content-Type", "application/json")

		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			internalError(w)
			return
		}
		defer resp.Body.Close()

		// NOTE: no error handling for now, requests fail silently
		if resp.StatusCode != http.StatusOK {
			fmt.Println("⚠️ PATCH dashboard status code:", resp.StatusCode)
		}

		if approve != "" {
			http.Redirect(w, r, "/"+dashboardID+"/"+key, http.StatusSeeOther)
		}
	})

	// Serve HTML template
	r.Get("/{dashboardID}/{key}", func(w http.ResponseWriter, r *http.Request) {
		dashboardID := chi.URLParam(r, "dashboardID")
		key := chi.URLParam(r, "key")

		url := API_URL + "/dashboards/" + dashboardID + "/" + key

		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			internalError(w)
			return
		}
		req.Header.Set("Accept", "application/json")

		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			internalError(w)
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			if resp.StatusCode == http.StatusNotFound {
				notFound(w)
			} else {
				internalError(w)
			}
			return
		}

		index(w, resp.Body, dashboardID, key)
	})

	r.NotFound(func(w http.ResponseWriter, r *http.Request) {
		notFound(w)
	})

	if DEBUG {
		fmt.Println("✨ Parent dashboard running on port 3000...")
		http.ListenAndServe(":3000", r)
	} else {
		fmt.Println("✨ Parent dashboard running on port 80...")
		http.ListenAndServe(":80", r)
	}
}

func redirectTLS(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "https://dashboard.cu.bzh"+r.RequestURI, http.StatusMovedPermanently)
}

func index(w http.ResponseWriter, body io.ReadCloser, dashboardID, key string) {
	var err error

	decoder := json.NewDecoder(body)

	var info DashboardInfo
	err = decoder.Decode(&info)
	if err != nil {
		internalError(w)
		return
	}

	content := DashboardContent{
		Link:            "https://dashboard.cu.bzh/" + dashboardID + "/" + key,
		Approved:        *info.ParentalControlApproved,
		Chat:            *info.ParentalControlChatAllowed,
		PrivateMessages: *info.ParentalControlMessagesAllowed,
		ChildAge:        *info.ChildAge,
		CreationDate:    info.CreatedAt.Format("January 02, 2006"),
	}

	if DEBUG { // re-parse template for live debug
		indexTmpl, err = template.New("index.html").ParseFiles("templates/index.html")
		if err != nil {
			log.Fatalln("can't load index template")
			return
		}
	}

	err = indexTmpl.ExecuteTemplate(w, "index.html", content)
	if err != nil {
		internalError(w)
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func notFound(w http.ResponseWriter) {
	err := notFoundTmpl.ExecuteTemplate(w, "404.html", nil)
	if err != nil {
		internalError(w)
	}
}

func internalError(w http.ResponseWriter) {
	err := internalErrorTmpl.ExecuteTemplate(w, "500.html", nil)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}
