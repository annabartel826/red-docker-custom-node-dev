#!/bin/bash

set -o errexit

main() {
    case $1 in
        "prepare")
            docker_prepare
            ;;
        "build")
            docker_build
            ;;
        "test")
            docker_test
            ;;
        "tag")
            docker_tag
            ;;
        "push")
            docker_push
            ;;
        "manifest-list")
            docker_manifest_list
            ;;
        *)
            echo "none of above!"
    esac
}

docker_prepare() {
    # Prepare the machine before any code installation scripts
    setup_dependencies

    # Update docker configuration to enable docker manifest command
    update_docker_configuration

    # Prepare qemu to build images other then x86_64 on travis
    prepare_qemu
}

docker_build() {
  # Build Docker image
  echo "DOCKER BUILD: Build Docker image."
  echo "DOCKER BUILD: build version -> ${BUILD_VERSION}."
  echo "DOCKER BUILD: build from -> ${BUILD_FROM}."
  echo "DOCKER BUILD: node version -> ${NODE_VERSION}."
  echo "DOCKER BUILD: os -> ${OS}."
  echo "DOCKER BUILD: node-red version -> ${NODE_RED_VERSION}."
  echo "DOCKER BUILD: arch - ${ARCH}."
  echo "DOCKER BUILD: qemu arch - ${QEMU_ARCH}."
  echo "DOCKER BUILD: docker file - ${DOCKER_FILE}."

  docker build --no-cache --build-arg BUILD_FROM=${BUILD_FROM} --build-arg NODE_VERSION=${NODE_VERSION} --build-arg OS=${OS} --build-arg NODE_RED_VERSION=v${NODE_RED_VERSION} --build-arg ARCH=${ARCH} --build-arg QEMU_ARCH=${QEMU_ARCH} --file ./.docker/${DOCKER_FILE} --tag ${TARGET}:build-${NODE_VERSION}-${OS}-${ARCH} .
}

docker_test() {
  echo "DOCKER TEST: Test Docker image."
  echo "DOCKER TEST: testing image -> ${TARGET}:build-${NODE_VERSION}-${OS}-${ARCH}."

  docker run -d --rm --name=test-${NODE_VERSION}-${ARCH} ${TARGET}:build-${NODE_VERSION}-${OS}-${ARCH}
  if [ $? -ne 0 ]; then
     echo "DOCKER TEST: FAILED - Docker container test-${NODE_VERSION}-${OS}-${ARCH} failed to start."
     exit 1
  else
     echo "DOCKER TEST: PASSED - Docker container test-${NODE_VERSION}-${OS}-${ARCH} succeeded to start."
  fi
}

docker_tag() {
    echo "DOCKER TAG: Tag Docker image."
    echo "DOCKER TAG: tagging image - ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-${OS}-${ARCH}."
    docker tag ${TARGET}:build-${NODE_VERSION}-${OS}-${ARCH} ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-${OS}-${ARCH}
}

docker_push() {
  echo "DOCKER PUSH: Push Docker image."
  echo "DOCKER PUSH: pushing - ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-${OS}-${ARCH}."
  docker push ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-${OS}-${ARCH}
}

docker_manifest_list() {
  # Create and push manifest lists, displayed as FIFO
  echo "DOCKER MANIFEST: Create and Push docker manifest lists."
  docker_manifest_list_version
  # if build is not a beta then create and push manifest lastest
    if [[ ${BUILD_VERSION} != *"beta"* ]]; then
        echo "DOCKER MANIFEST: Create and Push docker manifest lists LATEST."
        docker_manifest_list_latest
	  else
        echo "DOCKER MANIFEST: Create and Push docker manifest lists BETA."
        docker_manifest_list_beta
    fi
  docker_manifest_list_version_os_arch
}

docker_manifest_list_version() {
  # Manifest Create BUILD_VERSION
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${BUILD_VERSION}."
  docker manifest create ${TARGET}:${BUILD_VERSION} \
      ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-amd64 \
      ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 \
      ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 \
      ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8

  # Manifest Annotate BUILD_VERSION
  docker manifest annotate ${TARGET}:${BUILD_VERSION} ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 --os=linux --arch=arm --variant=v6
  docker manifest annotate ${TARGET}:${BUILD_VERSION} ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 --os=linux --arch=arm --variant=v7
  docker manifest annotate ${TARGET}:${BUILD_VERSION} ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8 --os=linux --arch=arm64 --variant=v8

  # Manifest Push BUILD_VERSION
  docker manifest push ${TARGET}:${BUILD_VERSION}
}

docker_manifest_list_latest() {
  # Manifest Create latest
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:latest."
  docker manifest create ${TARGET}:latest \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-amd64 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8

  # Manifest Annotate BUILD_VERSION
  docker manifest annotate ${TARGET}:latest ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 --os=linux --arch=arm --variant=v6
  docker manifest annotate ${TARGET}:latest ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 --os=linux --arch=arm --variant=v7
  docker manifest annotate ${TARGET}:latest ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8 --os=linux --arch=arm64 --variant=v8

  # Manifest Push BUILD_VERSION
  docker manifest push ${TARGET}:latest
}

docker_manifest_list_beta() {
  # Manifest Create beta
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:beta."
  docker manifest create ${TARGET}:beta \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-amd64 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8

  # Manifest Annotate BUILD_VERSION
  docker manifest annotate ${TARGET}:beta ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 --os=linux --arch=arm --variant=v6
  docker manifest annotate ${TARGET}:beta ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 --os=linux --arch=arm --variant=v7
  docker manifest annotate ${TARGET}:beta ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8 --os=linux --arch=arm64 --variant=v8

  # Manifest Push BUILD_VERSION
  docker manifest push ${TARGET}:beta
}

docker_manifest_list_version_os_arch() {
  # Manifest Create alpine-amd64
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-amd64."
  docker manifest create ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-amd64 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-amd64

  # Manifest Push alpine-amd64
  docker manifest push ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-amd64

  # Manifest Create alpine-arm32v6
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6."
  docker manifest create ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6

  # Manifest Annotate alpine-arm32v6
  docker manifest annotate ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6 --os=linux --arch=arm --variant=v6

  # Manifest Push alpine-arm32v6
  docker manifest push ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm32v6

  # Manifest Create slim-arm32v7
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7."
  docker manifest create ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7

  # Manifest Annotate slim-arm32v7
  docker manifest annotate ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7 --os=linux --arch=arm --variant=v7

  # Manifest Push slim-arm32v7
  docker manifest push ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-slim-arm32v7

  # Manifest Create alpine-arm64v8
  echo "DOCKER MANIFEST: Create and Push docker manifest list - ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8."
  docker manifest create ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8 \
    ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8

  # Manifest Annotate alpine-arm64v8
  docker manifest annotate ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8 ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8 --os=linux --arch=arm64 --variant=v8

  # Manifest Push alpine-arm64v8
  docker manifest push ${TARGET}:${BUILD_VERSION}-${NODE_VERSION}-alpine-arm64v8
}

#
#
# #------------
# docker_manifest_list_node_v10() {
#     # Manifest Create v10
#     docker manifest create $TARGET:$NODE_RED_VERSION-10 \
#       $TARGET:$NODE_RED_VERSION-10-alpine-amd64 \
#       # $TARGET:$NODE_RED_VERSION-10-alpine-arm32v6 \
#       $TARGET:$NODE_RED_VERSION-10-debian-arm32v7 \
#       $TARGET:$NODE_RED_VERSION-10-alpine-arm64v8
#
#     # Manifest Annotate v10
#     #docker manifest annotate $TARGET:$NODE_RED_VERSION-10 $TARGET:$NODE_RED_VERSION-10-alpine-arm32v6 --os=linux --arch=arm --variant=v6
#     docker manifest annotate $TARGET:$NODE_RED_VERSION-10 $TARGET:$NODE_RED_VERSION-10-debian-arm32v7 --os=linux --arch=arm --variant=v7
#     docker manifest annotate $TARGET:$NODE_RED_VERSION-10 $TARGET:$NODE_RED_VERSION-10-alpine-arm64v8 --os=linux --arch=arm64 --variant=v8
#
#     # Manifest Push v10
#     docker manifest push $TARGET:$NODE_RED_VERSION-10
# }
#
# docker_manifest_list_latest() {
#     # Manifest Create LATEST
#     docker manifest create $TARGET:latest \
#         $TARGET:latest-8-alpine-amd64 \
#         $TARGET:latest-8-alpine-arm32v6 \
#         $TARGET:latest-8-debian-arm32v7 \
#         $TARGET:latest-8-alpine-arm64v8
#
#     # Manifest Annotate LATEST
#     docker manifest annotate $TARGET:latest $TARGET:latest-8-alpine-arm32v6 --os=linux --arch=arm --variant=v6
#     docker manifest annotate $TARGET:latest $TARGET:latest-8-debian-arm32v7 --os=linux --arch=arm --variant=v7
#     docker manifest annotate $TARGET:latest $TARGET:latest-8-alpine-arm64v8 --os=linux --arch=arm64 --variant=v8
#
#     # Manifest Push LATEST
#     docker manifest push $TARGET:latest
# }

setup_dependencies() {
  echo "PREPARE: Setting up dependencies."

  sudo apt update -y
  # sudo apt install realpath python python-pip -y
  sudo apt install --only-upgrade docker-ce -y
  # sudo pip install docker-compose || true
  #
  # docker info
  # docker-compose --version
}

update_docker_configuration() {
  echo "PREPARE: Updating docker configuration"

  mkdir $HOME/.docker

  # enable experimental to use docker manifest command
  echo '{
    "experimental": "enabled"
  }' | tee $HOME/.docker/config.json

  # enable experimental
  echo '{
    "experimental": true,
    "storage-driver": "overlay2",
    "max-concurrent-downloads": 50,
    "max-concurrent-uploads": 50
  }' | sudo tee /etc/docker/daemon.json

  sudo service docker restart
}

prepare_qemu(){
    echo "PREPARE: Qemu"
    # Prepare qemu to build non amd64 / x86_64 images
    docker run --rm --privileged multiarch/qemu-user-static:register --reset
    mkdir tmp
    pushd tmp &&
    curl -L -o qemu-x86_64-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/$QEMU_VERSION/qemu-x86_64-static.tar.gz && tar xzf qemu-x86_64-static.tar.gz &&
    curl -L -o qemu-arm-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/$QEMU_VERSION/qemu-arm-static.tar.gz && tar xzf qemu-arm-static.tar.gz &&
    curl -L -o qemu-aarch64-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/$QEMU_VERSION/qemu-aarch64-static.tar.gz && tar xzf qemu-aarch64-static.tar.gz &&
    popd
}

main $1
