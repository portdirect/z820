#!/bin/bash
set -ex



kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: rook-ceph
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: rook-release
  namespace: rook-ceph
spec:
  interval: 10m
  url: https://charts.rook.io/release
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  interval: 5m
  chart:
    spec:
      chart: rook-ceph
      sourceRef:
        kind: HelmRepository
        name: rook-release
        namespace: rook-ceph
      interval: 1m
...
EOF

sudo apt-get update
sudo apt-get install --no-install-recommends -y lvm2

kubectl apply -f - <<EOF
---
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: ceph
  namespace: rook-ceph
spec:
  dataDirHostPath: /var/lib/rook
  cephVersion:
    #see: https://tracker.ceph.com/issues/48797
    image: ceph/ceph:v15.2.7
    #allowUnsupported: true
  mon:
    count: 3
    allowMultiplePerNode: true
  dashboard:
    enabled: true
  crashCollector:
    disable: true
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: singapore
        devices:
          - name: /dev/disk/by-path/pci-0000:02:00.0-sas-phy4-lun-0
          - name: /dev/disk/by-path/pci-0000:02:00.0-sas-phy5-lun-0
          - name: /dev/disk/by-path/pci-0000:02:00.0-sas-phy6-lun-0
          - name: /dev/disk/by-path/pci-0000:02:00.0-sas-phy7-lun-0
EOF

kubectl apply -f - <<EOF
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: rbd-pvc
  namespace: rook-ceph
spec:
  failureDomain: osd
  replicated:
    size: 2
    # Disallow setting pool with replica 1, this could lead to data loss without recovery.
    # Make sure you're *ABSOLUTELY CERTAIN* that is what you want
    requireSafeReplicaSize: true
    # gives a hint (%) to Ceph in terms of expected consumption of the total cluster capacity of a given pool
    # for more info: https://docs.ceph.com/docs/master/rados/operations/placement-groups/#specifying-expected-pool-size
    #targetSizeRatio: .5
EOF


kubectl apply -f - <<EOF
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: ceph-rbd
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
    # clusterID is the namespace where the rook cluster is running
    # If you change this namespace, also change the namespace below where the secret namespaces are defined
    clusterID: rook-ceph

    # If you want to use erasure coded pool with RBD, you need to create
    # two pools. one erasure coded and one replicated.
    # You need to specify the replicated pool here in the pool parameter, it is
    # used for the metadata of the images.
    # The erasure coded pool must be set as the dataPool parameter below.
    #dataPool: rook-ceph
    pool: rbd-pvc

    # RBD image format. Defaults to "2".
    imageFormat: "2"

    # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only layering feature.
    imageFeatures: layering

    # The secrets contain Ceph admin credentials. These are generated automatically by the operator
    # in the same namespace as the cluster.
    csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
    csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
    csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
    csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
    csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
    csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
    # Specify the filesystem type of the volume. If not specified, csi-provisioner
    # will set default as ext4.
    csi.storage.k8s.io/fstype: ext4
# uncomment the following to use rbd-nbd as mounter on supported nodes
# **IMPORTANT**: If you are using rbd-nbd as the mounter, during upgrade you will be hit a ceph-csi
# issue that causes the mount to be disconnected. You will need to follow special upgrade steps
# to restart your application pods. Therefore, this option is not recommended.
#mounter: rbd-nbd
allowVolumeExpansion: true
reclaimPolicy: Delete
...
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rook-ceph-tools
  namespace: rook-ceph # namespace:cluster
  labels:
    app: rook-ceph-tools
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rook-ceph-tools
  template:
    metadata:
      labels:
        app: rook-ceph-tools
    spec:
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: rook-ceph-tools
        image: rook/ceph:v1.5.6
        command: ["/tini"]
        args: ["-g", "--", "/usr/local/bin/toolbox.sh"]
        imagePullPolicy: IfNotPresent
        env:
          - name: ROOK_CEPH_USERNAME
            valueFrom:
              secretKeyRef:
                name: rook-ceph-mon
                key: ceph-username
          - name: ROOK_CEPH_SECRET
            valueFrom:
              secretKeyRef:
                name: rook-ceph-mon
                key: ceph-secret
        volumeMounts:
          - mountPath: /etc/ceph
            name: ceph-config
          - name: mon-endpoint-volume
            mountPath: /etc/rook
      volumes:
        - name: mon-endpoint-volume
          configMap:
            name: rook-ceph-mon-endpoints
            items:
            - key: data
              path: mon-endpoints
        - name: ceph-config
          emptyDir: {}
      tolerations:
        - key: "node.kubernetes.io/unreachable"
          operator: "Exists"
          effect: "NoExecute"
          tolerationSeconds: 5
EOF

# To get ceph healthy on a single node:
POD=$(kubectl -n rook-ceph get pod -l app=rook-ceph-tools -o name | awk -F '/' '{ print $NF }')
kubectl -n rook-ceph exec -it ${POD} -- bash -c "ceph osd getcrushmap | crushtool -d - > /tmp/crush.map"
kubectl -n rook-ceph exec -it ${POD} -- bash -c 'sed -i "s/step chooseleaf firstn 0 type host/step chooseleaf firstn 0 type osd/g" /tmp/crush.map'
kubectl -n rook-ceph exec -it ${POD} -- bash -c 'crushtool -c /tmp/crush.map -o /tmp/crush.map.compiled'
kubectl -n rook-ceph exec -it ${POD} -- bash -c 'ceph osd setcrushmap -i /tmp/crush.map.compiled'

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: rook-ceph-mgr-dashboard-loadbalancer
  namespace: rook-ceph # namespace:cluster
  labels:
    app: rook-ceph-mgr
    rook_cluster: rook-ceph # namespace:cluster
spec:
  ports:
  - name: dashboard
    port: 80
    protocol: TCP
    targetPort: 7000
  selector:
    app: rook-ceph-mgr
    rook_cluster: rook-ceph
  sessionAffinity: None
  type: LoadBalancer
EOF

