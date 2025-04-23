Use this folder to place your additional resources.
You must create a file "custom-resources.yaml" with a list of additional resources required for kustomization.
Then place resource manifest in the same folder using specific filenames.

For example:
```
cat << EOF >> custom-resources.yaml
- ./custom-resources.d/clickhouse-service.yaml
- ./custom-resources.d/clickhouse-endpoints.yaml
EOF

cat << EOF > clickhouse-service.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: clickhouse-server
    app.kubernetes.io/component: db
    app.kubernetes.io/part-of: analytics
    global-app-name: vsaas
  name: clickhouse-server
spec:
  ports:
    - name: "http"
      port: 8123
      protocol: TCP
      targetPort: 8123
    - name: "client"
      port: 9000
      protocol: TCP
      targetPort: 9000
EOF

cat << EOF > clickhouse-endpoints.yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: clickhouse-server
  labels:
    app.kubernetes.io/name: clickhouse-server
    app.kubernetes.io/component: db
    app.kubernetes.io/part-of: analytics
    global-app-name: vsaas
subsets:
  - addresses:
      - ip: 192.168.20.131
    ports:
      - name: "http"
        port: 8123
      - name: "client"
        port: 9000
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
