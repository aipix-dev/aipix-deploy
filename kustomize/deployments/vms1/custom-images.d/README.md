Use this folder to patch your images.
For example:
```
cat << EOF >> my-images.yaml
- name: download.aivp.io:8443/vms-backend/release
  newName: download.aivp.io:8443/vms-backend/release
  newTag: 24.12.1.2
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
