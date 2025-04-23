Use this folder to place your additional resources.
You must create a file "custom-resources.yaml" with a list of additional resources required for kustomization.
Then place resource manifests in the same folder using specific filenames.

For example:
```
cat << EOF >> custom-resources.yaml
- ./custom-resources.d/new-services.yaml
EOF

cat << EOF > new-services.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: service1
    app.kubernetes.io/component: monitoring
    app.kubernetes.io/part-of: monitoring
    global-app-name: vsaas
  name: service1
  namespace: vsaas-vms
spec:
  ports:
    - name: "http"
      port: 80
      protocol: TCP
      targetPort: 80
  selector:
    app.kubernetes.io/name: service1
    app.kubernetes.io/component: monitoring
    app.kubernetes.io/part-of: monitoring
    global-app-name: vsaas
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
