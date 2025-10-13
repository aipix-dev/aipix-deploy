Use this folder to patch your images.
For example:
```
cat << EOF >> my-images.yaml
- name: download.aipix.ai:8443/vms-backend/release
  newName: download.aipix.ai:8443/vms-backend/release
  newTag: 25.06.1.0
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
