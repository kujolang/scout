// This is a safe regex API usage and should not be flagged as dangerous execution.
const safe_match = /hello/.exec("hello world");

// This is a safe string literal mention and should not be flagged.
const marker = "exec(";

// This should be flagged.
exec("ls -la");
