def app_version(a; v):    a + "-" + v;
def bookinfo_name(a):     "bookinfo-" + a;
def bookinfo_image(a; v): "registry.istio.io/release/examples-bookinfo-" + a + "-" + v + ":1.20.3";
def reviews_image(v):     "registry.istio.io/release/examples-bookinfo-reviews-" + v + ":1.20.3";
def svc_v1(s):            s + "-v1";
