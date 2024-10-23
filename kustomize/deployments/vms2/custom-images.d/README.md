Use this folder to patch your images.
For example:
```
cat << EOF >> my-images.yaml
- name: my-repository:8443/my-app/dev
  newName: my-repository:8443/my-app/release
  newTag: 1.1.0.0
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
