import hashlib

def digest(value):
	return hashlib.md5(value).hexdigest()
