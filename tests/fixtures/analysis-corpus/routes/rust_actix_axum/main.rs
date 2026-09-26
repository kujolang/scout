let app = Router::new().route("/rust", get(handler)).route(dynamic_path, get(handler));
