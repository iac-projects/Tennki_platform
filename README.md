# Tennki_platform
Tennki Platform repository

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
````

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
    ````
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
