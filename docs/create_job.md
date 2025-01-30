## Create job configuration

Fork the [test-infra](https://github.com/ppc64le-cloud/test-infra/) repo.

Write config in corresponding yaml file in [knative](https://github.com/ppc64le-cloud/test-infra/tree/master/config/jobs/periodic/knative) or [knative-extensions](https://github.com/ppc64le-cloud/test-infra/tree/master/config/jobs/periodic/knative-extensions) directory based on the knative component under test.

Refer PR [#486](https://github.com/ppc64le-cloud/test-infra/pull/486) for more details.

Add new configurations in corresponding yaml files in  `config/jobs/periodic/knative/`. 

Below configurations are for Operator main branch tests on power which are added to `config/jobs/periodic/knative/operator/main/operator-main.gen.yaml` file.
  ```bash
periodics:
  - name: knative-operator-main-periodic
    labels:
      preset-knative-powervs: "true"
    decorate: true
    cron: "20 0 * * *"
    extra_refs:
      - base_ref: main
        org: ppc64le-cloud
        repo: knative-tkn-upstream-ci
        workdir: true
      - base_ref: main
        org: knative
        repo: operator
    spec:
      containers:
        - image: quay.io/powercloud/knative-prow-tests:latest
          resources:
            requests:
              cpu: "1500m"
            limits:
              cpu: "1500m"
          command:
            - runner.sh
          args:
            - bash
            - -c
            - |
              set -o errexit
              set -o nounset
              set -o pipefail
              set -o xtrace

              TIMESTAMP=$(date +%s)
              K8S_BUILD_VERSION=$(curl https://storage.googleapis.com/k8s-release-dev/ci/latest.txt)

              kubetest2 tf --powervs-image-name CentOS9-Stream\
                --powervs-region syd --powervs-zone syd05 \
                --powervs-service-id af3e8574-29ea-41a2-a9c5-e88cba5c5858 \
                --powervs-ssh-key knative-ssh-key \
                --ssh-private-key ~/.ssh/ssh-key \
                --build-version $K8S_BUILD_VERSION \
                --cluster-name knative-$TIMESTAMP \
                --workers-count 2 \
                --up --auto-approve --retry-on-tf-failure 5 \
                --break-kubetest-on-upfail true \
                --powervs-memory 32

              export KUBECONFIG="$(pwd)/knative-$TIMESTAMP/kubeconfig"
              grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' $(pwd)/knative-$TIMESTAMP/hosts > HOSTS_IP
              source setup-environment.sh HOSTS_IP

              pushd $GOPATH/src/github.com/knative/operator
              . /tmp/adjust.sh
              ./test/e2e-tests.sh --run-tests
              popd

              kubetest2 tf --powervs-region syd --powervs-zone syd05 \
                --powervs-service-id af3e8574-29ea-41a2-a9c5-e88cba5c5858 \
                --ignore-cluster-dir true \
                --cluster-name knative-$TIMESTAMP \
                --down --auto-approve --ignore-destroy-errors
          env:
          - name: CI_JOB
            value: operator-main
  ```
  
  - In above config, 
  
  ```bash
  - name: CI_JOB
    value: "operator-main"
  ```
  will change based on component and version to be tested. `$CI_JOB` is used in `setup-environment.sh` script to fetch correct adjustment script.

## Modify the adjustment scripts

Refer [adjustment-scripts](https://github.com/ppc64le-cloud/knative-tkn-upstream-ci/blob/main/docs/adjustment-scripts.md) to make ppc64le specific changes for each component.

## Test your changes locally

Refer [test_job](https://github.com/ppc64le-cloud/knative-tkn-upstream-ci/blob/main/docs/testing.md) to test your changes locally.