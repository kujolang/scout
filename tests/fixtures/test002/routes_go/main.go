package main

type router_interface interface {
	GET(string, func())
}

func get_pet() {
}

func mount(router router_interface) {
	router.GET("/pets/:id", get_pet)
}

var note = "/pets/example"
