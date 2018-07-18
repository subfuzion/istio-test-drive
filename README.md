# Istio Test Drive

## Overview

The [Istio docs](https://istio.io/docs/) provide comprehensive instructions for setting up Istio for a variety of environments. You will want to refer to them to understand the variety of configuration options and for more in depth explanations for the related topics. The following are concise notes based on my own experience running Istio using [Docker for Mac](https://www.docker.com/docker-mac) with [Kubernetes enabled](https://docs.docker.com/docker-for-mac/#kubernetes), and basically meant to be a guide for demo purposes. Others may find this streamlined format useful as well.

> Warning: the official docs for 0.8.0 and the latest 1.0.0 snapshot are not entirely up-to-date. In particular, there are a number of errors in the Telemetry section. The steps in this guide have been verified to work and there are a few updates to relevant manifests.

To keep this concise, the setup is based on installing Istio

* without using Helm
* without mutual TLS between sidecars
* with automatic sidecar injection

This is the Docker / Kubernetes version combination I tested with.

```sh
$ docker version
Client:
 Version:      18.05.0-ce
 API version:  1.37
 Go version:   go1.9.5
 Git commit:   f150324
 Built:        Wed May  9 22:12:05 2018
 OS/Arch:      darwin/amd64
 Experimental: true
 Orchestrator: kubernetes

Server:
 Engine:
  Version:      18.05.0-ce
  API version:  1.37 (minimum version 1.12)
  Go version:   go1.10.1
  Git commit:   f150324
  Built:        Wed May  9 22:20:16 2018
  OS/Arch:      linux/amd64
  Experimental: true
 Kubernetes:
  Version:     v1.10.3
  StackAPI:                   v1beta1


$ kubectl version --short
Client Version: v1.10.3
Server Version: v1.10.3
```

## Install Istio

Note: there are more options than described here. This is a simple set up on a local machine setup without TLS and without using Helm (and Tiller).
See [this page](https://istio.io/docs/setup/kubernetes/quick-start/) for more quick start options.

The following will download and unarchive the latest release version (`0.0.8`):

     curl -L https://git.io/getLatestIstio | sh -

If you prefer to download the latest pre-release version (`1.0.0`), you will need to get it from the [Istio releases](https://github.com/istio/istio/releases) page and unarchive it yourself.

Change directory to the new istio-&lt;VERSION&gt; directory just created:

    $ cd istio-0.8.0

Add the `istioctl` client to your path:

    $ export PATH=$PWD/bin:$PATH

 You probably also want to persist the path to your bash profile:

    $ echo "export PATH=$PWD/bin"':$PATH' >> ~/.bash_profile

Deploy the Istio components to your Kubernetes cluster:

     $ kubectl apply -f install/kubernetes/istio-demo.yaml

#### Verify

 Ensure the following services are deployed: istio-pilot, istio-ingressgateway, istio-policy, istio-telemetry, prometheus and istio-sidecar-injector.

```sh
$ kubectl get svc -n istio-system
NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                               AGE
grafana                    ClusterIP      10.97.214.229    <none>        3000/TCP                                                              1h
istio-citadel              ClusterIP      10.111.150.116   <none>        8060/TCP,9093/TCP                                                     1h
istio-egressgateway        ClusterIP      10.106.11.99     <none>        80/TCP,443/TCP                                                        1h
istio-ingressgateway       LoadBalancer   10.108.184.93    localhost     80:31380/TCP,443:31390/TCP,31400:31400/TCP                            1h
istio-pilot                ClusterIP      10.110.231.96    <none>        15003/TCP,15005/TCP,15007/TCP,15010/TCP,15011/TCP,8080/TCP,9093/TCP   1h
istio-policy               ClusterIP      10.101.18.237    <none>        9091/TCP,15004/TCP,9093/TCP                                           1h
istio-sidecar-injector     ClusterIP      10.97.69.159     <none>        443/TCP                                                               1h
istio-statsd-prom-bridge   ClusterIP      10.96.47.170     <none>        9102/TCP,9125/UDP                                                     1h
istio-telemetry            ClusterIP      10.100.122.119   <none>        9091/TCP,15004/TCP,9093/TCP,42422/TCP                                 1h
prometheus                 ClusterIP      10.105.153.109   <none>        9090/TCP                                                              1h
servicegraph               ClusterIP      10.101.133.48    <none>        8088/TCP                                                              1h
tracing                    LoadBalancer   10.96.154.77     <pending>     80:32365/TCP                                                          1h
zipkin                     ClusterIP      10.100.192.140   <none>        9411/TCP                                                              1h
```

Ensure all the pods are up and running (disregard the ones with "Completed" status):

```sh
$ kubectl get pods -n istio-system
NAME                                       READY     STATUS      RESTARTS   AGE
grafana-6f6dff9986-j4s7s                   1/1       Running     0          2h
istio-citadel-7bdc7775c7-v5lx9             1/1       Running     0          2h
istio-cleanup-old-ca-tqbpd                 0/1       Completed   0          2h
istio-egressgateway-795fc9b47-gbc44        1/1       Running     0          2h
istio-ingressgateway-7d89dbf85f-5l78j      1/1       Running     0          2h
istio-mixer-post-install-nl2c4             0/1       Completed   0          2h
istio-pilot-66f4dd866c-6lklx               2/2       Running     0          2h
istio-policy-76c8896799-v7r8q              2/2       Running     0          2h
istio-sidecar-injector-645c89bc64-ktf48    1/1       Running     0          2h
istio-statsd-prom-bridge-949999c4c-h5b66   1/1       Running     0          2h
istio-telemetry-6554768879-55v2l           2/2       Running     0          2h
istio-tracing-754cdfd695-lrgg7             1/1       Running     0          2h
prometheus-86cb6dd77c-4kwqj                1/1       Running     0          2h
servicegraph-5849b7d696-5ckvm              1/1       Running     0          2h
```

#### Label namespaces for automatic sidecar injection

Istio uses Envoy as a sidecar proxy for each pod; it can be automatically injected in pods running in namespaces that are labeled with `istio-injection=enabled`. Go ahead and do this for the `default` namespace and remember to do this as well for any other namespaces you create if you want automatic sidecar injection.

    $ kubectl label namespace default istio-injection=enabled

Note: If you choose not to enable automatic sidecar injection, then you will need to inject sidecars manually
for application containers. For the bookinfo sample below, you will need to start the application using
the following command instead of the one indicated in step 1:

    $ kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/kube/bookinfo.yaml)

#### Removing Istio components

The following will delete the `istio-system` namespace and resources under it (you can safely ignore errors for non-existent resources that may have already been deleted from the hierarchy).

    $ kubectl delete -f install/kubernetes/istio-demo.yaml

## bookinfo sample

In the following steps, `make` is used for convenience during demonstration, but the actual commands used are also displayed.

#### 1. Deploy the bookinfo services.

Note: if you did not enable automatic sidecar injection, then see the note in the section above
("Label namespaces for automatic sidecar injection") to start the application with manual sidecar
injection. Otherwise, perform the following:

```sh
$ make apply-bookinfo
kubectl apply -f ./istio-0.8.0/samples/bookinfo/kube/bookinfo.yaml
service "details" created
deployment.extensions "details-v1" created
service "ratings" created
deployment.extensions "ratings-v1" created
service "reviews" created
deployment.extensions "reviews-v1" created
deployment.extensions "reviews-v2" created
deployment.extensions "reviews-v3" created
service "productpage" created
deployment.extensions "productpage-v1" created
```

The manifest that was applied defines the following 4 services:
* productpage
* details
* ratings
* reviews

For each of these, there is a corresponding Service and Deployment configuration. For example,
`productpage` is configured as shown below:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: productpage
  labels:
    app: productpage
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: productpage
```

This defines a Service listening on port `9080` that will be associated with the pods identified
by `.spec.selector.app` as `productpage`. A Service is the abstraction used by Kubernetes to provide
an address (cluster IP) that will be used by service clients that is independent of the individual
addresses of pods comprising the service.

For each Service, there is a corresponding Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productpage-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productpage
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      containers:
      - name: productpage
        image: istio/examples-bookinfo-productpage-v1:1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
```

In a nutshell, this Deployment spec defines a desired state, 
`.spec.selector.matchLabels.app` configures the deployment controller to only target
pods identified by the matching label to achieve and maintain the desired state. In this
case, the desired state is a single replica of a pod specified by the pod creation spec
in `.spec.template.spec`, which, among other things, identifies the image to use and the
port to open for use by the pod.

#### 2. Confirm the services and pods are correctly defined and running.

```sh
$ make verify-bookinfo
kubectl get svc
NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
details       ClusterIP   10.104.172.103   <none>        9080/TCP   6m
kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP    19h
productpage   ClusterIP   10.105.119.231   <none>        9080/TCP   6m
ratings       ClusterIP   10.107.237.200   <none>        9080/TCP   6m
reviews       ClusterIP   10.103.237.115   <none>        9080/TCP   6m
kubectl get pod
NAME                              READY     STATUS    RESTARTS   AGE
details-v1-7b97668445-n8scf       2/2       Running   0          6m
productpage-v1-7bbdd59459-jjzwz   2/2       Running   0          6m
ratings-v1-76dc7f6b9-lqwtr        2/2       Running   0          6m
reviews-v1-64545d97b4-bmvjj       2/2       Running   0          6m
reviews-v2-8cb9489c6-qm8jh        2/2       Running   0          6m
reviews-v3-6bc884b456-nt57h       2/2       Running   0          6m
```

Note that each pod shows 2/2 containers running because each also has a proxy running in it
as a container sidecar.

#### 3. Define an ingress gateway to the productpage service for the bookinfo application.

```sh
$ make create-ingress
./istio-0.8.0/bin/istioctl create -f ./istio-0.8.0/samples/bookinfo/routing/bookinfo-gateway.yaml
Created config gateway/default/bookinfo-gateway at revision 83509
Created config virtual-service/default/bookinfo at revision 83510
```

#### 4. Determine the ingress IP and port.

```sh
$ make get-ingressgateway
kubectl get svc istio-ingressgateway -n istio-system
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.103.53.179   localhost     80:31380/TCP,443:31390/TCP,31400:31400/TCP   29m

#### 5. Set `GATEWAY_URL`. For example, using the information displayed above:

Using `EXTERNAL-IP` and the appropriate `PORT` printed in the previous step, set an environment variable
called `GATEWAY_URL` as follows (if the port is 80, then leave it off). For more details, see: https://istio.io/docs/tasks/traffic-management/ingress/#determining-the-ingress-ip-and-ports
```

```sh
export GATEWAY_URL=localhost
```

#### 6. Get the bookinfo application productpage using `curl` and print the HTTP response status code:

```sh
$ make curl-bookinfo
curl -o /dev/null -sw "%{http_code}\n" http://localhost/productpage
200

Repeat this command or browse to the bookinfo productpage and reload several times (should cycle through 3 different versions):
http://localhost/productpage
```

#### 7. Browse to the productpage

Use the URL printed at the end of the previous step to open the productpage in a browser.
The URL uses the host:port values previously set for `$GATEWAY_URL`. For example:

http://localhost/productpage

#### 8. Set routing for v1 only

```sh
$ make set-route-v1
./istio-0.8.0/bin/istioctl create -f ./istio-0.8.0/samples/bookinfo/routing/route-rule-all-v1.yaml
Created config virtual-service/default/productpage at revision 88216
Created config virtual-service/default/reviews at revision 88217
Created config virtual-service/default/ratings at revision 88218
Created config virtual-service/default/details at revision 88219
Created config destination-rule/default/productpage at revision 88220
Created config destination-rule/default/reviews at revision 88221
Created config destination-rule/default/ratings at revision 88222
Created config destination-rule/default/details at revision 88223

Visit the application and reload several times (shows only v1 - no ratings):
http://localhost/productpage
```

The `route-rule-all-v1.yaml` manifest defines the following for each service:
* VirtualService
* DestinationRule

Using `reviews` as an example, this is how the VirtualService is defined:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
```

And this is how the DestinationRule is defined. Note that `reviews` defines 3 different subsets
for each different version of the service:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
```

#### 9. Set routing to v2 for user "jason"

```sh
$ make set-route-v2-jason
./istio-0.8.0/bin/istioctl replace -f ./istio-0.8.0/samples/bookinfo/routing/route-rule-reviews-test-v2.yaml
Updated config virtual-service/default/reviews to revision 91198

Visit the application and log in as 'jason' (will now see v2 - ratings):
http://localhost/productpage
```

This step updates the routing rule for the `reviews` VirtualService using `istioctl update` to apply the following:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - match:
    - headers:
        cookie:
          regex: "^(.*?;)?(user=jason)(;.*)?$"
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

#### 10. Create fault injection rule using HTTP delay

```sh
$ make create-fault-injection-rule
./istio-0.8.0/bin/istioctl replace -f ./istio-0.8.0/samples/bookinfo/routing/route-rule-ratings-test-delay.yaml
Updated config virtual-service/default/ratings to revision 93223
```

#### 11. Confirm fault injection

Introducing an HTTP delay causes an unexpected error due to a bug: there is a mismatch between configured delay timeout tolerances between the `productpage` and the `reviews` services vs. the `reviews` and `ratings` services.

```sh
$ make confirm-fault-injection-rule
./istio-0.8.0/bin/istioctl get virtualservice ratings -o yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  creationTimestamp: null
  name: ratings
  namespace: default
  resourceVersion: "93223"
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        fixedDelay: 7.000s
        percent: 100
    match:
    - headers:
        cookie:
          regex: ^(.*?;)?(user=jason)(;.*)?$
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
---

Visit the application and log in as 'jason' (unexpected reviews not available due to delay handling mismatch bug):
http://localhost/productpage
```

#### 12. Reset default version to v1

```sh
$ make reset-route-v1
./istio-0.8.0/bin/istioctl replace -f ./istio-0.8.0/samples/bookinfo/routing/route-rule-all-v1.yaml
Updated config virtual-service/default/productpage to revision 88216
Updated config virtual-service/default/reviews to revision 95828
Updated config virtual-service/default/ratings to revision 95829
Updated config virtual-service/default/details to revision 88219
Updated config destination-rule/default/productpage to revision 88220
Updated config destination-rule/default/reviews to revision 88221
Updated config destination-rule/default/ratings to revision 88222
Updated config destination-rule/default/details to revision 88223
```

#### 13. Shift 50% of traffic to v3

```sh
$ make shift-to-v3-50-percent
./istio-0.8.0/bin/istioctl replace -f ./istio-0.8.0/samples/bookinfo/routing/route-rule-reviews-50-v3.yaml
Updated config virtual-service/default/reviews to revision 96211

Visit the application (approx 50% of traffic v3 - red star ratings):
http://localhost/productpage
```

#### 14. Shift 100% of traffic to v3

```sh
$ make shift-to-v3-100-percent
./istio-0.8.0/bin/istioctl replace -f ./istio-0.8.0/samples/bookinfo/routing/route-rule-reviews-v3.yaml
Updated config virtual-service/default/reviews to revision 96562

Visit the application (100% of traffic v3 - red star ratings):
http://localhost/productpage
```

## Telemetry

#### Distributed tracing

Access the tracing dashboard using port-forwarding. The tracing pod in the `istio-system` namespace is labeled `app=jaeger` (based on the `jaegertracing/all-in-one:1.5` image).

```sh
$ kubectl port-forward -n istio-system svc/tracing 32687:80
Forwarding from 127.0.0.1:32687 -> 16686
Forwarding from [::1]:32687 -> 16686
```

Select the **productpage** service from the dropdown menu and click the **Find Traces** button.

Reload the page at http://$GATEWAY_URL/productpage several times.

Select the most recent trace at the top of the tracing dashboard. You should be able to view the trace comprised of spans, where each span corresponds to a `bookinfo` service invoked during the execution of a `/productpage` request.

While Istio proxies automatically send the spans, application services must participate by forwarding the following HTTP headers:

* x-request-id
* x-b3-traceid
* x-b3-spanid
* x-b3-parentspanid
* x-b3-sampled
* x-b3-flags
* x-ot-span-context

See [Distributed Tracing](https://istio.io/docs/tasks/telemetry/distributed-tracing/).

#### Metrics and logs

```sh
$ make create-new-telemetry
./istio-0.8.0/bin/istioctl create -f ./bookinfo_telemetry.yaml
Created config metric/istio-system/doublerequestcount at revision 99701
Created config prometheus/istio-system/doublehandler at revision 99702
Created config rule/istio-system/doubleprom at revision 99703
Created config logentry/istio-system/newlog at revision 99704
Created config stdio/istio-system/newhandler at revision 99705
Created config rule/istio-system/newlogstdio at revision 99706
```

Reload the page at http://$GATEWAY_URL/productpage several times.

Set up port forwarding for the Prometheus service:

```sh
$ kubectl port-forward -n istio-system svc/prometheus 9090:9090
Forwarding from 127.0.0.1:9090 -> 9090
Forwarding from [::1]:9090 -> 9090
```

Open the Prometheus console at:
http://localhost:9090/graph#%5B%7B%22range_input%22%3A%221h%22%2C%22expr%22%3A%22istio_double_request_count%22%2C%22tab%22%3A1%7D%5D

Use `kubectl` to verify logging:

```sh
kubectl -n istio-system logs $(kubectl -n istio-system get pods -l istio-mixer-type=telemetry -o jsonpath='{.items[0].metadata.name}') mixer | grep \"instance\":\"newlog.logentry.istio-system\"
```

See [Querying Metrics and Logs](https://istio.io/docs/tasks/telemetry/metrics-logs/)

#### Better logging with Fluentd

The following example collects service logs using Fluentd and uses Elasticsearch as the logging backend and Kibana as the log viewer.

See: [Logging with Fluentd](https://istio.io/docs/tasks/telemetry/fluentd/)

#### Viewing a service graph

Set port forwarding for the servicegraph pod.

```sh
kubectl -n istio-system port-forward svc/servicegraph 8088:8088
```

http://localhost:8088/force/forcegraph.html

Visit the following endpoints:

* `/force/forcegraph.html` As explored above, this is an interactive D3.js visualization.
* `/dotviz` is a static Graphviz visualization.
* `/dotgraph` provides a DOT serialization.
* `/d3graph` provides a JSON serialization for D3 visualization.
* `/graph` provides a generic JSON serialization.
