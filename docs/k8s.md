# Create a Kubernetes cluster with Kind

## Prerequisites

- Linux based terminal, Git bash, MacOs terminal or of course a terminal in a unix-system. Windows command prompt or Powershell does not work!
- kubectl (https://kubernetes.io/docs/tasks/tools/)
- docker
- kind
- helm
- jq
- base64

Optional:

- k9s (https://github.com/derailed/k9s) / lens (https://k8slens.dev/)

## Create a cluster with 1 controle plane and three workers:

```bash
kind create cluster --name testcluster --config ./config/kindconfig.yaml
```

After installation is complete, `kubectl get nodes` should be something like this:

```bash
kubectl get nodes
NAME                  STATUS   ROLES           AGE   VERSION
testcluster-control-plane   Ready    control-plane   77s   v1.31.0
testcluster-worker          Ready    <none>          62s   v1.31.0
testcluster-worker2         Ready    <none>          62s   v1.31.0
testcluster-worker3         Ready    <none>          62s   v1.31.0
```

## Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for argocd server to start:

```bash
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=90s
```

If `condition met` all good :white_check_mark:

### Getting ArgoCD initial admin passord:

```bash
kubectl get secrets -n argocd argocd-initial-admin-secret -o json | jq -r '.data.password' | base64 -d
```

This could result in something like this:

```bash
nr-p1tqyaMkUmB6T%
```

:exclamation: do not copy the `%` at the end! (could be my zsh installation too ...)

### Port forward to argocd webpage:

Open a new terminal and:

```bash
kubectl port-forward -n argocd services/argocd-server 58080:443
```

Open a browser at http://localhost:58080

Use username: `admin`

Use password: `<what you found in the steps about "Getting ArgoCD initial admin password section">`

## Install an Ingress controller (nginx)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Now the Ingress is all setup. Wait until is ready to process requests running:

```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

If `condition met` all good :white_check_mark:

# Install Nyan-cat test app with argocd application:

1. reuse portforward from previous and to to http://localhost:58080
   - or go to section "Port forward to argocd webpage
2. click the "+ NEW APP" or the "Create application" in the middle of the start page
3. inputs:
   - Application name: "nyan-cat"
   - Project name -> select "default"
   - Sync policy -> Automatic
   - Check off
     - :white_check_mark: Prune resources
     - :white_check_mark: Self heal
     - :white_check_mark: Set default finalizer
     - :white_check_mark: Auto-Create Namespace
   - Repository url: https://github.com/rogerwesterbo/nyan-cat.git
   - Path: charts/nyan-cat
   - Cluster Url -> "https://kubernetes.default.svc"
   - Namespace: "nyan-cat"
4. Click "create" button on top
5. Application will be create, and argocd will install the helm chart
6. :white_check_mark:

# Install Nyan-cat test app with helm

```bash
helm upgrade -i nyan-cat charts/nyan-cat -n nyancat --create-namespace
```
