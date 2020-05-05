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

