package main

import (
	// "encoding/json"
	"container/list"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"text/template"
	"util/fsutil"

	yaml "gopkg.in/yaml.v2"
)

const (
	contentDirectory = "/www"
	templateFile     = "page.tmpl"
	serverCertFile   = "/certs/server-cert-and-ca.pem"
	serverKeyFile    = "/certs/server-key.pem"
)

var (
	debug                 bool = true
	pages                 map[string]*Page
	pageTemplate          *template.Template
	staticFileDirectories = []string{"js", "style", "audio", "images", "media"}
	// key: the type, value: the page where it is described
	typeRoutes map[string]string
)

//
func redirectTLS(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "https://docs.cu.bzh:443"+r.RequestURI, http.StatusMovedPermanently)
}

//
func main() {

	// --------------------------------------------------
	// retrieve environment variables' values
	// --------------------------------------------------
	if os.Getenv("RELEASE") == "1" {
		debug = false
	}
	// secure transport
	var envSecureTransport bool = os.Getenv("PCUBES_SECURE_TRANSPORT") == "1"
	fmt.Println("[env] secure transport:", envSecureTransport)

	parseContent()

	for _, staticDir := range staticFileDirectories {
		http.Handle("/"+staticDir+"/", http.StripPrefix("/"+staticDir+"/", http.FileServer(http.Dir(filepath.Join(contentDirectory, staticDir)))))
	}

	http.HandleFunc("/", httpHandler)

	fmt.Println("✨ Cubzh documentation running...")

	if envSecureTransport {
		// listen on 80 for traffic to redirect
		go func() {
			if err := http.ListenAndServe(":80", http.HandlerFunc(redirectTLS)); err != nil {
				log.Fatalf("ListenAndServe :80 error: %v", err)
			}
		}()
		// listen for connections on port 443
		log.Fatal(http.ListenAndServeTLS(":443", serverCertFile, serverKeyFile, nil))
	} else {
		log.Fatal(http.ListenAndServe(":80", nil))
	}
}

func httpHandler(w http.ResponseWriter, r *http.Request) {

	if debug {
		parseContent()
	}

	path := cleanPath(r.URL.Path)

	page, ok := pages[path]
	if ok == false && path != "/" {
		// not found, redirect to /
		fmt.Println("not found:", path)

		if page404, ok := pages["/404"]; ok {
			w.WriteHeader(http.StatusNotFound)
			_ = replyPage(w, page404)
			return
		}

		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	if r.URL.Path != path {
		fmt.Println(r.URL.Path, "!=", path)
		http.Redirect(w, r, path, http.StatusMovedPermanently)
		return
	}

	if page != nil {
		_ = replyPage(w, page)
		return
	}

	replyText(w, "hello world")
}

func replyText(w http.ResponseWriter, text string) {
	fmt.Fprintln(w, text)
}

func replyPage(w http.ResponseWriter, page *Page) error {
	err := pageTemplate.Execute(w, page)
	if err != nil {
		fmt.Println("🔥 error:", err.Error())
	}
	return err
}

func GetTitle(page *Page) string {
	return page.GetTitle()
}

func IsNotCreatableObject(page *Page) bool {
	return page.IsNotCreatableObject()
}

// GetTypeLink returns an non empty string if the type
// is defined at some route
func GetTypeRoute(typeName string) string {
	if route, ok := typeRoutes[typeName]; ok {
		return route
	}
	return ""
}

// parseContent is only done once at startup in RELEASE mode.
// Called for each request in DEBUG to consider potential changes.
func parseContent() error {

	var err error

	pages = make(map[string]*Page)
	typeRoutes = make(map[string]string)

	if !fsutil.DirectoryExists(contentDirectory) {
		return errors.New("content directory is missing")
	}

	templateFilePath := filepath.Join(contentDirectory, templateFile)

	pageTemplate = template.New("page.tmpl").Funcs(template.FuncMap{
		"Join":                  strings.Join,
		"GetTitle":              GetTitle,
		"GetAnchorLink":         GetAnchorLink,
		"SampleHasCodeAndMedia": SampleHasCodeAndMedia,
		"IsNotCreatableObject":  IsNotCreatableObject,
		"GetTypeRoute":          GetTypeRoute,
	})

	pageTemplate, err = pageTemplate.ParseFiles(templateFilePath)

	if err != nil {
		fmt.Println("🔥 error:", err.Error())
		return err
	}

	err = filepath.Walk(contentDirectory, func(walkPath string, walkInfo os.FileInfo, walkErr error) (err error) {
		if walkErr != nil {
			return walkErr
		}

		if strings.HasSuffix(walkPath, ".yml") { // YML FILE

			// check if path points to a regular file
			exists := fsutil.RegularFileExists(walkPath)
			if exists {

				var page Page

				file, err := os.Open(walkPath)
				if err != nil {
					return err
				}

				// example: from /www/index.json to /index.json
				trimmedPath := strings.TrimPrefix(walkPath, contentDirectory)

				page.ResourcePath = trimmedPath

				cleanPath := cleanPath(trimmedPath)

				err = yaml.NewDecoder(file).Decode(&page)

				if err != nil {

					page.Title = "Error"
					page.Description = err.Error()

				}

				pages[cleanPath] = &page
			}
		}

		return nil
	})

	if err != nil {
		return err
	}

	for route, page := range pages {
		if page.Type != "" {
			typeRoutes[page.Type] = route
		}
	}

	queue := list.New()
	for _, page := range pages {
		if page.Type != "" && page.Extends != "" {
			page.ExtentionBaseSet = false
			queue.PushBack(page)
		}
	}

	for queue.Len() > 0 {
		e := queue.Front()
		page := e.Value.(*Page) // First element
		queue.Remove(e)         // Dequeue

		if extendedTypePageRoute, ok := typeRoutes[page.Extends]; ok {
			if extendedTypePage, ok := pages[extendedTypePageRoute]; ok {
				if extendedTypePage.ReadyToBeSetAsBase() {
					page.SetExtentionBase(extendedTypePage)
					page.ExtentionBaseSet = true
				} else {
					// base is itself an extension and should be
					// taken care of first.
					queue.PushBack(page)
				}
			}
		}
	}

	for _, page := range pages {
		page.Sanitize()
	}

	fmt.Println("content parsed!")
	// fmt.Printf("%4v\n", pages)
	// fmt.Println("PAGES:")
	// for k, _ := range pages {
	// 	fmt.Println(k)
	// }
	// fmt.Println("TYPES:")
	// for t, r := range typeRoutes {
	// 	fmt.Println(t, "->", r)
	// }

	return nil
}

// cleanPath cleans a path, lowercases it,
// removes file extension and make it /
// if it refers to /index.
func cleanPath(path string) string {

	cleanPath := filepath.Clean(path)
	cleanPath = strings.ToLower(cleanPath)

	extension := filepath.Ext(cleanPath)
	if extension != "" {
		cleanPath = strings.TrimSuffix(cleanPath, extension)
	}

	if strings.HasSuffix(cleanPath, "/index") {
		cleanPath = strings.TrimSuffix(cleanPath, "/index")
	}

	if cleanPath == "" {
		cleanPath = "/"
	}

	return cleanPath
}
