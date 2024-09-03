# Build Particubes Web in Docker

## Build

Call this from repository root directory:

```
docker build -t particubes-web -f ./dockerfiles/wasm.Dockerfile .
```

## Run

```
docker run --rm -p 10080:80 -p 10443:443 particubes-web
```

## Enjoy

Open http://localhost:10080/ in your webbrowser
