# Tennki_platform
Tennki Platform repository

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
