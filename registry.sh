#!/usr/bin/env bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

DEFAULT_REGISTRY_IMAGE=registry:2
DEFAULT_REGISTRY_NAME=kind-registry
DEFAULT_REGISTRY_PORT=5000
DEFAULT_CLUSTER_NAME=kind

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help                              Display help
        --registry-image                    The registry image to use (default: registry:2)
        --registry-name                     The registry name to use
        --registry-port                     The local port used to bind the registry
        -n, --cluster-name                  The name of the cluster to create (default: $DEFAULT_CLUSTER_NAME)"
        --document                          Document the local registry

EOF
}

main() {
    local registry_image="$DEFAULT_REGISTRY_IMAGE"
    local registry_name="$DEFAULT_REGISTRY_NAME"
    local registry_port="$DEFAULT_REGISTRY_PORT"
    local cluster_name="$DEFAULT_CLUSTER_NAME"
    local document=false

    parse_command_line "$@"
    
    if [[ "$document" = "false" ]]
    then
        create_registry
        connect_registry
        create_kind_config
    else
        document
    fi

}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            --registry-image)
                if [[ -n "${2:-}" ]]; then
                    registry_image="$2"
                    shift
                else
                    echo "ERROR: '--registry-image' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --registry-name)
                if [[ -n "${2:-}" ]]; then
                    registry_name="$2"
                    shift
                else
                    echo "ERROR: '--registry-name' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --registry-port)
                if [[ -n "${2:-}" ]]; then
                    registry_port="$2"
                    shift
                else
                    echo "ERROR: '--registry-port' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -n|--cluster-name)
                if [[ -n "${2:-}" ]]; then
                    cluster_name="$2"
                    shift
                else
                    echo "ERROR: '-n|--cluster-name' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --document)
                if [[ -n "${2:-}" ]]; then
                    document="$2"
                    shift
                else
                    echo "ERROR: '--document' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac

        shift
    done
}

create_registry() {
    echo "Creating registry \"$registry_name\" on port $registry_port from image \"$registry_image\"..."
    if [ "$RUNNER_OS" == "macOS" ] && ! [ -x "$(command -v docker)" ]; then
         brew install docker colima
         colima start
    fi
    docker run -d --restart=always -p "${registry_port}:5000" --name "${registry_name}" $registry_image > /dev/null
    
    # Adding registry to /etc/hosts
    sudo -- bash -c 'echo "127.0.0.1 $registry_name" >> /etc/hosts'

    # Exporting the registry location for subsequent jobs
    echo "KIND_REGISTRY=${registry_name}:${registry_port}" >> $GITHUB_ENV
}

connect_registry() {
    echo 'Connecting registry to the "kind" network...'
    docker network create kind
    docker network connect "kind" "${registry_name}"
}

create_kind_config() {
    sudo mkdir -p /etc/kind-registry
    cat <<EOF | sudo dd status=none of=/etc/kind-registry/config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${registry_name}:${registry_port}"]
    endpoint = ["http://${registry_name}:${registry_port}"]
EOF
    sudo chmod a+r /etc/kind-registry/config.yaml
}

document() {
    # Document the local registry
    # https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "${registry_name}:${registry_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

main "$@"
