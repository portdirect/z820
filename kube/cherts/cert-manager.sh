#!/bin/bash
set -ex
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: jetstack
  namespace: cert-manager
spec:
  interval: 10m
  url: https://charts.jetstack.io
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  interval: 5m
  chart:
    spec:
      chart: cert-manager
      version: 'v1.1.0'
      sourceRef:
        kind: HelmRepository
        name: jetstack
        namespace: cert-manager
      interval: 1m
  values:
    installCRDs: true
...
EOF