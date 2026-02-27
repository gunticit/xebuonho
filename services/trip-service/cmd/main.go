package main

import (
"fmt"
"log"
"net/http"
"os"
)

func main() {
port := os.Getenv("HTTP_PORT")
if port == "" {
port = "8080"
}

serviceName := getServiceName()
log.Printf("[%s] Starting on port %s...", serviceName, port)

http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
w.WriteHeader(http.StatusOK)
fmt.Fprintf(w, `{"status":"ok","service":"%s"}`, serviceName)
})

if err := http.ListenAndServe(":"+port, nil); err != nil {
log.Fatal(err)
}
}

func getServiceName() string {
name := os.Getenv("SERVICE_NAME")
if name == "" {
return "unknown-service"
}
return name
}
