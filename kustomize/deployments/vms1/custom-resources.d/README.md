Use this folder to place your additional resources.
You must create a file "custom-resources.yaml" with a list of additional resources required for kustomization.
Then place resource manifests in the same folder using specific filenames.

For example:
```
cat << EOF >> custom-resources.yaml
- ./custom-resources.d/csa-configmap.yaml
- ./custom-resources.d/csa-deployments.yaml
- ./custom-resources.d/csa-services.yaml
EOF

cat << EOF > csa-deployments.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: csa
    app.kubernetes.io/component: csa
    app.kubernetes.io/part-of: vms
    global-app-name: vsaas
  name: csa
  namespace: vsaas-vms
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: csa
      app.kubernetes.io/component: csa
      app.kubernetes.io/part-of: vms
      global-app-name: vsaas
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: csa
        app.kubernetes.io/component: csa
        app.kubernetes.io/part-of: vms
        global-app-name: vsaas
    spec:
      containers:
        - name: csa
          envFrom:
          - configMapRef:
              name: csa-env
          args:
            - docker/csa.sh
          image: download.aipix.ai:8443/csa/release:latest
          imagePullPolicy: Always
          resources:
            requests:
              cpu: 5m
              memory: 50Mi
      imagePullSecrets:
        - name: download-aipix-ai
      hostname: csa
      restartPolicy: Always
EOF

cat << EOF > csa-services.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: csa
    app.kubernetes.io/component: csa
    app.kubernetes.io/part-of: vms
    global-app-name: vsaas
  name: csa
  namespace: vsaas-vms
spec:
  ports:
    - name: "http"
      port: 80
      protocol: TCP
      targetPort: 80
  selector:
    app.kubernetes.io/name: csa
    app.kubernetes.io/component: csa
    app.kubernetes.io/part-of: vms
    global-app-name: vsaas
EOF

cat << EOF > csa-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: csa-env
  namespace: vsaas-vms
data:
  DB_HOST: mysql-server
  DB_PORT: "3306"
EOF
```

For more information about kustomization read the folloqwing doc:
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
