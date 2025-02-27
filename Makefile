# Copyright 2020 The OpenYurt Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

TARGET_PLATFORMS ?= linux/amd64
IMAGE_REPO ?= openyurt
IMAGE_TAG ?= $(shell git describe --abbrev=0 --tags)
GIT_COMMIT = $(shell git rev-parse HEAD)

ifeq ($(shell git tag --points-at ${GIT_COMMIT}),)
GIT_VERSION=$(IMAGE_TAG)-$(shell echo ${GIT_COMMIT} | cut -c 1-7)
else
GIT_VERSION=$(IMAGE_TAG)
endif

DOCKER_BUILD_ARGS = --build-arg GIT_VERSION=${GIT_VERSION}

ifeq (${REGION}, cn)
DOCKER_BUILD_ARGS += --build-arg GOPROXY=https://goproxy.cn --build-arg MIRROR_REPO=mirrors.aliyun.com
endif

.PHONY: clean all build

all: test build

# Build binaries in the host environment
build:
	bash hack/make-rules/build.sh $(WHAT)

# generate yaml files
gen-yaml:
	hack/make-rules/genyaml.sh $(WHAT)

# Run test
test: fmt vet
	go test -v -short ./pkg/... ./cmd/... -coverprofile cover.out
	go test -v  -coverpkg=./pkg/yurttunnel/...  -coverprofile=yurttunnel-cover.out ./test/integration/yurttunnel_test.go

# Run go fmt against code
fmt:
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

clean:
	-rm -Rf _output

# Start up OpenYurt cluster on local machine based on a Kind cluster
# And you can run the following command on different env by specify TARGET_PLATFORMS, default platform is linux/amd64
#   - on centos env: make local-up-openyurt
#   - on MACBook Pro M1: make local-up-openyurt TARGET_PLATFORMS=linux/arm64
local-up-openyurt:
	YURT_VERSION=$(GIT_VERSION) bash hack/make-rules/local-up-openyurt.sh

# Build all OpenYurt components images and then start up OpenYurt cluster on local machine based on a Kind cluster
# And you can run the following command on different env by specify TARGET_PLATFORMS, default platform is linux/amd64
#   - on centos env: make docker-build-and-up-openyurt
#   - on MACBook Pro M1: make docker-build-and-up-openyurt TARGET_PLATFORMS=linux/arm64
docker-build-and-up-openyurt: docker-build
	YURT_VERSION=$(GIT_VERSION) bash hack/make-rules/local-up-openyurt.sh

e2e-tests:
	bash hack/make-rules/run-e2e-tests.sh

install-golint: ## check golint if not exist install golint tools
ifeq (, $(shell which golangci-lint))
	@{ \
	set -e ;\
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.31.0 ;\
	}
GOLINT_BIN=$(shell go env GOPATH)/bin/golangci-lint
else
GOLINT_BIN=$(shell which golangci-lint)
endif

lint: install-golint ## Run go lint against code.
	$(GOLINT_BIN) run -v

# Build the docker images only one arch(specify arch by TARGET_PLATFORMS env)
#     - build linux/amd64 docker images:
#       $# make docker-build TARGET_PLATFORMS=linux/amd64
#     - build linux/arm64 docker images:
#       $# make docker-build TARGET_PLATFORMS=linux/arm64
docker-build: docker-build-yurthub docker-build-yurt-controller-manager docker-build-yurt-tunnel-server docker-build-yurt-tunnel-agent docker-build-node-servant

docker-build-yurthub:
	docker buildx build --no-cache --load ${DOCKER_BUILD_ARGS} --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurthub . -t ${IMAGE_REPO}/yurthub:${GIT_VERSION}

docker-build-yurt-controller-manager:
	docker buildx build --no-cache --load ${DOCKER_BUILD_ARGS} --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-controller-manager . -t ${IMAGE_REPO}/yurt-controller-manager:${GIT_VERSION}

docker-build-yurt-tunnel-server:
	docker buildx build --no-cache --load ${DOCKER_BUILD_ARGS} --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-tunnel-server . -t ${IMAGE_REPO}/yurt-tunnel-server:${GIT_VERSION}

docker-build-yurt-tunnel-agent:
	docker buildx build --no-cache --load ${DOCKER_BUILD_ARGS} --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-tunnel-agent . -t ${IMAGE_REPO}/yurt-tunnel-agent:${GIT_VERSION}

docker-build-node-servant:
	docker buildx build --no-cache --load ${DOCKER_BUILD_ARGS} --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-node-servant . -t ${IMAGE_REPO}/node-servant:${GIT_VERSION}

# Build and Push the docker images with multi-arch
docker-push: docker-push-yurthub docker-push-yurt-controller-manager docker-push-yurt-tunnel-server docker-push-yurt-tunnel-agent docker-push-node-servant

docker-push-yurthub:
	docker buildx build --no-cache --push ${DOCKER_BUILD_ARGS}  --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurthub . -t ${IMAGE_REPO}/yurthub:${GIT_VERSION}

docker-push-yurt-controller-manager:
	docker buildx build --no-cache --push ${DOCKER_BUILD_ARGS}  --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-controller-manager . -t ${IMAGE_REPO}/yurt-controller-manager:${GIT_VERSION}

docker-push-yurt-tunnel-server:
	docker buildx build --no-cache --push ${DOCKER_BUILD_ARGS}  --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-tunnel-server . -t ${IMAGE_REPO}/yurt-tunnel-server:${GIT_VERSION}

docker-push-yurt-tunnel-agent:
	docker buildx build --no-cache --push ${DOCKER_BUILD_ARGS}  --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-tunnel-agent . -t ${IMAGE_REPO}/yurt-tunnel-agent:${GIT_VERSION}

docker-push-node-servant:
	docker buildx build --no-cache --push ${DOCKER_BUILD_ARGS}  --platform ${TARGET_PLATFORMS} -f hack/dockerfiles/Dockerfile.yurt-node-servant . -t ${IMAGE_REPO}/node-servant:${GIT_VERSION}
