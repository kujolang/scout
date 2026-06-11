fn setup_routes(app: App) {
    app.route("/users/:id", get(user_handler));
}

let note = "/users/example";
