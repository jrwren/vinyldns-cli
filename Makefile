NAME=vinyldns
VERSION=0.8.10
TAG=v$(VERSION)
ARCH=$(shell uname -m)
PREFIX=/usr/local
DOCKER_NAME=vinyldns/vinyldns-cli
IMG=${DOCKER_NAME}:${VERSION}
LATEST=${DOCKER_NAME}:latest
BATS=github.com/sstephenson/bats
VINYLDNS_REPO=github.com/vinyldns/vinyldns
SRC=src/*.go

all: test stop-api docker build-releases

install: build
	mkdir -p $(PREFIX)/bin
	cp -v bin/$(NAME) $(PREFIX)/bin/$(NAME)

uninstall:
	rm -vf $(PREFIX)/bin/$(NAME)

build:
	go build -ldflags "-X main.version=$(VERSION)" -o bin/$(NAME) $(SRC)

build-releases:
	rm -rf release && mkdir release
	GOOS=linux go build -ldflags "-X main.version=$(VERSION)" -o release/$(NAME)_$(VERSION)_linux_$(ARCH) $(SRC)
	GOOS=darwin go build -ldflags "-X main.version=$(VERSION)" -o release/$(NAME)_$(VERSION)_darwin_$(ARCH) $(SRC)
	GOOS=linux CGO_ENABLED=0  go build -ldflags "-X main.version=$(VERSION)" -o release/$(NAME)_$(VERSION)_linux_$(ARCH)_nocgo $(SRC)

start-api:
	if [ ! -d "$(GOPATH)/src/$(VINYLDNS_REPO)" ]; then \
		echo "$(VINYLDNS_REPO) not found in your GOPATH (necessary for acceptance tests), getting..."; \
		git clone https://$(VINYLDNS_REPO) $(GOPATH)/src/$(VINYLDNS_REPO); \
	fi
	$(GOPATH)/src/$(VINYLDNS_REPO)/bin/docker-up-vinyldns.sh \
		--api-only \
		--version 0.9.1

stop-api:
	$(GOPATH)/src/$(VINYLDNS_REPO)/bin/remove-vinyl-containers.sh

bats:
	if ! [ -x ${GOPATH}/src/${BATS}/bin/bats ]; then \
		git clone --depth 1 https://${BATS}.git ${GOPATH}/src/${BATS}; \
	fi

test: build bats start-api
	go get -u golang.org/x/lint/golint
	golint -set_exit_status $(SRC)
	go vet $(SRC)
	${GOPATH}/src/${BATS}/bin/bats tests

release: build-releases
	go get github.com/aktau/github-release
	github-release release \
		--user vinyldns \
		--repo vinyldns-cli \
		--tag $(TAG) \
		--name "$(TAG)" \
		--description "vinyldns-cli version $(VERSION)"
	cd release && ls | xargs -I FILE github-release upload \
		--user vinyldns \
		--repo vinyldns-cli \
		--tag $(TAG) \
		--name FILE \
		--file FILE

docker:
	docker build -t ${IMG} .
	docker tag ${IMG} ${LATEST}

docker-push:
	docker push ${LATEST}
	docker push ${IMG}

.PHONY: install uninstall build build_releases release test docker docker-push
