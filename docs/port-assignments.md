# Port Assignment Reference

All `kubectl port-forward` commands use unique local ports to avoid conflicts when running multiple services simultaneously.

## Database Services

| Service     | Port Forward Command                                                                | Local Port | Service Port |
| ----------- | ----------------------------------------------------------------------------------- | ---------- | ------------ |
| MongoDB     | `kubectl port-forward --namespace mongodb service/mongodb-instance-svc 27017:27017` | 27017      | 27017        |
| PostgreSQL  | `kubectl port-forward -n postgres-cluster services/postgres-cluster-rw 5432:5432`   | 5432       | 5432         |
| Valkey      | `kubectl port-forward -n valkey svc/valkey-master 6381:6379`                        | 6381       | 6379         |

## Web UIs & Dashboards

| Service       | Port Forward Command                                                               | Local Port | Service Port | Local URL                                                     |
| ------------- | ---------------------------------------------------------------------------------- | ---------- | ------------ | ------------------------------------------------------------- |
| Grafana       | `kubectl port-forward -n prometheus services/prometheus-grafana 3000:80`           | 3000       | 80           | http://localhost:3000                                         |
| Kubeview      | `kubectl port-forward -n kubeview pods/<pod-name> 15004:8000`                      | 15004      | 8000         | http://localhost:15004                                        |
| Kite          | `kubectl -n kite port-forward svc/kite 15001:8080`                                 | 15001      | 8080         | http://localhost:15001 or http://kite.localtest.me[:port]     |
| Keycloak      | `kubectl port-forward -n keycloak svc/keycloak-http 15003:80`                      | 15003      | 80           | http://localhost:15003 or http://keycloak.localtest.me[:port] |
| OpenBao (Dev) | `kubectl port-forward -n openbao svc/openbao 8201:8200`                            | 8201       | 8200         | http://localhost:8201 or http://openbao.localtest.me[:port]   |
| PgAdmin       | `kubectl port-forward -n pgadmin services/pgadmin-pgadmin4 5050:80`                | 5050       | 80           | http://localhost:5050                                         |
| Falco UI      | `kubectl port-forward --namespace falco services/falco-falcosidekick-ui 2802:2802` | 2802       | 2802         | http://localhost:2802                                         |

**Note:**

-   Kite is accessible via ingress at `http://kite.localtest.me` (or with cluster-specific port if multiple clusters are running).
-   Keycloak is accessible via ingress at `http://keycloak.localtest.me` (or with cluster-specific port if multiple clusters are running).
-   OpenBao runs in dev mode with ingress at `http://openbao.localtest.me` (or with cluster-specific port if multiple clusters are running).

## Monitoring & Metrics

| Service      | Port Forward Command                                                                            | Local Port | Service Port | Local URL             |
| ------------ | ----------------------------------------------------------------------------------------------- | ---------- | ------------ | --------------------- |
| Prometheus   | `kubectl port-forward -n prometheus services/prometheus-kube-prometheus-prometheus 9090:9090`   | 9090       | 9090         | http://localhost:9090 |
| Alertmanager | `kubectl port-forward -n prometheus services/prometheus-kube-prometheus-alertmanager 9093:9093` | 9093       | 9093         | http://localhost:9093 |
| OpenCost     | `kubectl port-forward --namespace opencost service/opencost 9003 9090`                          | 9003       | 9090         | http://localhost:9003 |

## Messaging Services

| Service        | Port Forward Command                               | Local Port | Service Port | Protocol  |
| -------------- | -------------------------------------------------- | ---------- | ------------ | --------- |
| NATS Core      | `kubectl -n nats port-forward svc/nats 4222:4222`  | 4222       | 4222         | NATS      |
| NATS MQTT      | `kubectl -n nats port-forward svc/nats 1883:1883`  | 1883       | 1883         | MQTT      |
| NATS WebSocket | `kubectl -n nats port-forward svc/nats 15002:8080` | 15002      | 8080         | WebSocket |

## Quick Reference - Port Ranges

-   **1000-2999**: Falco (2802), NATS MQTT (1883)
-   **3000-3999**: Grafana (3000)
-   **4000-4999**: NATS Core (4222)
-   **5000-5999**: PostgreSQL (5432), PgAdmin (5050)
-   **6000-6999**: Valkey (6381)
-   **8000-8999**: OpenBao (8201)
-   **9000-9999**: OpenCost (9003), Prometheus (9090), Alertmanager (9093)
-   **15000+**: Kite (15001), NATS WebSocket (15002), Keycloak (15003), Kubeview (15004)
-   **27000+**: MongoDB (27017)

## Default Credentials

### Grafana

-   Username: `admin`
-   Password: `prom-operator`

### Keycloak

-   Username: `admin`
-   Password: `admin` (or retrieve with: `kubectl get secret -n keycloak keycloak-initial-admin -o jsonpath='{.data.password}' | base64 -d`)

### PgAdmin

-   Username: `chart@domain.com`
-   Password: `SuperSecret`

### PostgreSQL

-   User: `postgres`
-   Password: Retrieve with: `kubectl get secrets -n postgres-cluster postgres-cluster-superuser -o json | jq -r '.data.password' | base64 -d`

### MongoDB

-   Username: `appuser`
-   Password: `SuperSecret`

### OpenBao (Dev Mode)

-   Token: `openbao-root`
