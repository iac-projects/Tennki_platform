# Tennki_platform
Tennki Platform repository

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
