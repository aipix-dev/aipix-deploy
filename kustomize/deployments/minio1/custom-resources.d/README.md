Use this folder to place your additional resources.
You must create a file "custom-resources.yaml" with a list of additional resources required for kustomization.
Then place resource manifests in the same folder using specific filenames.

For example:
```
cat << EOF >> custom-resources.yaml
- ./custom-resources.d/minio-services.yaml
EOF

cat << EOF > minio-services.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: minio
    app.kubernetes.io/component: storage
    app.kubernetes.io/part-of: vms
    global-app-name: vsaas
  name: minio
  namespace: vsaas-vms
spec:
  ports:
    - name: "http"
      port: 80
      protocol: TCP
      targetPort: 80
  selector:
    app.kubernetes.io/name: minio
    app.kubernetes.io/component: storage
    app.kubernetes.io/part-of: vms
    global-app-name: vsaas
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
