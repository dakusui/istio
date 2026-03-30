def subset_of(v): {"name": v, "labels": {"version": v}};
def http_port(n): {"number": n, "name": "http", "protocol": "HTTP"};
def https_port(n): {"number": n, "name": "https", "protocol": "HTTPS"};
def routing_destination(sub): {"host": reftag("_svc"), "subset": sub};
def weighted_destination_of(sub; w): {"destination": routing_destination(sub), "weight": w};
