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

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help                              Display help
        --knative-serving                   The version of Knative Serving to use
        --knative-eventing                  The version of Knative Eventing to use
        --knative-kourier                   The version of Knative Net Kourier to use

EOF
}

main() {
    local serving_version=
    local eventing_version=
    local kourier_version=

    parse_command_line "$@"
    
    if [[ "$serving_version" != "" ]] || [[ "$eventing_version" != "" ]] || [[ "$kourier_version" != "" ]]
    then
        install_prerequisites
    fi

    if [[ "$serving_version" != "" ]]
    then
        install_serving
    fi
    
    if [[ "$kourier_version" != "" ]]
    then
        install_kourier
    fi

    if [[ "$eventing_version" != "" ]]
    then
        install_eventing
    fi
    
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            --knative-serving)
                if [[ -n "${2:-}" ]]; then
                    serving_version="$2"
                    shift
                else
                    echo "ERROR: '--serving-version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --knative-kourier)
                if [[ -n "${2:-}" ]]; then
                    kourier_version="$2"
                    shift
                else
                    echo "ERROR: '--kourier-version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --knative-eventing)
                if [[ -n "${2:-}" ]]; then
                    eventing_version="$2"
                    shift
                else
                    echo "ERROR: '--eventing-version' cannot be empty." >&2
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

install_prerequisites() {
    echo "Installing yq for patching Knative resources..."
    sudo pip install yq
}

install_serving() {
    # TODO find alternative to sleep
    echo "Installing Knative Serving $serving_version..."
    kubectl apply --filename https://github.com/knative/serving/releases/download/$serving_version/serving-crds.yaml
    echo "Waiting for resources to be initialized..."
    sleep 5
    curl -L -s https://github.com/knative/serving/releases/download/$serving_version/serving-core.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' -y | yq 'del(.metadata.annotations."knative.dev/example-checksum")' -y | kubectl apply -f -
    echo "Waiting for resources to be initialized..."
    sleep 60
    kubectl get pod -n knative-serving
}

install_kourier() {
    # TODO find alternative to sleep
    echo "Installing Knative Net Kourier $kourier_version..."
    kubectl apply --filename https://github.com/knative-sandbox/net-kourier/releases/download/$kourier_version/kourier.yaml
    kubectl patch configmap/config-network \
      --namespace knative-serving \
      --type merge \
      --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
    echo "Waiting for resources to be initialized..."
    sleep 30
    kubectl get pod -n kourier-system
}

install_eventing() {
    # TODO find alternative to sleep
    echo "Installing Knative Eventing $eventing_version..."
    kubectl apply --filename https://github.com/knative/eventing/releases/download/$eventing_version/eventing-crds.yaml
    echo "Waiting for resources to be initialized..."
    sleep 5
    curl -L -s https://github.com/knative/eventing/releases/download/$eventing_version/eventing-core.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' -y | yq 'del(.metadata.annotations."knative.dev/example-checksum")' -y | kubectl apply -f -
    # Eventing channels
    curl -L -s https://github.com/knative/eventing/releases/download/$eventing_version/in-memory-channel.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' -y | yq 'del(.metadata.annotations."knative.dev/example-checksum")' -y | kubectl apply -f -
    # Eventing broker
    curl -L -s https://github.com/knative/eventing/releases/download/$eventing_version/mt-channel-broker.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' -y | yq 'del(.metadata.annotations."knative.dev/example-checksum")' -y | kubectl apply -f -
    echo "Waiting for resources to be initialized..."
    sleep 30
    kubectl get pod -n knative-eventing
}

main "$@"
