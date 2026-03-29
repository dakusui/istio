def backendRef(version; port): {"name": reftag("_svc") + "-" + version, "port": port};
def backendRef(version; port; weight): {"name": reftag("_svc") + "-" + version, "port": port, "weight": weight};
