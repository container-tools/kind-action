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

DEFAULT_KIND_VERSION=v0.17.0
DEFAULT_CLUSTER_NAME=kind
DEFAULT_KUBECTL_VERSION=v1.26.1

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help                              Display help
    -v, --version                           The kind version to use (default: $DEFAULT_KIND_VERSION)"
    -k, --kubectl-version                   The kubectl version to use (default: $DEFAULT_KUBECTL_VERSION)"
    -c, --config                            The path to the kind config file"
    -i, --node-image                        The Docker image for the cluster nodes"
    -n, --cluster-name                      The name of the cluster to create (default: $DEFAULT_CLUSTER_NAME)"
    -w, --wait                              The duration to wait for the control plane to become ready (default: 60s)"
    -l, --log-level                         The log level for kind [panic, fatal, error, warning, info, debug, trace] (default: warning)

EOF
}

main() {
    local version="$DEFAULT_KIND_VERSION"
    local kubectl_version="$DEFAULT_KUBECTL_VERSION"
    local config=
    local node_image=
    local cluster_name="$DEFAULT_CLUSTER_NAME"
    local wait=60s
    local log_level=

    parse_command_line "$@"

    install_kind
    install_kubectl
    install_docker
    create_kind_cluster

}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -k|--kubectl-version)
                if [[ -n "${2:-}" ]]; then
                    kubectl_version="$2"
                    shift
                else
                    echo "ERROR: '-k|--kubectl-version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -c|--config)
                if [[ -n "${2:-}" ]]; then
                    config="$2"
                    shift
                else
                    echo "ERROR: '--config' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -i|--node-image)
                if [[ -n "${2:-}" ]]; then
                    node_image="$2"
                    shift
                else
                    echo "ERROR: '-i|--node-image' cannot be empty." >&2
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
            -w|--wait)
                if [[ -n "${2:-}" ]]; then
                    wait="$2"
                    shift
                else
                    echo "ERROR: '--wait' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -l|--log-level)
                if [[ -n "${2:-}" ]]; then
                    log_level="$2"
                    shift
                else
                    echo "ERROR: '--log-level' cannot be empty." >&2
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

install_kind() {
    echo 'Installing kind...'
    if [ "$RUNNER_OS" == "macOS" ]; then
        # for Intel Macs
        [ $(uname -m) = x86_64 ] && curl -sSLo kind "https://kind.sigs.k8s.io/dl/$version/kind-darwin-amd64"
        # for M1 / ARM Macs
        [ $(uname -m) = arm64 ] && curl -sSLo kind "https://kind.sigs.k8s.io/dl/$version/kind-darwin-arm64"
    else
        curl -sSLo kind "https://github.com/kubernetes-sigs/kind/releases/download/$version/kind-linux-amd64"
    fi
    chmod +x kind
    sudo mv kind /usr/local/bin/kind
    kind version
}

install_kubectl() {
    echo 'Installing kubectl...'
    if [ "$RUNNER_OS" == "macOS" ]; then
        # for Intel Macs
        [ $(uname -m) = x86_64 ] && curl -sSLo kubectl "https://dl.k8s.io/release/$kubectl_version/bin/darwin/amd64/kubectl"
        # for M1 / ARM Macs
        [ $(uname -m) = arm64 ] && curl -sSLo kubectl "https://dl.k8s.io/release/$kubectl_version/bin/darwin/arm64/kubectl"
    else
        curl -sSLO "https://dl.k8s.io/release/$kubectl_version/bin/linux/amd64/kubectl"
    fi
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    kubectl version --client --output=yaml
}

install_docker() {
    if [ "$RUNNER_OS" == "macOS" ] && ! [ -x "$(command -v docker)" ]; then
        echo 'Installing docker...'
        brew install docker docker-buildx colima
        mkdir -p ~/.docker/cli-plugins
        ln -sfn /usr/local/opt/docker-buildx/bin/docker-buildx ~/.docker/cli-plugins/docker-buildx
        colima start
    fi
}

create_kind_cluster() {
    echo 'Creating kind cluster...'
    local args=(create cluster "--name=$cluster_name" "--wait=$wait")

    if [[ -n "$node_image" ]]; then
        args+=("--image=$node_image")
    fi

    if [[ -n "$config" ]]; then
        args+=("--config=$config")
    fi

    if [[ -n "$log_level" ]]; then
        args+=("--loglevel=$log_level")
    fi

    kind "${args[@]}"
}

main "$@"
