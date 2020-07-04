# Tennki_platform
Tennki Platform repository

# HW.11 Kubernetes-gitops
**Репозиторий с кодом приложения**
https://gitlab.com/Tennki/microservices-demo 

## В процессе сделано:
- Подготовлен репозиторий с демо-приложением https://gitlab.com/Tennki/microservices-demo
- Сделан CI для автоматической сборки образов приложения и загрузки их в репозиторий. [gitlab-ci.yml](kubernetes-gitops/.gitlab-ci.yml)
- Развернут кластер в gke
```bash
# Создание кластера
gcloud beta container clusters create gitops \
    --addons=Istio --istio-config=auth=MTLS_PERMISSIVE \
    --cluster-version=1.16.9-gke.6 \
    --machine-type=n1-standard-2 \
    --num-nodes=4
# Включение Istio как плагина. Работает криво, пришлось ставить через istioctl.
gcloud beta container clusters update gitops \
    --update-addons=Istio=ENABLED --istio-config=auth=MTLS_PERMISSIVE
# Отлючение Istio
gcloud beta container clusters update gitops \
  --update-addons=Istio=DISABLED
```
- Установлен Istio
```bash
istioctl operator init
kubectl create ns istio-system
# Разворачиваем с профилем demo со включенными компонентами мониторинга и трейсинга
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: example-istiocontrolplane
spec:
  profile: demo
EOF
# Публикуем ресурсы (grafana,kiali,prometheus,jaeger) наружу.
kubectl apply -f kubernetes-gitops/istio/
```
- Установлен Flux
```bash
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml
helm repo add fluxcd https://charts.fluxcd.io
kubectl create namespace flux
helm upgrade --install flux fluxcd/flux -f flux.values.yaml --namespace flux
helm upgrade --install helm-operator fluxcd/helm-operator -f helm-operator.values.yaml --namespace flux
# Получаем ssh ключ flux и добавляем его в репозиторий
fluxctl identity --k8s-fwd-ns flux

# flux namespace creation log:
ts=2020-06-29T09:52:22.76400505Z caller=sync.go:605 method=Sync cmd="kubectl apply -f -" took=640.25118ms err=null output="namespace/microservices-demo created"
```
- Подготовлены helmrelease файлы для helm-operator (https://gitlab.com/Tennki/microservices-demo/-/tree/master/deploy/releases)
- Выполнено обновление сервиса frontend
```bash
# Лог обновления helmrelease frontend в через helm-operatror
ts=2020-06-29T14:11:57.054791338Z caller=release.go:75 component=release release=frontend targetNamespace=microservices-demo resource=microservices-demo:helmrelease/frontend helmVersion=v3 info="starting sync run"
ts=2020-06-29T14:11:57.311301633Z caller=release.go:289 component=release release=frontend targetNamespace=microservices-demo resource=microservices-demo:helmrelease/frontend helmVersion=v3 info="running upgrade" action=upgrade
ts=2020-06-29T14:11:57.342966237Z caller=helm.go:69 component=helm version=v3 info="preparing upgrade for frontend" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.34857561Z caller=helm.go:69 component=helm version=v3 info="resetting values to the chart's original version" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.839740316Z caller=helm.go:69 component=helm version=v3 info="performing update for frontend" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.854567296Z caller=helm.go:69 component=helm version=v3 info="creating upgraded release for frontend" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.864146087Z caller=helm.go:69 component=helm version=v3 info="checking 5 resources for changes" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.871875793Z caller=helm.go:69 component=helm version=v3 info="Looks like there are no changes for Service \"frontend\"" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.883710258Z caller=helm.go:69 component=helm version=v3 info="Created a new Deployment called \"frontend-hipster\" in microservices-demo\n" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.908296401Z caller=helm.go:69 component=helm version=v3 info="Looks like there are no changes for Gateway \"frontend-gateway\"" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.94174423Z caller=helm.go:69 component=helm version=v3 info="Looks like there are no changes for ServiceMonitor \"frontend\"" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.97658965Z caller=helm.go:69 component=helm version=v3 info="Looks like there are no changes for VirtualService \"frontend\"" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:57.983771404Z caller=helm.go:69 component=helm version=v3 info="Deleting \"frontend\" in microservices-demo..." targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:58.443024855Z caller=helm.go:69 component=helm version=v3 info="updating status for upgraded release for frontend" targetNamespace=microservices-demo release=frontend
ts=2020-06-29T14:11:58.482377921Z caller=release.go:309 component=release release=frontend targetNamespace=microservices-demo resource=microservices-demo:helmrelease/frontend helmVersion=v3 info="upgrade succeeded" revision=dde0e025fbc7c6c1cac0162a1c67aab5e17864e3 phase=upgrade
```
- Установлен Flagger
```bash
flagger install
kubectl apply -f https://raw.githubusercontent.com/weaveworks/flagger/master/artifacts/flagger/crd.yaml
helm upgrade --install flagger flagger/flagger \
--namespace istio-system \
--set crd.create=false \
--set meshProvider=istio \
--set metricsServer=http://prometheus:9090
```
- Добавлен лэйбл для namespace microservices-demo.
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices-demo
  labels:
    istio-injection: enabled
```
Flux применил изменения в кластере. 
```bash
# Пересоздаем поды чтобы istio добавил sidecar контейнеры
kubectl delete pods --all -n microservices-demo
# Проверка
kubectl get pods -n microservices-demo 
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-847589476d-2stgq               2/2     Running   0          4h33m
cartservice-85cb49794f-hhvvs             2/2     Running   0          4h33m
cartservice-redis-master-0               2/2     Running   0          21h
checkoutservice-6488cd446b-jk68l         2/2     Running   0          4h32m
currencyservice-69bd84979d-b65hh         2/2     Running   0          4h34m
emailservice-6659c8b578-jfmkv            2/2     Running   0          4h34m
frontend-primary-78844554f9-kxp2p        2/2     Running   0          4h27m
loadgenerator-68b7ccb7dd-czs6l           2/2     Running   2          4h31m
paymentservice-7cfb946d9d-nz7hl          2/2     Running   0          4h34m
productcatalogservice-64ffbc99d6-8qchm   2/2     Running   0          4h32m
recommendationservice-56f9b86fb4-2227c   2/2     Running   0          4h34m
shippingservice-76747dd4c4-fd6bz         2/2     Running   0          4h30m
```
- Добавлены Istio Gateway и VirtualService для сервиса frontend.
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: frontend-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "{{ .Values.ingress.host }}"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
spec:
  hosts:
  - "{{ .Values.ingress.host }}"
  gateways:
  - frontend-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
```
- Добавлен ресурс canary для сервиса frontend. 
```yaml
apiVersion: flagger.app/v1alpha3
kind: Canary
metadata:
  name: frontend
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  progressDeadlineSeconds: 60
  service:
    port: 80
    targetPort: 8080
    gateways:
    - frontend-gateway
    hosts:
    - {{ .Values.ingress.host }}
    trafficPolicy:
      tls:
        mode: DISABLE
    retries:
      attempts: 3
      perTryTimeout: 1s
      retryOn: "gateway-error,connect-failure,refused-stream"
  analysis:
    interval: 1m
    threshold: 1
    maxWeight: 30
    stepWeight: 10
    metrics:
    - name: request-success-rate
      threshold: 99
      interval: 1m
```
- Выполнен canary deploy сервиса frontend.
```bash
k describe canary -n microservices-demo frontend
Events:
  Type     Reason  Age                From     Message
  ----     ------  ----               ----     -------
  Warning  Synced  22m                flagger  deployment frontend.microservices-demo get query error: deployments.apps "frontend" not found
  Warning  Synced  21m                flagger  frontend-primary.microservices-demo not ready: waiting for rollout to finish: observed deployment generation less then desired generation
  Normal   Synced  20m (x2 over 21m)  flagger  all the metrics providers are available!
  Normal   Synced  20m                flagger  Initialization done! frontend.microservices-demo
  Normal   Synced  10m                flagger  New revision detected! Scaling up frontend.microservices-demo
  Normal   Synced  9m6s               flagger  Starting canary analysis for frontend.microservices-demo
  Normal   Synced  9m6s               flagger  Advance frontend.microservices-demo canary weight 10
  Normal   Synced  8m6s               flagger  Advance frontend.microservices-demo canary weight 20
  Normal   Synced  7m6s               flagger  Advance frontend.microservices-demo canary weight 30
  Normal   Synced  6m6s               flagger  Copying frontend.microservices-demo template spec to frontend-primary.microservices-demo
  Normal   Synced  5m6s               flagger  Routing all traffic to primary
  Normal   Synced  4m6s               flagger  (combined from similar events): Promotion completed! Scaling down frontend.microservices-demo
k get canaries -n microservices-demo frontend
NAME       STATUS      WEIGHT   LASTTRANSITIONTIME
frontend   Succeeded   0        2020-06-30T08:15:03Z
```
- Выполнен canary deploy сервиса adservice
```yaml
apiVersion: flagger.app/v1alpha3
kind: Canary
metadata:
  name: adservice
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: adservice
  progressDeadlineSeconds: 60
  service:
    port: 9555
    targetPort: 9555
    trafficPolicy:
      tls:
        mode: DISABLE
    retries:
      attempts: 3
      perTryTimeout: 1s
      retryOn: "connect-failure,refused-stream"
  analysis:
    interval: 1m
    threshold: 1
    maxWeight: 30
    stepWeight: 10
    metrics:
    - name: request-success-rate
      threshold: 99
      interval: 1m
```
![grafana](doc/images/grafana-adservice.png)
- Добавлена возможность отправки оповещений в Slack
```bash
helm upgrade -i flagger flagger/flagger -n istio-system\
--set slack.url=https://hooks.slack.com/services/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 \
--set slack.channel=gitops \
--set slack.user=flagger
```
![slack-notification](doc/images/slack-notification.png)
- Установлен ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# Публикуем UI наружу через istio
kubectl apply -f kubernetes-gitops/argocd/argocd.istio.yaml
```
- Подготовлен namespace demo для развертывания приложения через argocd 
```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
```
- Созданы отдельные приложения для сервисов из общего [репозитория](https://gitlab.com/Tennki/microservices-demo) путем указания путей до helm чартов (deploy/charts/adservice, deploy/charts/cartservice и т.д.).  
![argocd](doc/images/argocd.png)
![shop](doc/images/argo-shop.png)

# HW.10 Kubernetes-vault
## В процессе сделано:

- Установлен кластер consul
```bash
git clone https://github.com/hashicorp/consul-helm.git
helm install consul consul-helm
```
- Установлен кластер vault. Файл переменных [values.yaml](kubernetes-vault/vault-helm/values.yaml), добавлены параметры для включения tls.
```bash
git clone https://github.com/hashicorp/vault-helm.git
helm install vault vault-helm

helm status vault
NAME: vault
LAST DEPLOYED: Mon Jun 15 14:16:35 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get vault
```
- Выполнена инициализация vault
```bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
Unseal Key 1: J9rYhuKu3yiXF83ftvCukKwnThchbH+7Ice8FhBpm2I=

Initial Root Token: s.Odn2G0LWhZQDqnVgMu202bKo
```
Распечатываем поды vault:
```bash
kubectl exec -it vault-0 -- vault operator unseal 'J9rYhuKu3yiXF83ftvCukKwnThchbH+7Ice8FhBpm2I='
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.4.2
Cluster Name           vault-cluster-57c6a60f
Cluster ID             56560c42-f820-6dd9-4192-007d1f9b2a02
HA Enabled             true
HA Cluster             n/a
HA Mode                standby
Active Node Address    <none>

kubectl exec -it vault-1 -- vault operator unseal 'J9rYhuKu3yiXF83ftvCukKwnThchbH+7Ice8FhBpm2I='
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.4.2
Cluster Name           vault-cluster-57c6a60f
Cluster ID             56560c42-f820-6dd9-4192-007d1f9b2a02
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.244.1.6:8200

kubectl exec -it vault-2 -- vault operator unseal 'J9rYhuKu3yiXF83ftvCukKwnThchbH+7Ice8FhBpm2I='
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.4.2
Cluster Name           vault-cluster-57c6a60f
Cluster ID             56560c42-f820-6dd9-4192-007d1f9b2a02
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.244.1.6:8200
```
Логинимся в vault root token-ом
```bash
kubectl exec -it vault-0 -- vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                s.Odn2G0LWhZQDqnVgMu202bKo
token_accessor       v0R00gxXSmZZVekLY3b7TByC
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```
Получаем список авторизаций
```bash
kubectl exec -it vault-0 -- vault auth list
Path      Type     Accessor               Description
----      ----     --------               -----------
token/    token    auth_token_d4c88ac3    token based credentials
```
- Работа с ключами
Включаем kv engine и создаем секреты:
```bash
kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
kubectl exec -it vault-0 -- vault secrets list --detailed
kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='asajkjkahs'
kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='asajkjkahs'
kubectl exec -it vault-0 -- vault read otus/otus-ro/config
kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
Success! Enabled the kv secrets engine at: otus/
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options    Description                                                UUID
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------    -----------                                                ----
cubbyhole/    cubbyhole    cubbyhole_f0bd3412    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           62aebf2a-6043-7d01-f9a6-fb4208ffbb8b
identity/     identity     identity_8f248057     system         system     false             replicated     false        false                      map[]      identity store                                             1e4cf999-4292-61ea-a837-4554e2c5b818
otus/         kv           kv_d3379188           system         system     false             replicated     false        false                      map[]      n/a                                                        616c42fb-37b8-77c9-f266-72ce31ca7bf4
sys/          system       system_41a9c89c       n/a            n/a        false             replicated     false        false                      map[]      system endpoints used for control, policy and debugging    a8460ecc-ea6d-ec68-352e-4c3896800491
Success! Data written to: otus/otus-ro/config
Success! Data written to: otus/otus-rw/config
Key                 Value
---                 -----
refresh_interval    768h
password            asajkjkahs
username            otus
====== Data ======
Key         Value
---         -----
password    asajkjkahs
username    otus
```

- Работа с k8s
Включем авторизацию через k8s:
```bash
kubectl exec -it vault-0 -- vault auth enable kubernetes
kubectl exec -it vault-0 -- vault auth list
Path           Type          Accessor                    Description
----           ----          --------                    -----------
kubernetes/    kubernetes    auth_kubernetes_276985be    n/a
token/         token         auth_token_d4c88ac3         token based credentials
```
Мы смогли записать otus-rw/config т.к. в политике есть разрешение на create, но нет на update. Файл политики [otus-policy.hcl](kubernetes-vault/otus-policy.hcl)
- Использование vault-agent для получения секретов
```bash
kubectl apply -f kubernetes-vault/configmap.yaml
kubectl apply -f kubernetes-vault/example-k8s-spec.yaml
```
Итоговый файл [index.html](kubernetes-vault/index.html)
Конфиг инит контейнера в kubernetes-vault/example-k8s-spec.yaml переделан для работы по https.
- Использование vault в качестве CA.
```bash
kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="gitlab.example.ru" ttl="24h"
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUJQeRmEvg38wV7HyhHXHaSKXGfwwwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yMDA2MTYwNzM0MDhaFw0yNTA2
MTUwNzM0MzhaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMac7l3dm6uQ
0bgHySOU6EiE1l6YtqSBFPDVpmnJDyNnMn8n/tZH9AISit0B+4wM6gagfchEzbii
ZS99h9wqYk55piNkfkO8yUOgxUw9yTcWaC2bdnZZ4OZHgPPtd8tgGalcV7MDgyTi
n+pP0KL2roWKzbEuybnbZ3XYuXo+lsAd4a2JYtTI/3a04aaPuIBx/TIDHwlb56Wy
6BDUblvcyplDod/0B/mRbxqyh0be1WRuUnHggMccMfNUEF73hrxxof7IpHaGQVHc
oMR1IOdQxR9EpJPdOdNtCidSzBLH/CijQylDck5iImh5oKVL4Pu6gRtrNfJmEw4v
AdLn4nt1yxUCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUVt66P7FzKF96sTpZUAlT0cUhCXcwHwYDVR0jBBgwFoAU
jlgrHlD+qyErlnUGNj0NXDGZ/4gwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
EUakzY/EiLtj5jGqCPE5/0TCXbPssbhXWo97f2oizkQpaI7b8Fc/Rw7h3NdDMF5h
T2JXnEez+j8DttLNtBLgvA0yveMeDRyKk8sJLSG8vKOie4d0awGRDrJ4IZ65WjtK
lN21jIylizvN4K6HPq9ZwZlpzjotB9ex+bs2Ye5uTfVens8VW/GWF8xXxhpDJG+x
10IedMk8KRpbSIwNvinZpe/cirtA/emwIGrac4JH9JI+q3wB4iIsKKGKfJRhHFUa
zARc6uXCeAGbn+oontMASi+zsGWKIIJ07SUQxoK45q1eSlbrooCDiUiLUlENXdyP
1DaklS1sPKg/R6UrRK9TyA==
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUex8RqbWqW2fIXbA38ptJB9nA26cwDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTIwMDYxNjA3Mzk1OFoXDTIwMDYxNzA3NDAyN1owHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC4
nJN4PHZBPuY24FgQfoVU9+r6iJofhde4nCtbH0cg8w77bgw18T7eQh6Cz0/fYGnK
S2cVcxiWTn3edEw32qVFMBezfPO5cLKqYqYGUs07r70r7ec7Jv9TsVKRXNmL7uDL
vN3cme+BmV7y6FAuafU5m3XdN8KXtyAiDe70jr6Mim7eXKaxx+qzPYGQL4yG3Ad5
ATtlwelxIqw++PJLEt6vbWayUFdFK0pHp7fE/t+7Xjr6kslf0j038EgDyYgSCD2l
3WG6JV7Nb/jJMJmSEOJy4Ln5W69n3uPyjvaz3ssDCp7qZQBSQH5YUbzJUozdrjwY
jiiDeUCeAsXujfQ3GZZ/AgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUuPKWEsDgBgL+tj+f
9ZdiwlDT554wHwYDVR0jBBgwFoAUVt66P7FzKF96sTpZUAlT0cUhCXcwHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBAJwMLvYo
fRhUEEZyNQtvuDp4L84N1qlj4YVRWYigBceWosTm8H2QWzlLsV+4Yl5UsZltPObK
2T8gM6t27ujI9FyyTeNGbqAmaJ31E6SyL1uYr+mlAVFA7eKEPzq6EpGfwqWy7MlI
xcASmV4OJC5TJhDaZ3XUiJ/IgT9E2kPmrw03NnTzK9qG6wAiU1HnSMdaqY1FTxoO
NdTHpIqID4HedCMWcsoVwcVEzPinOle3L75wq1G6to3N/KScAx+QUOTCSJwKjxD9
GSV4aXoaebJ3TJrz6zudL7pMD6vTcxy3BNT1Jg4/+xF7XCv/9xwN86+E9aYoiWK+
fsNHpQNk0FY7s9E=
-----END CERTIFICATE-----
expiration          1592379627
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUJQeRmEvg38wV7HyhHXHaSKXGfwwwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhtYXBsZS5ydTAeFw0yMDA2MTYwNzM0MDhaFw0yNTA2
MTUwNzM0MzhaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMac7l3dm6uQ
0bgHySOU6EiE1l6YtqSBFPDVpmnJDyNnMn8n/tZH9AISit0B+4wM6gagfchEzbii
ZS99h9wqYk55piNkfkO8yUOgxUw9yTcWaC2bdnZZ4OZHgPPtd8tgGalcV7MDgyTi
n+pP0KL2roWKzbEuybnbZ3XYuXo+lsAd4a2JYtTI/3a04aaPuIBx/TIDHwlb56Wy
6BDUblvcyplDod/0B/mRbxqyh0be1WRuUnHggMccMfNUEF73hrxxof7IpHaGQVHc
oMR1IOdQxR9EpJPdOdNtCidSzBLH/CijQylDck5iImh5oKVL4Pu6gRtrNfJmEw4v
AdLn4nt1yxUCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUVt66P7FzKF96sTpZUAlT0cUhCXcwHwYDVR0jBBgwFoAU
jlgrHlD+qyErlnUGNj0NXDGZ/4gwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
EUakzY/EiLtj5jGqCPE5/0TCXbPssbhXWo97f2oizkQpaI7b8Fc/Rw7h3NdDMF5h
T2JXnEez+j8DttLNtBLgvA0yveMeDRyKk8sJLSG8vKOie4d0awGRDrJ4IZ65WjtK
lN21jIylizvN4K6HPq9ZwZlpzjotB9ex+bs2Ye5uTfVens8VW/GWF8xXxhpDJG+x
10IedMk8KRpbSIwNvinZpe/cirtA/emwIGrac4JH9JI+q3wB4iIsKKGKfJRhHFUa
zARc6uXCeAGbn+oontMASi+zsGWKIIJ07SUQxoK45q1eSlbrooCDiUiLUlENXdyP
1DaklS1sPKg/R6UrRK9TyA==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAuJyTeDx2QT7mNuBYEH6FVPfq+oiaH4XXuJwrWx9HIPMO+24M
NfE+3kIegs9P32BpyktnFXMYlk593nRMN9qlRTAXs3zzuXCyqmKmBlLNO6+9K+3n
Oyb/U7FSkVzZi+7gy7zd3JnvgZle8uhQLmn1OZt13TfCl7cgIg3u9I6+jIpu3lym
scfqsz2BkC+MhtwHeQE7ZcHpcSKsPvjySxLer21mslBXRStKR6e3xP7fu146+pLJ
X9I9N/BIA8mIEgg9pd1huiVezW/4yTCZkhDicuC5+VuvZ97j8o72s97LAwqe6mUA
UkB+WFG8yVKM3a48GI4og3lAngLF7o30NxmWfwIDAQABAoIBADCOFgdYt62fcoNa
bC8iZ8UaU7ZDOW4zELLgeFLGHjofU4BzyEhjxCpG76luB070F776KAmvNPdLe7WH
lwhVvIQ/CuzNX3kVmBhSS+J74rjhFvs33kpjjmIf0FylNB6m3H8ZlKzR2/mVMjDn
QzeB7NqS9eQSJ18p7gym54NxC9MAn5dz3p0GSe8pWq4hXy7/xRU3T5GjLwUSU+T3
DZP8+7l/FEvgMsV6G0deQVam9iQr7cR6HQ8OOUNMjUaM7w+GUNV4iLUii3JDSQd7
R1QnrEwFi+VyEANli/JOdLmn03knN/MAg+DOJK70w6SgaKMcbW/nH/u0sG3aq6jB
j5F1hNkCgYEA1Hv+XxoWaVPb3XoNRCungJfrU3IFta7s52tFOV0UxRqsxfXFnwOx
NrKaRQlzFUco0RqgjF7pLxbXYJDJ1+gNoWc3K6vZWeSyqWWiBxtn9eqrChxgPSE/
ZN9LwheH4nxi5nsh0EvcqfdPSXdYzI5SbRDyhEWFauvBVsyCll2N6i0CgYEA3mtJ
j3oJLQ1pAoG/xCPpqGotKsksdPvcBSVImnQFgBiBZGEqmrSf3O997Mz6QuopDsw1
wueVesMiA7m4RZDlaVnSkhyvQAWlIIj2xmTLC+7pe9ZrGF8LvvCm49/zkBlOXuPX
izH6xphTZgl0IDrY7T+ICfbcpi1rfJjikGAOitsCgYAKUD5nhU+jKyPX2y27qlbG
Ahm1AirOx7/N98HzZ9YzPvk13pkJ/9bhLcgZI71HQh30EFPMnGq7E2O+1yhE54mJ
1QWzg/LXzybw2/MCX00rfYlxwzDUpsF59vCpahT5ZEo0n7NjddsvEMbzbOyNeTb8
/j6XNvyj1O+cc+6+t6nEvQKBgCrX38OTblEPVDr3Y0kU4d1fFnQ3bCjcmvUiyWl3
D9gs4D/Ft781K9YTC96hXVOmZ2JCU9jHYzPSgqrVC3na/1Xbx4P9ooRikfxCZcax
g6s4yiDgnKCFLm4JTRx39yK6vS3qFYrqhbPbg7UT/Rp4O3D32+yPcNFRznKhwIKu
/h4hAoGBAJJr7C+DA81dsmpnSmLPbzrQE1Gc/5woO+LVZoeIe7e70iQCMv2muno7
9LPomPfR+WakYEP6JSj0d+38Laj6UNH3yh6dVi0hCJlTVy6Vn3Rg246xvQW8Jm5+
eOqgnSmTzYSud1a0yuOg+wWYjps6XIxqXTQaApI5YjXxbg2Dm0C9
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       7b:1f:11:a9:b5:aa:5b:67:c8:5d:b0:37:f2:9b:49:07:d9:c0:db:a7


kubectl exec -it vault-0 -- vault write pki_int/revoke serial_number="7b:1f:11:a9:b5:aa:5b:67:c8:5d:b0:37:f2:9b:49:07:d9:c0:db:a7"
Key                        Value
---                        -----
revocation_time            1592293300
revocation_time_rfc3339    2020-06-16T07:41:40.6715085Z
```
### Включение TLS
```bash
# Генерим ключ
openssl genrsa -out vault.key 2048
# Создаем файл запроса на основе конфига vault-csr.conf и сгенерированного ключа vault.key
# В vault-csr.conf в разделе alt_names указываем дополнительные имена сервиса vault
openssl req -new -key vault.key -subj "/CN=vault" -out vault.csr -config vault-csr.conf
# Создаем манифест запроса для запроса сертификата в k8s
export CSR_NAME=vault-csr
cat <<EOF >vault-csr.yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  groups:
  - system:authenticated
  request: $(cat vault.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
# Запрашиваем сертификат
kubectl create -f vault-csr.yaml
# Апрувим выдачу сертификата
kubectl certificate approve ${CSR_NAME}
# Вытаскиваем сертификат и сохраняем в файл vault.crt
serverCert=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}')
echo "${serverCert}" | openssl base64 -d -A -out vault.crt
# Создаем секрет в k8s из сертификата и ключа
kubectl create secret generic vault \
    --from-file=vault.key=vault.key \
    --from-file=vault.crt=vault.crt 
```
```yaml
# Добавляем в файл переменных созданный волюм, включаем tls и указывае пути до сертификата и ключа
  extraEnvironmentVars:
    VAULT_ADDR: https://localhost:8200
    VAULT_CACERT: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  ...
  extraVolumes:
    - type: secret
      name: vault
      path: null
  ...
  config: |
      ui = true

      listener "tcp" {
        tls_disable = 0
        address = "[::]:8200"
        cluster_address = "[::]:8201"
        tls_cert_file = "/vault/userconfig/vault/vault.crt"
        tls_key_file  = "/vault/userconfig/vault/vault.key"      
      }
```
```bash
# Обновляем чарт, при обновление надо убивать поды руками чтоб они пересоздались с новым конфигом
helm upgrade --install vault vault-helm
# Проверка tls
VAULT_ADDR=https://vault:8200
VAULT_CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
curl --cacert $VAULT_CACERT --header "X-Vault-Token:s.6KmnlbjUKM9XsQmPJXaV5Tsv" $VAULT_ADDR/v1/otus/otus-ro/config | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   207  100   207    0     0   9409      0 --:--:-- --:--:-- --:--:--  9857
{
  "request_id": "d00be0f9-a964-998f-71c5-fc5f35fce3b5",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 2764800,
  "data": {
    "password": "asajkjkahs",
    "username": "otus"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}
```
### Автогенерация сертификатов для nginx
 - В политику [otus-policy.hcl](kubernetes-vault/otus-policy.hcl) добавлена возможность запрашивать сертификаты
 ```json
  path "pki_int*" {
  capabilities = ["read", "update", "create", "list", "sudo", "delete"]
  }

  path "pki*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
 ```
 - В файле [nginx-ssl-configmap.yaml](kubernetes-vault/nginx-ssl-configmap.yaml) описаны 2 конфигмапа: конфиг nginx для включения ssl и конфиг для vault-agent.
 ```go
    // Рендер сертификата CA
    template {
    destination = "/etc/secrets/ca.crt"
    contents = "{{ with secret \"pki_int/issue/example-dot-ru\" \"common_name=nginx.example.ru\" \"ttl=24h\" }}{{ .Data.issuing_ca }}{{ end }}"
    }
    // Рендер private key
    template {
    destination = "/etc/secrets/tls.key"
    contents = "{{ with secret \"pki_int/issue/example-dot-ru\" \"common_name=nginx.example.ru\" \"ttl=24h\" }}{{ .Data.private_key }}{{ end }}"
    }
    // Рендер сертификата nginx
    template {
    destination = "/etc/secrets/tls.crt"
    contents = "{{ with secret \"pki_int/issue/example-dot-ru\" \"common_name=nginx.example.ru\" \"ttl=24h\" }}{{ .Data.certificate }}{{ end }}"
    }
    // Рендер index.html
    template {
    destination = "/vault/file/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/otus-ro/config" }}
    <ul>
    <li><pre>username: {{ .Data.username }}</pre></li>
    <li><pre>password: {{ .Data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }
 ```
- В файле [nginx-ssl.yaml](kubernetes-vault/nginx-ssl.yaml) описан под nginx. При создании пода инит контейнер с vault-agent создает файлы сертификатов, ключа и index.html и складывает на волюмы, которые потом монтируются в nginx.
```yaml
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: shared-data
    - mountPath: /etc/nginx/certs
      name: shared-secrets
    - mountPath: /etc/nginx/conf.d
      name: nginx-config
```
При каждом перезапуске пода получаем новый сертификат
Проверка:  
![cert1](doc/images/cert1.png)
![cert2](doc/images/cert2.png)

# HW.9 Kubernetes-logging
## В процессе сделано:
- Подготовлен k8s кластер в GCP
- Установлено демо-приложение
```bash
kubectl create ns microservices-demo
kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Logging/microservices-demo-without-resources.yaml -n microservices-demo
```
- Установлен nginx-ingress
```bash
kubectl create ns nginx-ingress
helm upgrade --install nginx-ingress stable/nginx-ingress --wait --namespace=nginx-ingress -f nginx-ingress.values.yaml
```
- Установлен Prometheus + Grafana
```
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
helm upgrade --install prometheus-operator stable/prometheus-operator --namespace observability --set prometheusOperator.createCustomResource=false -f prometheus-operator.values.yaml
```
Файл переменных [prometheus-operator.values.yaml](kubernetes-logging/prometheus-operator.values.yaml)
- Установлен EFK стек. Kinbana
```bash
helm upgrade --install elasticsearch elastic/elasticsearch --namespace observability -f elasticsearch.values.yaml
helm upgrade --install kibana elastic/kibana --namespace observability -f kibana.values.yaml
helm upgrade --install fluent-bit stable/fluent-bit --namespace observability -f fluent-bit.values.yaml
helm upgrade --install elasticsearch-exporter stable/elasticsearch-exporter --setes.uri=http://elasticsearch-master:9200 --set serviceMonitor.enabled=true --namespace=observability
```
Файл переменных [elasticsearch.values.yaml](kubernetes-logging/elasticsearch.values.yaml)  
Файл переменных [kibana.values.yaml](kubernetes-logging/kibana.values.yaml)  
Файл переменных [fluent-bit.values.yaml](kubernetes-logging/fluent-bit.values.yaml)
- Создан дашборд ElasticSearch [export.ndjson](kubernetes-logging/export.ndjson)
- Установлен Loki стек
```bash
helm repo add loki https://grafana.github.io/loki/charts
helm repo update
helm upgrade --install loki loki/loki-stack --namespace observability -f loki.values.yaml
```
Файл переменных [loki.values.yaml](kubernetes-logging/loki.values.yaml)
- Создан дашборд Grafana [nginx-ingress.json](kubernetes-logging/nginx-ingress.json)  
![Nginx-Dashboard](doc/images/nginx-dashboard.png)
- |* Audit logging
  - Развернут self-hosted кластер в GCP. 1 мастер + 2 ноды. Использован ansible для установки docker и kubeadm. Кластер развернут с помощью kubeadm
  ```bash
  kubeadm init --control-plane-endpoint="10.166.0.11:6443" --pod-network-cidr=10.244.0.0/16 --upload-certs
  ```
  - Настроен аудит. Добавлены следующие параметры в конфигурацию пода [kube-apiserver](kubernetes-logging/audit/kube-apiserver.yaml)
  ```yaml
    - --audit-policy-file=/etc/kubernetes/policies/audit-policy.yaml
    - --audit-log-path=/var/log/kube-audit/audit.log
    - --audit-log-format=json
    - --audit-log-maxbackup=10
    - --audit-log-maxsize=100
    - --audit-log-maxage=7
  ```
  - Добавляем политику аудита на мастер хосте /etc/kubernetes/policies/[audit-policy.yaml](kubernetes-logging/audit/audit-policy.yml) Использована дефолтная политика [GCE](https://github.com/kubernetes/kubernetes/blob/master/cluster/gce/gci/configure-helper.sh#L1017-L1144).
  - Установлен Prometheus+Grafana (http://grafana.k8s.tennki.tk)
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
  kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
  kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
  kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
  kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
  kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.38/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
  helm upgrade --install prometheus-operator stable/prometheus-operator --set prometheusOperator.createCustomResource=false -f audit/prometheus-operator.values.yaml
  ```
  - Установлен Loki+Promtail
  ```bash
  helm upgrade --install loki loki/loki-stack -f audit/loki.values.yaml
  ```
  ![Audit-logs](doc/images/audit-logs.png)


# HW.8 Kubernetes-monitoring
## В процессе сделано:
- Подготовлен кастомный образ [nginx](kubernetes-monitoring/nginx) с модулем ngx_http_stub_status_module [nginx_conf](kubernetes-monitoring/nginx/conf). 
```bash
docker build -t tenki/nginx:1.0 .
docker push tenki/nginx:1.0
``` 
- Подготовлен [Deployment](kubernetes-monitoring/deployment.yaml) для запуска 3-х реплик приложения и [Service](kubernetes-monitoring/service.yaml). В поде 2 контейнера: "web" - nginx, "exporter" - nginx-exporter. Exporter запускается из образа [nginx/nginx-prometheus-exporter:0.7.0](https://hub.docker.com/r/nginx/nginx-prometheus-exporter/tags)
```bash
kubectl apply -f kubernetes-monitoring/deployment.yaml
kubectl apply -f kubernetes-monitoring/service.yaml
```
- Prometheus-operator запускался вместе с Prometheus и Grafana из проекта [coreos/kube-prometheus](https://github.com/coreos/kube-prometheus). В манифестах уменьшено количество реплик Prometheus и Grafana [manfests](kubernetes-monitoring/kube-prometheus/manifests).
```bash
minikube delete && minikube start --kubernetes-version=v1.18.1 --memory=4g --bootstrapper=kubeadm --extra-config=kubelet.authentication-token-webhook=true --extra-config=kubelet.authorization-mode=Webhook --extra-config=scheduler.address=0.0.0.0 --extra-config=controller-manager.address=0.0.0.0
minikube addons disable metrics-server
kubectl apply -f kubernetes-monitoring/kube-prometheus/manifests/setup
kubectl apply -f kubernetes-monitoring/kube-prometheus/manifests
```
- Подготовлен [ServiceMonitor](kubernetes-monitoring/servicemonitor.yaml)
```bash
kubectl apply -f kubernetes-monitoring/servicemonitor.yaml
```
- Графики  
![grafana](doc/images/grafana-nginx.png) 



# HW.7 Kubernetes-operators
## В процессе сделано:
- Подготовлена программа реализующая работу оператора [mysql-operator.py](kubernetes-operators/build/mysql-operator.py).
- Подготовлен образ для запуска mysql оператора. [Dockerfile](kubernetes-operators/build/Dockerfile)
```bash
docker build -t tenki/mysql-operator:v0.1 .
docker push tenki/mysql-operator:v0.1
``` 
- Создан [CustomResourceDefinition](kubernetes-operators/deploy/crd.yml) определяющий формат кастомного ресурса mysql и правила валидации.
Секция required требует наличия поля в описании объекта СustomResource.  
```yaml
          required:
          - image
          - database
          - password
          - storage_size
```
- Создан [Deployment](kubernetes-operators/deploy/deploy-operator.yml) для запуска оператора.
```bash
kubectl apply -f kubernetes-operators/deploy/crd.yml
kubectl apply -f kubernetes-operators/deploy/service-account.yml
kubectl apply -f kubernetes-operators/deploy/role.yml
kubectl apply -f kubernetes-operators/deploy/clusterrolebinding.yml
kubectl apply -f kubernetes-operators/deploy/deploy-operator.yml
```
- Выполнена проверка корректности работы оператора:
```bash
# Создаем CustomResource
kubectl apply -f kubernetes-operators/deploy/cr.yml

# Создаем БД, добавляем данные
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
kubectl exec -it $MYSQLPOD -- mysql -u root -potuspassword -e "CREATE TABLE test (id smallint unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key (id));" otus-database
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name) VALUES ( null, 'some data' );" otus-database
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name) VALUES ( null, 'some data-2' );" otus-database

# Удаляем CustomResource
kubectl delete mysqls.otus.homework mysql-instance

# Пересоздаем CustomResource
kubectl apply -f kubernetes-operators/deploy/cr.yml

# Запрос данных из БД после восстановления
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
```
Данные после восстановления.  
![result](doc/images/mysql-operator.png)

# HW.6 Kubernetes-templating
## В процессе сделано:
- Установлен helm chart nginx-ingress
```bash
kubectl create ns nginx-ingress
helm upgrade --install nginx-ingress stable/nginx-ingress --wait --namespace=nginx-ingress --version=1.38.0
```
- Установлен helm chart cert-manager
```bash
kubectl create ns nginx-ingress
helm repo add jetstack https://charts.jetstack.io
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation="true"
helm upgrade --install cert-manager jetstack/cert-manager --wait --namespace=cert-manager --version=0.9.0
kubectl apply -f kubernetes-templating/cert-manager/clusterissuer.yaml
```
- Установлен helm chart chartmuseum
```bash
kubectl create ns chartmuseum
helm upgrade --install chartmuseum stable/chartmuseum --wait --namespace=chartmuseum --version=2.13.0 -f kubernetes-templating/chartmuseum/values.yaml
```
- |* Процесс работы с chartmuseum
```bash
# Добавление репозитория
helm repo add chartmuseum https://chartmuseum.tennki.tk
# Загрузка chart в репозиторий
curl -L --data-binary "@frontend-0.1.0.tgz" http://chartmuseum.tennki.tk/api/charts{"saved":true}
# Обновление списка чартов
helm repo update                           
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "harbor" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈ Happy Helming!⎈ 
# Поиск чарта frontend
helm search repo frontend
NAME                    CHART VERSION   APP VERSION     DESCRIPTION                                       
chartmuseum/frontend    0.1.0           1.16.0          A Helm chart for Kubernetes
# Установка чарта
helm upgrade --install frontend chartmuseum/frontend --wait --namespace=hipster-shop
```
- Установлен helm chart harbor
```bash
helm repo add harbor https://helm.goharbor.io
kubectl create ns harbor
helm upgrade --install harbor harbor/harbor --wait --namespace=harbor --version=1.1.2 -f kubernetes-templating/harbor/values.yaml
```
- |* Подготовлен [helmfile](kubernetes-templating/helmfile/helmfile.yaml) для запуска nginx-ingress,cert-manager и harbor. В файле используются файл [harbor.yaml](kubernetes-templating/helmfile/values/harbor.yaml) для переопределения некоторых параметров чарта harbor и файл манифеста [clusterissuer.yaml](kubernetes-templating/helmfile/charts/cert-manager/clusterissuer.yaml) для создания Prod ClusterIssuer. 
```bash
helmfile -f kubernetes-templating/helmfile/helmfile.yaml sync
```
- Создан helm chart [hipster-shop](kubernetes-templating/hipster-shop)
```bash
kubectl create ns hipster-shop
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
```
- Отделен сервис frontend и на его основе создан helm chart [frontend](kubernetes-templating/frontend)
```bash
helm upgrade --install frontend kubernetes-templating/frontend --namespace hipster-shop
```
- Чарт frontend добавлен как зависимость в чарт hipster-shop [Chart.yaml](kubernetes-templating/hipster-shop/Chart.yaml)
```yaml
dependencies:
  - name: frontend
    version: 0.1.0
    repository: "file://../frontend"
```
- |* Удален сервис redis, вместо него использован community chart stable/redis [Chart.yaml](kubernetes-templating/hipster-shop/Chart.yaml)
```yaml
dependencies:
  - name: redis
    version: 10.5.7
    repository: "https://kubernetes-charts.storage.googleapis.com"
```
- От hipster-shop отделены сервисы paymentservice, shippingservice и описаны с помощью jsonnet.
```bash
kubecfg show kubernetes-templating/kubecfg/services.jsonnet
kubecfg update kubernetes-templating/kubecfg/services.jsonnet --namespace hipster-shop
```
- От hipster-shop отделен сервис recommendationservice и использован в качестве шаблона для kustomize. 
```bash
kubectl apply -k kubernetes-templating/kustomize/overrides/dev
kubectl apply -k kubernetes-templating/kustomize/overrides/prod
```

# HW.5 Kubernetes-volumes
## В процессе сделано:
- Запущен StatefusSet minio
```bash
kubectl -f kubernetes-volumes/minio-statefulset.yaml
```
- Запущен сервис для доступа к StatefulSet minio
```bash
kubectl -f kubernetes-volumes/minio-headless-service.yaml
```
- Создан [secret](kubernetes-volumes/minio-secret.yaml) для хранения переменных необходимых для запуска minio
```bash
kubectl create secret generic minio-secret --from-literal=MINIO_ACCESS_KEY='minio' --from-literal=MINIO_SECRET_KEY='minio123'
```
или
```bash
kubectl -f kubernetes-volumes/minio-secret.yaml
```

# HW.4 Kubernetes-networks
## В процессе сделано:
- В [под web](kubernetes-intro/web-pod.yaml) добавлены проверки работоспособности.
- Создан [Deployment](kubernetes-networks/web-deploy.yaml) для запуска web приложения.
```bash
kubectl apply -f web-deploy.yaml
```
- Создан сервис ClusterIP (kubernetes-networks/web-svc-cip.yaml)
```bash
kubectl apply -f web-svc-cip.yaml
```
- Включен IPVS в minikube
- Развернут MetalLB
```bash 
kubectl apply -fhttps://raw.githubusercontent.com/google/metallb/v0.8.0/manifests/metallb.yaml
kubectl apply -f metallb-config.yaml
```
- Создан сервис LoadBalancer для приложения
```bash
kubectl apply -f web-svc-lb.yaml
```
- Создан сервис LoadBalancer для публикации CoreDNS наружу.
```bash
~: kubectl apply -f kubernetes-networks/coredns/coredns-svc-lb.yaml
~: nslookup web-svc-cip.default.svc.cluster.local 172.17.255.10
Server:		172.17.255.10
Address:	172.17.255.10#53

Name:	web-svc-cip.default.svc.cluster.local
Address: 10.96.166.80
```
- Развернут Ingress Nginx
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
kubectl apply -f kubernetes-networks/nginx-lb.yaml
```
- Приложение опубликовано через ingress http://<ingress_lb_ip>/web
```bash
kubectl apply -f kubernetes-networks/web-svc-headless.yaml
kubectl apply -f kubernetes-networks/web-ingress.yaml
```
- Развернут Kubernetes Dashboard
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.1/aio/deploy/recommended.yaml
```
- Dashboars опубликован через Ingress
  - [Dashboard Ingress Help1](https://aws.amazon.com/ru/premiumsupport/knowledge-center/eks-kubernetes-dashboard-custom-path/)
  - [Dashboard Ingress Help2](https://kubernetes.github.io/ingress-nginx/examples/rewrite/)
```bash
kubectl apply -f kubernetes-networks/dashboard/dashboard-ingress.yaml
```
- Проверен [Сanary release](kubernetes-networks/canary) через ingress-nginx
  - Модифицирован прод Ingress
  ```yaml
  spec:
   rules:
   - host: web.local
  ```
  - Создан Namespace Canary
  - Развернут Canary deployment
  - Создан сервис LoadBalancer для Canary deployment
  - Создан Canary Ingress
  - [Сanary release with ingress-nginx help1](https://kubesphere.io/docs/quick-start/ingress-canary/)
  - [Сanary release with ingress-nginx help2](https://medium.com/@domi.stoehr/canary-deployments-on-kubernetes-without-service-mesh-425b7e4cc862)
  - [Сanary release with ingress-nginx help3](https://mcs.mail.ru/help/ingress/setup-canary-deployment-on-kubernetes)
```bash  
~: kubectl apply -f kubernetes-networks/canary/
~: curl -s -H "canary: never" --resolve web.local:80:172.17.255.2 web.local/web | grep HOSTNAME
export HOSTNAME='web-74c8c7ff89-6vnf7'
~: curl -s -H "canary: always" --resolve web.local:80:172.17.255.2 web.local/web | grep HOSTNAME
export HOSTNAME='canary-7557bfbbdb-x8d6l'
```

# HW.3 Kubernetes-security
## В процессе сделано:
- [Task 1](kubernetes-security/task01)
  - Создан Service Account (SA) bob с кластер ролью admin.
  - Создан SA dave.
- [Task 2](kubernetes-security/task02)
  - Создан Namespace (NS) prometheus.
  - Создан SA carol в NS prometheus.
  - Создана Cluster Role с возможностью get, list, watch всех подов в кластере. 
  - Cоздан Cluster Role Binding для всех SAs в NS prometheus.
- [Task 3](kubernetes-security/task02)
  - Создан NS dev.
  - Создан SA jane в NS dev.
  - Создана Role admin в NS dev
  - Предоставлена Role admin для всех jane в NS dev.
  - Создан SA ken в NS dev.
  - Создана Role view в NS dev
  - Предоставлена Role view для SA ken в NS dev.

# HW.2 Kubernetes-controllers
## В процессе сделано:
- Запущен k8s кластер на основе kind.
- Создан манифест [Replicaset](kubernetes-controllers/frontend-replicaset.yaml) для запуска 1й реплики приложения frontend. Для успешного запуска в манифесте не хватало секции selector.
```yaml
  selector:
    matchLabels:
      app: frontend
```
- Изменена версия образ для запуска frontend приложения на 0.0.2, выполнена попытка обновления запущенной реплики. Образ в поде не обновился т.к. ReplicationController следит за тем чтобы количество запущенных подов соответсвовало указанному в конфигурации replicaset. ReplicationController не перезапускает поды при обновлении replicaset.
- Собран образ для приложения paymentservice и загружен на DockerHub c двумя разными тэгами.
- Создан манифест [Replicaset](kubernetes-controllers/paymentservice-replicaset.yaml) для запуска 3х реплик приложения paymentservice с версией 0.0.1. На основе манифеста replicaset создан [Deployment](kubernetes-controllers/paymentservice-deployment.yaml) манифеста для paymentservice и выполнен запуск деплоймента.
- Изменена версия образ для запуска paymentservice приложения на 0.0.2. Обновлен деплоймент paymentservice.
- Выполнен откат деплоймента paymentservice до версии 0.0.1.
```bash
kubectl rollout undo deployment paymentservice --to-revision=1
```
- Созданы два манифеста осуществляющие разные стратегии обновления deployment paymentservice: 
   - [Blue-green](kubernetes-controllers/paymentservice-deployment-bg.yaml)
   ```yaml
   strategy:
      type: RollingUpdate
      rollingUpdate:
      maxSurge: 100%
      maxUnavailable: 0
   ```
   - [Reverse rolling update](kubernetes-controllers/paymentservice-deployment-reverse.yaml)
   ```yaml
   strategy:
      type: RollingUpdate
      rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
   ```
- Cоздан [Deployment](kubernetes-controllers/frontend-deployment.yaml) манифеста для приложения frontend осуществляющий проверку работоспособности приложения при помощи probes.
- Создан манифест [DaemonSet](kubernetes-controllers/node-exporter-daemonset.yaml) для запуска Node Exporter. За основу взят https://github.com/coreos/kube-prometheus/blob/master/manifests/node-exporter-daemonset.yaml
Для возможности запуска на master нодах можно воспользоваться следующими конструкциями:
```yaml
tolerations:
   - operator: "Exists"
```
```yaml
tolerations:
- key: node-role.kubernetes.io/master
  effect: NoSchedule
```

# HW.1 Kubernetes-intro
## В процессе сделано:
 - Запущен k8s кластер на основе minikube и kind.
 - Проверена способность кластера к самовосстановлению после удаления docker контейнеров и после удаления системных pod-ов. Контроль системных pod-ов осуществляет kubelet, контроль pod-ов развернутых через deployment осуществляет ReplicationController.
 - Подготовлен образ веб-приложения и загружен в публичный репозиторий Docker hub.
    ```bash
    docker build -t tenki/web:1.0
    docker push tenki/web:1.0
    ```
 - Запущен pod созданного веб-приложения в k8s.
    ```bash
    kubectl apply -f web-pod.yaml
    ```
 - Создан образ frontend компонент из проекта https://github.com/GoogleCloudPlatform/microservices-demo
    ```bash
    docker build -t tenki/hipster-frontend:v0.0.1
    docker push tenki/hipster-frontend:v0.0.1
    ```
   Сгенерирован манифест для запуска пода из образа.
    ```bash
    kubectl run frontend --image avtandilko/hipster-frontend:v0.0.1 --restart=Never --dry-run -o yaml > frontend-pod.yaml
    ```
   В ходе анализа логов пода выяснилось что для успешного запуска необходимо указать ряд переменных: 
    ```yaml
    - name: PRODUCT_CATALOG_SERVICE_ADDR
    value: "productcatalogservice:3550"
    - name: CURRENCY_SERVICE_ADDR
    value: "currencyservice:7000"
    - name: CART_SERVICE_ADDR
    value: "cartservice:7070"
    - name: RECOMMENDATION_SERVICE_ADDR
    value: "recommendationservice:8080"
    - name: SHIPPING_SERVICE_ADDR
    value: "shippingservice:50051"
    - name: CHECKOUT_SERVICE_ADDR
    value: "checkoutservice:5050"
    - name: AD_SERVICE_ADDR
    value: "adservice:9555"
    ```
    ```bash
    kubectl apply -f frontend-pod-healthy.yaml
    ```
