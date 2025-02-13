set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

CLUSTER_NAME=knative-$(date +%s)
ORIGINAL_DIR=$(pwd)
trap 'pushd $ORIGINAL_DIR; source $(dirname $0)/cluster-setup.sh delete $CLUSTER_NAME; popd' EXIT
source $(dirname $0)/cluster-setup.sh create $CLUSTER_NAME

