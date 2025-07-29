import multiprocessing

bind = "unix:/path/to/your/project/gunicorn.sock"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2

# Logging
accesslog = "/path/to/your/project/logs/gunicorn/access.log"
errorlog = "/path/to/your/project/logs/gunicorn/error.log"
loglevel = "info"

# Process naming
proc_name = "django_app"

# Server mechanics
daemon = False
pidfile = "/path/to/your/project/gunicorn.pid"
user = "www-data"
group = "www-data"
tmp_upload_dir = None

# Security
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190
