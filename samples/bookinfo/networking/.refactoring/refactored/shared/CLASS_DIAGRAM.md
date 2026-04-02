# Class Diagram: samples/bookinfo/networking/.refactoring/refactored/shared

> This directory contains only reusable bases and mixins — no leaf files.
> `$extends` relationships are shown as inheritance arrows (`◁──`).
> jq function-library usage (via `eval:object:<ns>::<fn>`) is shown as
> dependency arrows (`‥‥▷`).

```mermaid
classDiagram
    direction LR

    %% ── jq function library ──────────────────────────────────────────────
    class specJq["spec.jq"] {
        <<jq library>>
        +subset_of(v)
        +http_port(n)
        +https_port(n)
        +routing_destination(sub)
    }

    %% ── bases that $extends spec.jq ─────────────────────────────────────
    class gatewayBase["gateway-base.yaml++"] {
        <<abstract Gateway>>
        +selector : istio=ingressgateway
        +servers : []
    }
    class drBase["destination-rule-base.yaml++"] {
        <<abstract DestinationRule>>
        +_svc
        +name : _svc
        +host : _svc
        +subsets : []
    }
    class tsAll["traffic-split/all.yaml++"] {
        <<http route mixin>>
        +_subset
        +http : route → routing_destination(_subset)
    }
    class tsAB["traffic-split/ab-testing.yaml++"] {
        <<http route mixin>>
        +_traffic_split : name+weight × 2
        +http : dest[0] w% + dest[1] w%
    }

    %% ── standalone bases (no $extends) ──────────────────────────────────
    class vsBase["virtual-service-base.yaml++"] {
        <<abstract VirtualService>>
        +_svc
        +name : _svc
        +hosts : _svc
        +http : []
    }
    class policyMtls["policy/mtls.yaml++"] {
        <<mixin>>
        +trafficPolicy.tls.mode : ISTIO_MUTUAL
    }

    %% ── subsets mixins (use spec.jq via eval:object:spec::subset_of) ────
    class subsProductpage["subsets/productpage.yaml++"] {
        <<subsets mixin>>
        +subsets : subset_of(v1)
    }
    class subsReviews["subsets/reviews.yaml++"] {
        <<subsets mixin>>
        +subsets : subset_of(v1) subset_of(v2) subset_of(v3)
    }
    class subsRatings["subsets/ratings.yaml++"] {
        <<subsets mixin>>
        +subsets : subset_of(v1) subset_of(v2) subset_of(v2-mysql) subset_of(v2-mysql-vm)
    }
    class subsDetails["subsets/details.yaml++"] {
        <<subsets mixin>>
        +subsets : subset_of(v1) subset_of(v2)
    }

    %% ── spec.jq → derived bases ──────────────────────────────────────────
    specJq <|-- gatewayBase
    specJq <|-- drBase
    specJq <|-- tsAll
    specJq <|-- tsAB

    %% ── subsets mixins depend on spec.jq for subset_of() ────────────────
    specJq ..> subsProductpage : subset_of
    specJq ..> subsReviews     : subset_of
    specJq ..> subsRatings     : subset_of
    specJq ..> subsDetails     : subset_of
```
