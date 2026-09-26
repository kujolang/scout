package main
func routes() { http.HandleFunc("/stdlib", handler); http.HandleFunc(dynamicPath, handler) }
