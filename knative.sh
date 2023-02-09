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
    if [ "$RUNNER_OS" == "macOS" ]; then
         brew install yq
    else
        wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
        chmod +x /usr/local/bin/yq
    fi
    yq --version
}

install_serving() {
    # TODO find alternative to sleep
    echo "Installing Knative Serving $serving_version..."
    base=https://github.com/knative/serving/releases/download/$serving_version
    if [[ $serving_version = v1* ]]; then
        base=https://github.com/knative/serving/releases/download/knative-$serving_version
    fi
    kubectl apply --filename $base/serving-crds.yaml
    echo "Waiting for resources to be initialized..."
    sleep 5
    curl -L -s $base/serving-core.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' | yq 'del(.metadata.annotations."knative.dev/example-checksum")' | kubectl apply -f -
    echo "Waiting for resources to be initialized..."
    sleep 60
    kubectl get pod -n knative-serving
}

install_kourier() {
    # TODO find alternative to sleep
    echo "Installing Knative Net Kourier $kourier_version..."
    base=https://github.com/knative-sandbox/net-kourier/releases/download/$kourier_version
    if [[ $serving_version = v1* ]]; then
        base=https://github.com/knative-sandbox/net-kourier/releases/download/knative-$kourier_version
    fi
    kubectl apply --filename $base/kourier.yaml
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
    base=https://github.com/knative/eventing/releases/download/$eventing_version
    if [[ $serving_version = v1* ]]; then
        base=https://github.com/knative/eventing/releases/download/knative-$eventing_version
    fi
    kubectl apply --filename $base/eventing-crds.yaml
    echo "Waiting for resources to be initialized..."
    sleep 5
    curl -L -s $base/eventing-core.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' | yq 'del(.metadata.annotations."knative.dev/example-checksum")' | kubectl apply -f -
    # Eventing channels
    set +e
    curl -L -s $base/in-memory-channel.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' | yq 'del(.metadata.annotations."knative.dev/example-checksum")' | kubectl apply -f -
    if [ $? -ne 0 ]; then
        set -e
        curl -L -s $base/in-memory-channel.yaml | kubectl apply -f -
    fi
    set -e
    # Eventing broker
    curl -L -s $base/mt-channel-broker.yaml | yq 'del(.spec.template.spec.containers[]?.resources)' | yq 'del(.metadata.annotations."knative.dev/example-checksum")' | kubectl apply -f -
    echo "Waiting for resources to be initialized..."
    sleep 30
    kubectl get pod -n knative-eventing
}

main "$@"
