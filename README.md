# Tennki_platform
Tennki Platform repository

# HW.14 Kubernetes-storage
## В процессе сделано:

- Выполнено развертывание k8s кластера v1.17 через kubeadm. Кластер создавался в GCP.
Конфигурация кластера 4 ВМ GCP, ОС Ubuntu 18.04 LTS:
  - master - 1 экземпляр (n1-standard-2)
  - worker - 3 экземпляра (n1-standard-1)
```bash
# Усатновку компонентов необходимо выполнить на всех нодах.
# Отключаем swap
sudo -i
swapoff -a

# Включаем маршрутизацию
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# Устанавливаем Docker
apt-get update && apt-get install -y \
apt-transport-https ca-certificates curl software-properties-common gnupg2

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"

apt-get update && apt-get install -y \
containerd.io=1.2.13-1 \
docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)

# Настрока docker daemon.
cat > /etc/docker/daemon.json <<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

# Перезапуск docker.
systemctl daemon-reload
systemctl restart docker


# Устанавливаем kubeadm, kubelet and kubectl
apt-get update && apt-get install -y apt-transport-https curl

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet=1.17.4-00 kubeadm=1.17.4-00 kubectl=1.17.4-00

# Создаем кластер
kubeadm init --pod-network-cidr=192.168.0.0/24
# В выводе будут:
# команда для копирования конфига kubectl
# сообщение о том, что необходимо установить сетевой плагин
# команда для присоединения control-plane ноды
# команда для присоединения worker ноды

# Копируем конфиг kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Устанавливаем сетевой плагин
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Присоединяем остальные ноды
kubeadm join 10.166.0.23:6443 --token c0vuc8.j7sxcum8oi0ciyu5 \
    --discovery-token-ca-cert-hash sha256:5a54a19a34b5840cf9cd367b1e61eda35b847e235a0b9f47294d1bd7bfeaa925

# Выпоняем проверку
kubectl get nodes
NAME      STATUS   ROLES    AGE     VERSION
master1   Ready    master   2m46s   v1.17.4
node1     Ready    <none>   50s     v1.17.4
node2     Ready    <none>   39s     v1.17.4
node3     Ready    <none>   34s     v1.17.4

# Звпуск приложения и проверка
kubectl apply -f deployment.yaml
kkubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
nginx-deployment-c8fd555cc-c7shk   1/1     Running   0          4m38s
nginx-deployment-c8fd555cc-n7rwf   1/1     Running   0          4m38s
nginx-deployment-c8fd555cc-qcj86   1/1     Running   0          4m38s
nginx-deployment-c8fd555cc-zvl4j   1/1     Running   0          4m38s
```
- Выполнено обновление кластера до v 1.18
```bash
# Обновляем мастер-ноду
apt-get update && apt-get install -y kubeadm=1.18.0-00 \
kubelet=1.18.0-00 kubectl=1.18.0-00

# Проверка
k get nodes
NAME      STATUS   ROLES    AGE     VERSION
master1   Ready    master   10m     v1.18.0
node1     Ready    <none>   8m33s   v1.17.4
node2     Ready    <none>   8m22s   v1.17.4
node3     Ready    <none>   8m17s   v1.17.4

kubelet --version
Kubernetes v1.18.0
cat /etc/kubernetes/manifests/kube-apiserver.yaml
image: k8s.gcr.io/kube-apiserver:v1.17.9

# Планируем обновление остальных компонентов
kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.17.9
[upgrade/versions] kubeadm version: v1.18.0
[upgrade/versions] Latest stable version: v1.18.6
[upgrade/versions] Latest stable version: v1.18.6
[upgrade/versions] Latest version in the v1.17 series: v1.17.9
[upgrade/versions] Latest version in the v1.17 series: v1.17.9
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
Kubelet     3 x v1.17.4   v1.18.6
            1 x v1.18.0   v1.18.6
Upgrade to the latest stable version:
COMPONENT            CURRENT   AVAILABLE
API Server           v1.17.9   v1.18.6
Controller Manager   v1.17.9   v1.18.6
Scheduler            v1.17.9   v1.18.6
Kube Proxy           v1.17.9   v1.18.6
CoreDNS              1.6.5     1.6.7
Etcd                 3.4.3     3.4.3-0
You can now apply the upgrade by executing the following command:
	kubeadm upgrade apply v1.18.6
Note: Before you can perform this upgrade, you have to update kubeadm to v1.18.6.
____________________________________________________________________

# Выполняем обновление
kubeadm upgrade apply v1.18.0
---
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.18.0". Enjoy!
---

# Проверка
kubeadm version
  kubeadm version: &version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:56:30Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
kubelet --version
  Kubernetes v1.18.0
kubectl version
  Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:58:59Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
  Server Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:50:46Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
kubectl describe pod -n kube-system kube-apiserver-master1
  Name:                 kube-apiserver-master1
  Namespace:            kube-system
  Priority:             2000000000
  Priority Class Name:  system-cluster-critical
  Node:                 master1/10.166.0.23
  Start Time:           Wed, 12 Aug 2020 05:28:30 +0000
  Labels:               component=kube-apiserver
                        tier=control-plane
  Annotations:          kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 10.166.0.23:6443
                        kubernetes.io/config.hash: b605743da174bb8fd72ff85f7ff3ee24
                        kubernetes.io/config.mirror: b605743da174bb8fd72ff85f7ff3ee24
                        kubernetes.io/config.seen: 2020-08-12T05:42:59.552706251Z
                        kubernetes.io/config.source: file
  Status:               Running
  IP:                   10.166.0.23
  IPs:
    IP:           10.166.0.23
  Controlled By:  Node/master1
  Containers:
    kube-apiserver:
      Container ID:  docker://620c75017e404ede86de076d18162bcc28e63b2020535dd7d21163efa815e3b0
      Image:         k8s.gcr.io/kube-apiserver:v1.18.0
      Image ID:      docker-pullable://k8s.gcr.io/kube-apiserver@sha256:fc4efb55c2a7d4e7b9a858c67e24f00e739df4ef5082500c2b60ea0903f18248
      Port:          <none>
      Host Port:     <none>
      Command:
        kube-apiserver
        --advertise-address=10.166.0.23
        --allow-privileged=true
        --authorization-mode=Node,RBAC
        --client-ca-file=/etc/kubernetes/pki/ca.crt
        --enable-admission-plugins=NodeRestriction
        --enable-bootstrap-token-auth=true
        --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
        --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
        --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
        --etcd-servers=https://127.0.0.1:2379
        --insecure-port=0
        --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
        --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
        --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
        --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
        --requestheader-allowed-names=front-proxy-client
        --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
        --requestheader-extra-headers-prefix=X-Remote-Extra-
        --requestheader-group-headers=X-Remote-Group
        --requestheader-username-headers=X-Remote-User
        --secure-port=6443
        --service-account-key-file=/etc/kubernetes/pki/sa.pub
        --service-cluster-ip-range=10.96.0.0/12
        --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
        --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
      State:          Running
        Started:      Wed, 12 Aug 2020 05:43:00 +0000
      Ready:          True
      Restart Count:  0
      Requests:
        cpu:        250m
      Liveness:     http-get https://10.166.0.23:6443/healthz delay=15s timeout=15s period=10s #success=1 #failure=8
      Environment:  <none>
      Mounts:
        /etc/ca-certificates from etc-ca-certificates (ro)
        /etc/kubernetes/pki from k8s-certs (ro)
        /etc/ssl/certs from ca-certs (ro)
        /usr/local/share/ca-certificates from usr-local-share-ca-certificates (ro)
        /usr/share/ca-certificates from usr-share-ca-certificates (ro)
  Conditions:
    Type              Status
    Initialized       True
    Ready             True
    ContainersReady   True
    PodScheduled      True
  Volumes:
    ca-certs:
      Type:          HostPath (bare host directory volume)
      Path:          /etc/ssl/certs
      HostPathType:  DirectoryOrCreate
    etc-ca-certificates:
      Type:          HostPath (bare host directory volume)
      Path:          /etc/ca-certificates
      HostPathType:  DirectoryOrCreate
    k8s-certs:
      Type:          HostPath (bare host directory volume)
      Path:          /etc/kubernetes/pki
      HostPathType:  DirectoryOrCreate
    usr-local-share-ca-certificates:
      Type:          HostPath (bare host directory volume)
      Path:          /usr/local/share/ca-certificates
      HostPathType:  DirectoryOrCreate
    usr-share-ca-certificates:
      Type:          HostPath (bare host directory volume)
      Path:          /usr/share/ca-certificates
      HostPathType:  DirectoryOrCreate
  QoS Class:         Burstable
  Node-Selectors:    <none>
  Tolerations:       :NoExecute
  Events:
    Type    Reason   Age    From              Message
    ----    ------   ----   ----              -------
    Normal  Pulled   4m48s  kubelet, master1  Container image "k8s.gcr.io/kube-apiserver:v1.18.0" already present on machine
    Normal  Created  4m48s  kubelet, master1  Created container kube-apiserver
    Normal  Started  4m48s  kubelet, master1  Started container kube-apiserver

# Обновляем воркер-ноды
# Вывод ноды из шедулинга
k drain node1
  node/node1 cordoned
  error: unable to drain node "node1", aborting command...
  There are pending nodes to be drained:
  node1
  error: cannot delete DaemonSet-managed Pods (use --ignore-daemonsets to ignore): kube-system/calico-node-k7fvk, kube-system/kube-proxy-5nqg9

k drain node1 --ignore-daemonsets
  node/node1 already cordoned
  WARNING: ignoring DaemonSet-managed Pods: kube-system/calico-node-k7fvk, kube-system/kube-proxy-5nqg9
  evicting pod default/nginx-deployment-c8fd555cc-n7rwf
  evicting pod kube-system/coredns-66bff467f8-v8vr6
  pod/nginx-deployment-c8fd555cc-n7rwf evicted
  pod/coredns-66bff467f8-v8vr6 evicted
  node/node1 evicted

k get nodes
  NAME      STATUS                     ROLES    AGE   VERSION
  master1   Ready                      master   22m   v1.18.0
  node1     Ready,SchedulingDisabled   <none>   20m   v1.17.4
  node2     Ready                      <none>   20m   v1.17.4
  node3     Ready                      <none>   20m   v1.17.4

# Обновление компонентов
apt-get install -y kubelet=1.18.0-00 kubeadm=1.18.0-00
systemctl restart kubelet

# Возвращаем ноду
k uncordon node1
node/node1 uncordoned

# Проверка
k get nodes
NAME      STATUS   ROLES    AGE   VERSION
master1   Ready    master   23m   v1.18.0
node1     Ready    <none>   21m   v1.18.0
node2     Ready    <none>   21m   v1.17.4
node3     Ready    <none>   21m   v1.17.4

# Аналогично обновляем  остальные воркер-ноды
k drain node2 --ignore-daemonsets
  node/node2 cordoned
  WARNING: ignoring DaemonSet-managed Pods: kube-system/calico-node-96274, kube-system/kube-proxy-tjgzv
  evicting pod default/nginx-deployment-c8fd555cc-b2wj2
  evicting pod default/nginx-deployment-c8fd555cc-c7shk
  evicting pod default/nginx-deployment-c8fd555cc-zvl4j
  pod/nginx-deployment-c8fd555cc-b2wj2 evicted
  pod/nginx-deployment-c8fd555cc-zvl4j evicted
  pod/nginx-deployment-c8fd555cc-c7shk evicted
  node/node2 evicted
k drain node3 --ignore-daemonsets
  node/node3 cordoned
  WARNING: ignoring DaemonSet-managed Pods: kube-system/calico-node-pcj94, kube-system/kube-proxy-5x9lw
  evicting pod default/nginx-deployment-c8fd555cc-qcj86
  evicting pod kube-system/coredns-66bff467f8-mjkhw
  pod/nginx-deployment-c8fd555cc-qcj86 evicted
  pod/coredns-66bff467f8-mjkhw evicted
  node/node3 evicted

k get nodes
  NAME      STATUS                     ROLES    AGE   VERSION
  master1   Ready                      master   27m   v1.18.0
  node1     Ready                      <none>   25m   v1.18.0
  node2     Ready,SchedulingDisabled   <none>   24m   v1.18.0
  node3     Ready,SchedulingDisabled   <none>   24m   v1.18.0
k uncordon node2 node3
  node/node2 uncordoned
  node/node3 uncordoned
# Кластер обновлен
k get nodes
  NAME      STATUS   ROLES    AGE   VERSION
  master1   Ready    master   27m   v1.18.0
  node1     Ready    <none>   25m   v1.18.0
  node2     Ready    <none>   25m   v1.18.0
  node3     Ready    <none>   25m   v1.18.0
```

- Выполнено автоматическое развертывание HA k8s кластера через [kubespray](https://github.com/kubernetes-sigs/kubespray)  
Конфигурация кластера 6 ВМ GCP, ОС Ubuntu 18.04 LTS:
  - master - 3 экземпляра (n1-standard-2)
  - worker - 3 экземпляра (n1-standard-1)
```bash
# Копируем репозиторий kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
# Установка зависимостей
sudo pip install -r requirements.txt
# Копирование примера конфига в отдельную директорию и заполняем его
cp -rfp inventory/sample inventory/mycluster
```
Копия [инвентори](kubernetes-production-clusters/inventory.ini)
```yaml
# Указываем внешние и внутренние адреса нод и имена нод etc-кластера
[all]
master1 ansible_host=35.228.102.42  ip=10.166.0.27 etcd_member_name=etcd1
master2 ansible_host=35.228.137.20 ip=10.166.0.28 etcd_member_name=etcd2
master3 ansible_host=35.228.68.31  ip=10.166.0.29 etcd_member_name=etcd3
node1 ansible_host=35.228.231.39  ip=10.166.0.31
node2 ansible_host=35.228.130.28  ip=10.166.0.32
node3 ansible_host=35.228.53.215  ip=10.166.0.33

# ## configure a bastion host if your nodes are not directly reachable
# bastion ansible_host=x.x.x.x ansible_user=some_user
# Указываем мастер ноды
[kube-master]
master1
master2
master3
# Указываем на какие ноды устанавливать etcd
[etcd]
master1
master2
master3
# Указываем воркер ноды
[kube-node]
node1
node2
node3
# Выбор сетевого плагина
[calico-rr]

[k8s-cluster:children]
kube-master
kube-node
calico-rr

```
```bash
# Выполняем развертывание
ansible-playbook -i inventory/mycluster/inventory.ini --become --become-user=root \
--user=${SSH_USERNAME} --key-file=${SSH_PRIVATE_KEY} cluster.yml
.....

# Проверка
k get nodes -o wide
  NAME      STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
  master1   Ready    master   13m   v1.18.6   10.166.0.27   <none>        Ubuntu 18.04.5 LTS   5.3.0-1032-gcp   docker://19.3.12
  master2   Ready    master   12m   v1.18.6   10.166.0.28   <none>        Ubuntu 18.04.5 LTS   5.3.0-1032-gcp   docker://19.3.12
  master3   Ready    master   12m   v1.18.6   10.166.0.29   <none>        Ubuntu 18.04.5 LTS   5.3.0-1032-gcp   docker://19.3.12
  node1     Ready    <none>   10m   v1.18.6   10.166.0.31   <none>        Ubuntu 18.04.5 LTS   5.3.0-1032-gcp   docker://19.3.12
  node2     Ready    <none>   10m   v1.18.6   10.166.0.32   <none>        Ubuntu 18.04.5 LTS   5.3.0-1032-gcp   docker://19.3.12
  node3     Ready    <none>   10m   v1.18.6   10.166.0.33   <none>        Ubuntu 18.04.5 LTS   5.3.0-1032-gcp   docker://19.3.12
```

# HW.12 Kubernetes-storage
## В процессе сделано:
### Установлен CSI драйвер и протестирован функционал snapshot-ов:
- Развернут кластер kind
- Скачан репозиторий <https://github.com/kubernetes-csi/csi-driver-host-path/blob/master/docs/deploy-1.17-and-later.md>
- Установлены VolumeSnapshot CRD и Snapshot controller
Применяем CRD
```bash
export SNAPSHOTTER_VERSION=v2.0.1
# VolumeSnapshot CRD
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
# Snapshot controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$SNAPSHOTTER_VERSION/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```
- Установлен CSI драйвер
```bash
./csi-driver-host-path/deploy/kubernetes-1.18/deploy.sh
```
- Запущено приложение
```bash
k apply -f hw/
persistentvolumeclaim/storage-pvc created
storageclass.storage.k8s.io/csi-hostpath-sc created
pod/storage-pod created
```
Проверка:
```bash
k get sc
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
csi-hostpath-sc      hostpath.csi.k8s.io     Delete          Immediate              true                   2m20s
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  17m
k get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-9e185914-0fee-47f1-9754-0d8cc4d02afd   1Gi        RWO            csi-hostpath-sc   2m30s
k get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS      REASON   AGE
pvc-9e185914-0fee-47f1-9754-0d8cc4d02afd   1Gi        RWO            Delete           Bound    default/storage-pvc   csi-hostpath-sc            2m32s
k get volumeattachment
Name:         csi-6107d10e918b8c5a6918b3c6abc7ef75037833a34ecdd941f5b34c669e452a6a
Namespace:    
Labels:       <none>
Annotations:  <none>
API Version:  storage.k8s.io/v1
Kind:         VolumeAttachment
Metadata:
  Creation Timestamp:  2020-08-01T15:14:36Z
  Managed Fields:
    API Version:  storage.k8s.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        f:attached:
    Manager:      csi-attacher
    Operation:    Update
    Time:         2020-08-01T15:14:36Z
    API Version:  storage.k8s.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        f:attacher:
        f:nodeName:
        f:source:
          f:persistentVolumeName:
    Manager:         kube-controller-manager
    Operation:       Update
    Time:            2020-08-01T15:14:36Z
  Resource Version:  3438
  Self Link:         /apis/storage.k8s.io/v1/volumeattachments/csi-6107d10e918b8c5a6918b3c6abc7ef75037833a34ecdd941f5b34c669e452a6a
  UID:               9ac78d27-b0eb-48f3-97cf-bb1a27ab3cc9
Spec:
  Attacher:   hostpath.csi.k8s.io
  Node Name:  kind-worker2
  Source:
    Persistent Volume Name:  pvc-9e185914-0fee-47f1-9754-0d8cc4d02afd
Status:
  Attached:  true
Events:      <none>
```
- Созданы тестовые данные
```bash
k exec -ti storage-pod bash
root@storage-pod:/data# echo 'Hello world!' > index.htm
root@storage-pod:/data# ls -l
total 4
-rw-r--r-- 1 root root 13 Aug  1 15:23 index.htm
```
- Cоздан snapshot
```bash
# Создание
k apply -f hw/snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/snapshot created
# Проверка
k get volumesnapshot                     
NAME       AGE
snapshot   76s
k describe volumesnapshot snapshot 
Name:         snapshot
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration:
                {"apiVersion":"snapshot.storage.k8s.io/v1beta1","kind":"VolumeSnapshot","metadata":{"annotations":{},"name":"snapshot","namespace":"defaul..."}
API Version:  snapshot.storage.k8s.io/v1beta1
Kind:         VolumeSnapshot
Metadata:
  Creation Timestamp:  2020-08-01T15:31:22Z
  Finalizers:
    snapshot.storage.kubernetes.io/volumesnapshot-as-source-protection
    snapshot.storage.kubernetes.io/volumesnapshot-bound-protection
  Generation:  1
  Managed Fields:
    API Version:  snapshot.storage.k8s.io/v1beta1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        f:creationTime:
        f:readyToUse:
        f:restoreSize:
    Manager:         snapshot-controller
    Operation:       Update
    Time:            2020-08-01T15:32:17Z
  Resource Version:  6520
  Self Link:         /apis/snapshot.storage.k8s.io/v1beta1/namespaces/default/volumesnapshots/snapshot
  UID:               b1febce0-c9d5-44e8-b73c-fd565b52d60f
Spec:
  Source:
    Persistent Volume Claim Name:  storage-pvc
  Volume Snapshot Class Name:      csi-hostpath-snapclass
Status:
  Bound Volume Snapshot Content Name:  snapcontent-b1febce0-c9d5-44e8-b73c-fd565b52d60f
  Creation Time:                       2020-08-01T15:32:17Z
  Ready To Use:                        true
  Restore Size:                        1Gi
Events:                                <none>
#
k get volumesnapshotcontents.snapshot.storage.k8s.io 
NAME                                               AGE
snapcontent-b1febce0-c9d5-44e8-b73c-fd565b52d60f   3m20s
#
k describe volumesnapshotcontents.snapshot.storage.k8s.io snapcontent-b1febce0-c9d5-44e8-b73c-fd565b52d60f 
Name:         snapcontent-b1febce0-c9d5-44e8-b73c-fd565b52d60f
Namespace:    
Labels:       <none>
Annotations:  <none>
API Version:  snapshot.storage.k8s.io/v1beta1
Kind:         VolumeSnapshotContent
Metadata:
  Creation Timestamp:  2020-08-01T15:31:22Z
  Finalizers:
    snapshot.storage.kubernetes.io/volumesnapshotcontent-bound-protection
  Generation:  1
  Managed Fields:
    API Version:  snapshot.storage.k8s.io/v1beta1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:finalizers:
          .:
          v:"snapshot.storage.kubernetes.io/volumesnapshotcontent-bound-protection":
    Manager:      snapshot-controller
    Operation:    Update
    Time:         2020-08-01T15:31:22Z
    API Version:  snapshot.storage.k8s.io/v1beta1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:creationTime:
        f:readyToUse:
        f:restoreSize:
        f:snapshotHandle:
    Manager:         csi-snapshotter
    Operation:       Update
    Time:            2020-08-01T15:32:17Z
  Resource Version:  6519
  Self Link:         /apis/snapshot.storage.k8s.io/v1beta1/volumesnapshotcontents/snapcontent-b1febce0-c9d5-44e8-b73c-fd565b52d60f
  UID:               47c84825-e9ff-463f-8615-e6b2a5963c1f
Spec:
  Deletion Policy:  Delete
  Driver:           hostpath.csi.k8s.io
  Source:
    Volume Handle:             abcb70f1-d409-11ea-ae24-ba8e7e29a379
  Volume Snapshot Class Name:  csi-hostpath-snapclass
  Volume Snapshot Ref:
    API Version:       snapshot.storage.k8s.io/v1beta1
    Kind:              VolumeSnapshot
    Name:              snapshot
    Namespace:         default
    Resource Version:  6353
    UID:               b1febce0-c9d5-44e8-b73c-fd565b52d60f
Status:
  Creation Time:    1596295937585119467
  Ready To Use:     true
  Restore Size:     1073741824
  Snapshot Handle:  2eaa896a-d40c-11ea-ae24-ba8e7e29a379
Events:             <none>
# Snapshot на ноде
docker exec -ti kind-worker2 bash
root@kind-worker2:/# cd /var/lib/csi-hostpath-data/
root@kind-worker2:/var/lib/csi-hostpath-data# ll
total 12
drwxr-xr-x  2 root root 4096 Aug  1 15:37 ./
drwxr-xr-x 13 root root 4096 Aug  1 15:02 ../
-rw-r--r--  1 root root  146 Aug  1 15:32 2eaa896a-d40c-11ea-ae24-ba8e7e29a379.snap
```
- Удалим pod, pvc и pv
```bash
k delete pod storage-pod 
pod "storage-pod" deleted
k delete pvc storage-pvc                    
persistentvolumeclaim "storage-pvc" deleted
k get pv 
No resources found in default namespace.
k get pvc
No resources found in default namespace.
```
- Выполнено восстановление
```bash
# Восстановление
k apply -f hw/restore.yaml   
persistentvolumeclaim/storage-pvc created
k get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-5f7bf2af-50eb-4638-9d80-20dbad15344c   1Gi        RWO            csi-hostpath-sc   76s
k get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS      REASON   AGE
pvc-5f7bf2af-50eb-4638-9d80-20dbad15344c   1Gi        RWO            Delete           Bound    default/storage-pvc   csi-hostpath-sc            85s
# Проверка что данные на месте
k apply -f hw/pod.yaml
k exec storage-pod -- ls -l /data
total 4
-rw-r--r-- 1 root root 13 Aug  1 15:23 index.htm
```
### Развернут k8s-кластер с хранилищем на iSCSI, протестирована работа k8s с lvm snapshot:
- Развернут k8s кластер в GCP. 1 мастер нода, 1 воркер нода, 1 сервер хранения. Все сервера на Ubuntu. k8s развертывался через kubeadm.
```bash
# Установка docker, kubeadm, kubelet, kubectl
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
systemctl daemon-reload
systemctl restart kubelet
# Добавляем ip мастера в /etc/hosts, на мастере и на воркере
echo "10.166.0.19 dev.gcp" >> /etc/hosts
# Инициализация кластера
kubeadm init --control-plane-endpoint="dev.gcp:6443" --pod-network-cidr=10.244.0.0/16 --upload-certs --ignore-preflight-errors=NumCPU
kubeadm join dev.gcp:6443 --token veclc2.3917pyu06zfnkpce \
    --discovery-token-ca-cert-hash sha256:a39a3019f802845770744d0a227ac6dd924aae063bc3234c4b952be04af801b7
# Добавление воркера
kubeadm join dev.gcp:6443 --token veclc2.3917pyu06zfnkpce \
    --discovery-token-ca-cert-hash sha256:a39a3019f802845770744d0a227ac6dd924aae063bc3234c4b952be04af801b7
```
- Выполнена настройка iSCSI target
```bash
# Установка targetcli
apt -y install targetcli-fb

# Создание pv
pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
pvdisplay
  "/dev/sdb" is a new physical volume of "20.00 GiB"
  --- NEW Physical volume ---
  PV Name               /dev/sdb
  VG Name
  PV Size               20.00 GiB
  Allocatable           NO
  PE Size               0
  Total PE              0
  Free PE               0
  Allocated PE          0
  PV UUID               3WPgoN-rZUi-24My-COdg-7yFK-uDfQ-lZz2IT

# Создание vg
vgcreate vg-target /dev/sdb
  Volume group "vg-target" successfully created
vgdisplay
  --- Volume group ---
  VG Name               vg-target
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  1
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                0
  Open LV               0
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               <20.00 GiB
  PE Size               4.00 MiB
  Total PE              5119
  Alloc PE / Size       0 / 0
  Free  PE / Size       5119 / <20.00 GiB
  VG UUID               HaEksn-nPGZ-XjaI-o3gD-PwwA-UXHn-n10hOs

vgs
  VG        #PV #LV #SN Attr   VSize   VFree
  vg-target   1   0   0 wz--n- <20.00g <20.00g

# Создаем lv
lvcreate -L1024 -n lv01 vg-target
  Logical volume "lv01" created.
lvs
  LV   VG        Attr       LSize Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  lv01 vg-target -wi-a----- 1.00g

# Создание iscsi target 
targetcli
targetcli shell version 2.1.51
Copyright 2011-2013 by Datera, Inc and others.
For help on commands, type 'help'.

/> ls
o- / ......................................................................................................................... [...]
  o- backstores .............................................................................................................. [...]
  | o- block .................................................................................................. [Storage Objects: 0]
  | o- fileio ................................................................................................. [Storage Objects: 0]
  | o- pscsi .................................................................................................. [Storage Objects: 0]
  | o- ramdisk ................................................................................................ [Storage Objects: 0]
  o- iscsi ............................................................................................................ [Targets: 0]
  o- loopback ......................................................................................................... [Targets: 0]
  o- vhost ............................................................................................................ [Targets: 0]
  o- xen-pvscsi ....................................................................................................... [Targets: 0]
/> /backstores/block create storage1 /dev/vg-target/lv01
Created block storage object storage1 using /dev/vg-target/lv01.
/> iscsi/ create iqn.2020-08.gcp.com:dev-storage-iscsi
Created target iqn.2020-08.gcp.com:dev-storage-iscsi.
Created TPG 1.
Global pref auto_add_default_portal=true
Created default portal listening on all IPs (0.0.0.0), port 3260.
/> /iscsi/iqn.2020-08.gcp.com:dev-storage-iscsi/tpg1/luns/ create /backstores/block/storage1
Created LUN 0.
/> /iscsi/iqn.2020-08.gcp.com:dev-storage-iscsi/tpg1/acls create iqn.2020-08.gcp.com:worker
Created Node ACL for iqn.2020-08.gcp.com:worker
Created mapped LUN 0.
/> /iscsi/iqn.2020-08.gcp.com:dev-storage-iscsi/tpg1/ set parameter AuthMethod=None
Parameter AuthMethod is now 'None'.
/> /iscsi/iqn.2020-08.gcp.com:dev-storage-iscsi/tpg1/ set attribute authentication=0
Parameter authentication is now '0'.
/> ls
o- / ......................................................................................................................... [...]
  o- backstores .............................................................................................................. [...]
  | o- block .................................................................................................. [Storage Objects: 1]
  | | o- storage1 .............................................................. [/dev/vg-target/lv01 (1.0GiB) write-thru activated]
  | |   o- alua ................................................................................................... [ALUA Groups: 1]
  | |     o- default_tg_pt_gp ....................................................................... [ALUA state: Active/optimized]
  | o- fileio ................................................................................................. [Storage Objects: 0]
  | o- pscsi .................................................................................................. [Storage Objects: 0]
  | o- ramdisk ................................................................................................ [Storage Objects: 0]
  o- iscsi ............................................................................................................ [Targets: 1]
  | o- iqn.2020-08.gcp.com:dev-storage-iscsi ............................................................................. [TPGs: 1]
  |   o- tpg1 ............................................................................................... [no-gen-acls, no-auth]
  |     o- acls .......................................................................................................... [ACLs: 1]
  |     | o- iqn.2020-08.gcp.com:worker ........................................................................... [Mapped LUNs: 1]
  |     |   o- mapped_lun0 .............................................................................. [lun0 block/storage1 (rw)]
  |     o- luns .......................................................................................................... [LUNs: 1]
  |     | o- lun0 ........................................................ [block/storage1 (/dev/vg-target/lv01) (default_tg_pt_gp)]
  |     o- portals .................................................................................................... [Portals: 1]
  |       o- 0.0.0.0:3260 ..................................................................................................... [OK]
  o- loopback ......................................................................................................... [Targets: 0]
  o- vhost ............................................................................................................ [Targets: 0]
  o- xen-pvscsi ....................................................................................................... [Targets: 0]
/>
``` 
- Настроен iSCSI initiator
``` bash
# Установка iscsi клиента
apt install -y open-iscsi

# Редактируем /etc/iscsi/initiatorname.iscsi, добавляем InitiatorName=iqn.2020-08.gcp.com:worker
cat /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.2020-08.gcp.com:worker

# Перезапуск сервисов
systemctl restart iscsid open-iscsi

# Проверка доступности iscsi target
iscsiadm -m discovery -t sendtargets -p 10.166.0.21
10.166.0.21:3260,1 iqn.2020-08.gcp.com:dev-storage-iscsi
scsiadm -m node --login
Logging in to [iface: default, target: iqn.2020-08.gcp.com:dev-storage-iscsi, portal: 10.166.0.21,3260] (multiple)
Login to [iface: default, target: iqn.2020-08.gcp.com:dev-storage-iscsi, portal: 10.166.0.21,3260] successful.
```
- Выполнен запуск приложения
```bash
k apply -f kubernetes-storage/iscsi/
pod/iscsi-pv-pod created
persistentvolume/iscsi-pv created
persistentvolumeclaim/iscsi-pvc created
storageclass.storage.k8s.io/iscsi-targetd-vg-targetd created
```
- Созданы тестовые данные
```bash
k exec -it iscsi-pv-pod /bin/sh
/opt # ls -la
total 32
drwxr-xr-x    4 root     root          4096 Aug  9 07:11 .
drwxr-xr-x    1 root     root          4096 Aug  9 07:01 ..
drwx------    2 root     root         16384 Aug  9 07:01 lost+found
drwxr-xr-x    2 root     root          4096 Aug  9 07:06 test
-rw-r--r--    1 root     root             5 Aug  9 07:11 test.txt
```
- На сервере хранилища создан snapshot
```bash
lvcreate -L 500MB -s -n sn01 /dev/vg-target/lv01
  Logical volume "sn01" created.
```
- Удалены тестовые данные из пода
```bash
k exec -it iscsi-pv-pod /bin/sh
/opt # rm -rf test
/opt # rm test.txt 
/opt # ls -la
total 24
drwxr-xr-x    3 root     root          4096 Aug  9 07:15 .
drwxr-xr-x    1 root     root          4096 Aug  9 07:01 ..
drwx------    2 root     root         16384 Aug  9 07:01 lost+found
```
- Удалено приложение pv и pvc
```bash
k delete pod iscsi-pv-pod
pod "iscsi-pv-pod" deleted

k delete pvc iscsi-pvc
persistentvolumeclaim "iscsi-pvc" deleted

k delete pv iscsi-pv
persistentvolume "iscsi-pv" deleted
```
- Выполенно восстановление из snapshot
```bash
# Останавливаем сервис
systemctl stop target
# Выполняем восстановление
lvconvert --merge /dev/vg-targetd/sn01
  Merging of volume vg-targetd/sn01 started.
  vg-targetd/lv01: Merged: 100.00%
# Запускаем сервис
systemctl start target
```
- Выполенена проверка результатов восстановления
```bash
# Запуск приложения
k apply -f kubernetes-storage/iscsi/
pod/iscsi-pv-pod created
persistentvolume/iscsi-pv created
persistentvolumeclaim/iscsi-pvc created
storageclass.storage.k8s.io/iscsi-targetd-vg-targetd unchanged
# Проверка
k exec -ti iscsi-pv-pod sh
/opt # ls -la
total 32
drwxr-xr-x    4 root     root          4096 Aug  9 07:11 .
drwxr-xr-x    1 root     root          4096 Aug  9 07:58 ..
drwx------    2 root     root         16384 Aug  9 07:01 lost+found
drwxr-xr-x    2 root     root          4096 Aug  9 07:06 test
-rw-r--r--    1 root     root             5 Aug  9 07:11 test.txt
```

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
