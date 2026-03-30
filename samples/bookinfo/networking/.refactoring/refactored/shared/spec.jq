def subset_of(v): {"name": v, "labels": {"version": v}};
def http_port(n): {"number": n, "name": "http", "protocol": "HTTP"};
def https_port(n): {"number": n, "name": "https", "protocol": "HTTPS"};
def routing_destination(sub): {"host": reftag("_svc"), "subset": sub};
