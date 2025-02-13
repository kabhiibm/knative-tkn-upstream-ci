set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

ORIGINAL_DIR=$(pwd)
trap 'pushd $ORIGINAL_DIR; source $(dirname $0)/cluster-setup.sh delete; popd' EXIT
source $(dirname $0)/cluster-setup.sh create

