# Class Diagram: samples/bookinfo/networking/.refactoring/refactored

> Leaf files and their base dependencies.
> `$extends` relationships are shown as inheritance arrows (`◁──`).
> Base node details (attributes, jq functions) are in [shared/CLASS_DIAGRAM.md](shared/CLASS_DIAGRAM.md).
> `virtual-service-base.yaml++` is repeated inside each VS package for readability; all instances refer to the same shared base.

```mermaid
classDiagram
    direction LR

    %% ── shared bases (details in shared/CLASS_DIAGRAM.md) ────────────────
    class specJq["spec.jq"]
    class gatewayBase["gateway-base.yaml++"]
    class drBase["destination-rule-base.yaml++"]
    class vsBase["virtual-service-base.yaml++"]
    class policyMtls["policy/mtls.yaml++"]

    namespace traffic-split {
        class tsAll["all.yaml++"]
        class tsAB["ab-testing.yaml++"]
    }

    namespace subsets {
        class subsProductpage["productpage.yaml++"]
        class subsReviews["reviews.yaml++"]
        class subsRatings["ratings.yaml++"]
        class subsDetails["details.yaml++"]
    }

    %% ── leaf: Gateways ───────────────────────────────────────────────────
    class bookinfoGW["bookinfo-gateway.yaml++"] {
        +doc1 Gateway bookinfo-gateway port 8080
        +doc2 VirtualService bookinfo → productpage:9080
    }
    class certManagerGW["certmanager-gateway.yaml++"] {
        +namespace : istio-system
        +doc1 Gateway cert-manager-gateway port 80
        +doc2 VirtualService cert-manager → cert-manager-resolver:8089
    }

    %% ── leaf: DestinationRules ───────────────────────────────────────────
    class drAll["destination-rule-all.yaml++"] {
        +doc1 _svc=productpage
        +doc2 _svc=reviews
        +doc3 _svc=ratings
        +doc4 _svc=details
    }
    class drAllMtls["destination-rule-all-mtls.yaml++"] {
        +doc1 _svc=productpage
        +doc2 _svc=reviews
        +doc3 _svc=ratings
        +doc4 _svc=details
    }
    class drReviews["destination-rule-reviews.yaml++"] {
        +_svc : reviews
        +trafficPolicy : RANDOM
    }

    %% ── leaf: egress + fault injection (inline, no $extends) ────────────
    class egressApis["egress-rule-google-apis.yaml++"] {
        <<inline>>
        +doc1 ServiceEntry googleapis
        +doc2 VirtualService rewrite-port
        +doc3 DestinationRule originate-tls
    }
    class faultDetails["fault-injection-details-v1.yaml++"] {
        +doc1 VirtualService details abort 555
        +doc2 DestinationRule details subsets v1
    }

    %% ── leaf: VirtualServices ────────────────────────────────────────────
    class vsAllV1["virtual-service-all-v1.yaml++"] {
        +_svc : productpage reviews ratings details
        +_subset : v1
    }

    namespace vs-details {
        class vsBaseD["virtual-service-base.yaml++"]
        class vsDetailsV2["details-v2.yaml++"] {
            +_subset : v2
        }
    }

    namespace vs-ratings {
        class vsBaseRa["virtual-service-base.yaml++"]
        class vsRatingsSubset["ratings-{db,mysql,mysql-vm}.yaml++"] {
            +doc1 _svc=reviews _subset=v3
            +doc2 _subset=v2/v2-mysql/v2-mysql-vm
        }
        class vsRatingsFault["ratings-test-{abort,delay}.yaml++"] {
            +match : end-user=jason → abort 500 OR delay 7s
            +default : v1
        }
    }

    namespace vs-reviews {
        class vsBaseRv["virtual-service-base.yaml++"]
        class vsReviewsV3["reviews-v3.yaml++"] {
            +_subset : v3
        }
        class vsReviewsWeighted["reviews-{50-v3,80-20,90-10,v2-v3}.yaml++"] {
            +_traffic_split : name+weight × 2
        }
        class vsReviewsJason["reviews-{test-v2,jason-v2-v3}.yaml++"] {
            +match : end-user=jason → v2
            +default : v1 OR v3
        }
    }

    %% ── spec.jq → derived bases ──────────────────────────────────────────
    specJq <|-- gatewayBase
    specJq <|-- drBase
    specJq <|-- tsAll
    specJq <|-- tsAB

    %% ── Gateway leaves ───────────────────────────────────────────────────
    gatewayBase <|-- bookinfoGW
    gatewayBase <|-- certManagerGW

    %% ── VirtualService leaves ────────────────────────────────────────────
    vsBase <|-- vsAllV1
    tsAll  <|-- vsAllV1

    vsBaseD <|-- vsDetailsV2
    tsAll   <|-- vsDetailsV2

    vsBaseRa <|-- vsRatingsSubset
    tsAll    <|-- vsRatingsSubset

    vsBaseRa <|-- vsRatingsFault

    vsBaseRv <|-- vsReviewsV3
    tsAll    <|-- vsReviewsV3

    vsBaseRv <|-- vsReviewsWeighted
    tsAB     <|-- vsReviewsWeighted

    vsBaseRv <|-- vsReviewsJason

    vsBase <|-- faultDetails

    %% ── DestinationRule leaves ───────────────────────────────────────────
    drBase          <|-- drAll
    subsProductpage <|-- drAll
    subsReviews     <|-- drAll
    subsRatings     <|-- drAll
    subsDetails     <|-- drAll

    drBase          <|-- drAllMtls
    policyMtls      <|-- drAllMtls
    subsProductpage <|-- drAllMtls
    subsReviews     <|-- drAllMtls
    subsRatings     <|-- drAllMtls
    subsDetails     <|-- drAllMtls

    drBase      <|-- drReviews
    subsReviews <|-- drReviews

    drBase <|-- faultDetails
```
