package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

const (
	API_URL = "https://api.cu.bzh"
	DEBUG   = true
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
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

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

	// Serve HTML template
	r.Get("/{dashboardID}/{key}", func(w http.ResponseWriter, r *http.Request) {
		dashboardID := chi.URLParam(r, "dashboardID")
		key := chi.URLParam(r, "key")

		fmt.Println("DASHBOARD ID:", dashboardID)
		fmt.Println("KEY:", key)

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

		decoder := json.NewDecoder(resp.Body)

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
	})

	r.NotFound(func(w http.ResponseWriter, r *http.Request) {
		notFound(w)
	})

	http.ListenAndServe(":3000", r)
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
