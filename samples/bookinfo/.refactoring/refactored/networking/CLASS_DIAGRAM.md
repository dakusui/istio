# Class Diagram: samples/bookinfo/.refactoring/refactored/networking

> `$extends` relationships are shown as inheritance arrows (`◁──`).
> jq library usage is shown as dependency arrows (`‥‥▷`).
> Files containing multiple `---`-separated documents list per-doc parameter
> bindings inline; all documents within a file share the same base.
> Files using the `@01.yaml` naming convention bypass jq++ and are marked
> `<<plain YAML>>`.

```mermaid
classDiagram
    direction LR

    %% ── jq function library ──────────────────────────────────────────────
    class subsetsJq["subsets.jq"] {
        <<jq library>>
        +versioned_subset(p)
    }

    %% ── DestinationRule bases ────────────────────────────────────────────
    class drBase["destination-rule-base.yaml++"] {
        <<abstract DestinationRule>>
        +_app
        +name : _app
        +host : _app
        +subsets : []
    }
    class drMtlsBase["destination-rule-mtls-base.yaml++"] {
        <<abstract DestinationRule>>
        +trafficPolicy.tls.mode : ISTIO_MUTUAL
    }

    %% ── VirtualService bases ─────────────────────────────────────────────
    class vsV1Base["virtual-service-v1-base.yaml++"] {
        <<abstract VirtualService>>
        +_app
        +name : _app
        +hosts : _app
        +route : _app / v1
    }
    class vsSubsetBase["virtual-service-subset-base.yaml++"] {
        <<abstract VirtualService>>
        +_app
        +_subset
        +name : _app
        +hosts : _app
        +route : _app / _subset
    }
    class vsWeightedBase["virtual-service-weighted-base.yaml++"] {
        <<abstract VirtualService>>
        +_app
        +_subset1 + _weight1
        +_subset2 + _weight2
        +route : _app/_subset1 w1% + _app/_subset2 w2%
    }
    class vsJasonBase["virtual-service-reviews-jason-base.yaml++"] {
        <<abstract VirtualService>>
        +_match_subset
        +_default_subset
        +match : end-user=jason → reviews/_match_subset
        +default : → reviews/_default_subset
    }

    %% ── leaf files: inlined (no $extends) ────────────────────────────────
    class bookinfoGW["bookinfo-gateway.yaml++"] {
        <<inline>>
        +Gateway bookinfo-gateway port 8080
        +VirtualService bookinfo → productpage:9080
    }
    class certManagerGW["certmanager-gateway.yaml++"] {
        <<inline>>
        +namespace : istio-system
        +Gateway cert-manager-gateway port 80
        +VirtualService cert-manager → cert-manager-resolver:8089
    }
    class egressApis["egress-rule-google-apis.yaml++"] {
        <<inline>>
        +ServiceEntry googleapis (80/HTTP 443/HTTPS)
        +VirtualService rewrite-port port 80→443
        +DestinationRule originate-tls ROUND_ROBIN SIMPLE
    }

    %% ── leaf files: DestinationRule ──────────────────────────────────────
    class drAll["destination-rule-all.yaml++"] {
        +doc1 _app=productpage subsets v1
        +doc2 _app=reviews subsets v1 v2 v3
        +doc3 _app=ratings subsets v1 v2 v2-mysql v2-mysql-vm
        +doc4 _app=details subsets v1 v2
    }
    class drAllMtls["destination-rule-all-mtls.yaml++"] {
        +doc1 _app=productpage subsets v1
        +doc2 _app=reviews subsets v1 v2 v3
        +doc3 _app=ratings subsets v1 v2 v2-mysql v2-mysql-vm
        +doc4 _app=details subsets v1 v2
    }
    class drReviews["destination-rule-reviews.yaml++"] {
        +_app : reviews
        +trafficPolicy : RANDOM
        +subsets : v1 v2 v3
    }

    %% ── leaf files: VirtualService all-v1 ───────────────────────────────
    class vsAllV1["virtual-service-all-v1.yaml++"] {
        +doc1 _app=productpage
        +doc2 _app=reviews
        +doc3 _app=ratings
        +doc4 _app=details
    }

    %% ── leaf files: VirtualService single-subset ─────────────────────────
    class vsDetailsV2["virtual-service-details-v2.yaml++"] {
        +_app : details
        +_subset : v2
    }
    class vsRatingsSubset["virtual-service-ratings-{db,mysql,mysql-vm}.yaml++"] {
        +doc1 _app=reviews _subset=v3
        +doc2 _app=ratings _subset=v2 OR v2-mysql OR v2-mysql-vm
    }
    class vsReviewsV3["virtual-service-reviews-v3.yaml++"] {
        +_app : reviews
        +_subset : v3
    }

    %% ── leaf files: VirtualService weighted ──────────────────────────────
    class vsReviewsWeighted["virtual-service-reviews-{50-v3,80-20,90-10,v2-v3}.yaml++"] {
        +_app : reviews
        +_subset1/weight1 : v1,v2 50–90%
        +_subset2/weight2 : v2,v3 10–50%
    }

    %% ── leaf files: VirtualService jason header ──────────────────────────
    class vsReviewsJason["virtual-service-reviews-{test-v2,jason-v2-v3}.yaml++"] {
        +_match_subset : v2
        +_default_subset : v1 OR v3
    }

    %% ── leaf files: plain YAML (bypass jq++) ─────────────────────────────
    class vsRatingsFault["virtual-service-ratings-test-{abort,delay}@01.yaml"] {
        <<plain YAML>>
        +ratings fault for jason header
        +abort 500 at 100% OR delay 7s at 100%
        +default : subset v1
    }

    %% ── leaf file: fault-injection pair ──────────────────────────────────
    class faultDetails["fault-injection-details-v1.yaml++"] {
        +doc1 VirtualService details abort 555 (inline)
        +doc2 DestinationRule details _app=details subsets v1
    }

    %% ── $extends: DR bases ───────────────────────────────────────────────
    drBase     <|-- drMtlsBase
    drBase     <|-- drAll
    drMtlsBase <|-- drAllMtls
    drBase     <|-- drReviews
    drBase     <|-- faultDetails

    subsetsJq ..> drAll        : versioned_subset
    subsetsJq ..> drAllMtls    : versioned_subset
    subsetsJq ..> drReviews    : versioned_subset
    subsetsJq ..> faultDetails : versioned_subset

    %% ── $extends: VS bases ───────────────────────────────────────────────
    vsV1Base      <|-- vsAllV1
    vsSubsetBase  <|-- vsDetailsV2
    vsSubsetBase  <|-- vsRatingsSubset
    vsSubsetBase  <|-- vsReviewsV3
    vsWeightedBase <|-- vsReviewsWeighted
    vsJasonBase   <|-- vsReviewsJason
```
