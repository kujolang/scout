import zlib
import alpha
from beta import gamma

@app.route("/z")
def handler():
    return "ok"

password = "top-secret"
cache_key = md5("example")
