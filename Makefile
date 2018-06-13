ISTIO=./istio-0.8.0
ISTIOCTL=$(ISTIO)/bin/istioctl
GATEWAY_URL ?= localhost

# step 1
# ======================
deploy-istio:
	kubectl apply -f $(ISTIO)/install/kubernetes/istio-demo.yaml

# step 2
# ======================
verify-istio:
	kubectl get svc -n istio-system
	kubectl get pods -n istio-system

# step 3
# ======================
# only does it for default namespace
# ensure this is done manually for any other namespace (substitute "default")
enable-istio-injection:
	kubectl label namespace default istio-injection=enabled

# step 4
# ======================
apply-bookinfo:
	kubectl apply -f $(ISTIO)/samples/bookinfo/kube/bookinfo.yaml

# step 5
# ======================
create-ingress:
	$(ISTIOCTL) create -f $(ISTIO)/samples/bookinfo/routing/bookinfo-gateway.yaml

# step 6
# ======================
verify-bookinfo:
	kubectl get svc
	kubectl get pod

# step 7
# ======================
get-ingressgateway:
	kubectl get svc istio-ingressgateway -n istio-system
	@printf "\nUse the information to set GATEWAY_URL (export GATEWAY_URL=host:port). If the port is 80, then leave it off.\n"
	@printf "For more details, see: https://istio.io/docs/tasks/traffic-management/ingress/#determining-the-ingress-ip-and-ports\n"

# step 8
# ======================
curl-bookinfo:
	curl -o /dev/null -sw "%{http_code}\n" http://${GATEWAY_URL}/productpage
	@printf "\nVisit the application and reload several times (shows all versions):\nhttp://${GATEWAY_URL}/productpage\n"

# step 9
# ======================
set-route-v1:
	$(ISTIOCTL) create -f $(ISTIO)/samples/bookinfo/routing/route-rule-all-v1.yaml
	@printf "\nVisit the application and reload several times (shows only v1 - no ratings):\nhttp://${GATEWAY_URL}/productpage\n"

# step 10
# ======================
set-route-v2-jason:
	$(ISTIOCTL) replace -f $(ISTIO)/samples/bookinfo/routing/route-rule-reviews-test-v2.yaml	
	@printf "\nVisit the application and log in as 'jason' (will now see v2 - ratings):\nhttp://${GATEWAY_URL}/productpage\n"

# step 11
# ======================
create-fault-injection-rule:
	$(ISTIOCTL) replace -f $(ISTIO)/samples/bookinfo/routing/route-rule-ratings-test-delay.yaml

# step 12
# ======================
confirm-fault-injection-rule:
	$(ISTIOCTL) get virtualservice ratings -o yaml
	@printf "\nVisit the application and log in as 'jason' (unexpected reviews not available due to delay handling mismatch bug):\nhttp://${GATEWAY_URL}/productpage\n"

# step 13
# ======================
reset-route-v1:
	$(ISTIOCTL) replace -f $(ISTIO)/samples/bookinfo/routing/route-rule-all-v1.yaml

# step 14
# ======================
shift-to-v3-50-percent:
	$(ISTIOCTL) replace -f $(ISTIO)/samples/bookinfo/routing/route-rule-reviews-50-v3.yaml
	@printf "\nVisit the application (approx 50%% of traffic v3 - red star ratings):\nhttp://${GATEWAY_URL}/productpage\n"

# step 15
# ======================
shift-to-v3-100-percent:
	$(ISTIOCTL) replace -f $(ISTIO)/samples/bookinfo/routing/route-rule-reviews-v3.yaml
	@printf "\nVisit the application (100%% of traffic v3 - red star ratings):\nhttp://${GATEWAY_URL}/productpage\n"

# step 16
# set up new telemetry
# ====================
# configure port forwarding for the prometheus dashboard (localhost:9090)
# configure port forwarding for the grafana dashboard (localhost:3000)
# send traffic to the mesh
create-new-telemetry:
	$(ISTIOCTL) create -f ./bookinfo_telemetry.yaml
	kubectl port-forward -n istio-system svc/prometheus 9090:9090 &
	kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &
	for i in {1..5}; do curl -so /dev/null http://${GATEWAY_URL}/productpage; done
	@printf "\n-> prometheus dashboard:  http://localhost:9090\n"
	@printf "\n-> grafana dashboard   :  http://localhost:3000\n"


# step 17
# install the service graph addon
# verify the service is running in the cluster
# send traffic to the mesh
# set up port forwarding
apply-servicegraph:
	kubectl -n istio-system get svc servicegraph
	kubectl -n istio-system port-forward svc/servicegraph 8088:8088 &
	for i in {1..5}; do curl -so /dev/null -w "." http://${GATEWAY_URL}/productpage; done
	@printf "\n-> service graph (d3):  http://localhost:8088/force/forcegraph.html\n"
	@printf "\n-> dotviz            :  http://localhost:8088/dotviz\n"


# step TBD
# set up a logging stack
# ======================
# configure istio to send logs to the logging stack
# send traffic to the mesh
create-logging-stack:
	kubectl apply -f logging-stack.yaml
	$(ISTIOCTL) create -f ./fluentd-istio.yaml
	for i in {1..5}; do curl -so /dev/null http://${GATEWAY_URL}/productpage; done

# step TBD
delete-logging-stack:
	-$(ISTIOCTL) delete -f ./fluentd-istio.yaml
	-kubectl delete -f ./logging-stack.yaml

delete-routing-rules:
	$(ISTIOCTL) delete -f $(ISTIO)/samples/bookinfo/routing/route-rule-all-v1.yaml

cleanup:
	-$(ISTIO)/samples/bookinfo/kube/cleanup.sh

delete-istio:
	-kubectl delete -f $(ISTIO)/install/kubernetes/istio-demo.yaml
