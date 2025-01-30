sed -i "/^source.*/a export USER=$\(whoami\)" test/e2e-tests.sh
sed -i "/^initialize.*/a sleep 60" test/e2e-tests.sh
sed -i "/^sleep.*/a kubectl set image deployment/3scale-kourier-gateway kourier-gateway=icr.io/upstream-k8s-registry/knative/maistra/envoy:v2.4 -n kourier-system" test/e2e-tests.sh
sed -i 's|gcr.io/knative-samples/helloworld-go|quay.io/openshift-knative/client/helloworld:v1.9|g' pkg/k8s/test/addressresolver_cases.go
sed -i "/^success.*/i .\/destroy.sh $1" test/e2e-tests.sh
kubectl get cm vcm-script -n default -o jsonpath='{.data.script}' > destroy.sh && chmod +x destroy.sh
