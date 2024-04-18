Use this folder to place your kustimizations patches.
You must create a file "custom-patches.yaml" with a list of patches required for kustomization.
Then place patch configurations in the same folder using specific filenames.

For example:
```
cat << EOF >> custom-patches.yaml
- target:
    group: ""
    version: v1
    kind: PersistentVolumeClaim
    name: storage
  path: ./custom-patches.d/patch-storage-pvc.yaml
EOF

cat << EOF > patch-storage-pvc.yaml
- op: replace
  path: /spec/storageClassName
  value: openebs-kernel-nfs-storage
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
