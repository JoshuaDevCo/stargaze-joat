PACKAGES=$(shell go list ./... | grep -v '/simulation')

VERSION := $(shell echo $(shell git describe --tags --always) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')

# TODO: Update the ldflags with the app, client & server names
ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=NewApp \
	-X github.com/cosmos/cosmos-sdk/version.ServerName=staked \
	-X github.com/cosmos/cosmos-sdk/version.ClientName=stakecli \
	-X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
	-X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) 

BUILD_FLAGS := -ldflags '$(ldflags)'

all: install

create-wallet:
	bin/stakecli keys add validator --keyring-backend test

init:
	rm -rf ~/.staked
	bin/staked init stakebird
	bin/staked add-genesis-account $(shell bin/stakecli keys show validator -a --keyring-backend test) 10000000000ufuel --keyring-backend test
	bin/staked gentx --name=validator --amount 10000000000ufuel --keyring-backend test
	bin/staked collect-gentxs 

install: go.sum
		go install -mod=readonly $(BUILD_FLAGS) ./cmd/staked
		go install -mod=readonly $(BUILD_FLAGS) ./cmd/stakecli

build:
		go build -o bin/staked ./cmd/staked
		go build -o bin/stakecli ./cmd/stakecli

go.sum: go.mod
		@echo "--> Ensure dependencies have not been modified"
		GO111MODULE=on go mod verify

# Uncomment when you have some tests
# test:
# 	@go test -mod=readonly $(PACKAGES)

# look into .golangci.yml for enabling / disabling linters
lint:
	@echo "--> Running linter"
	@golangci-lint run
	@go mod verify


build-linux: 
	GOARCH=amd64 GOOS=linux go build -o bin/staked github.com/rocket-protocol/stakebird/cmd/staked
	GOARCH=amd64 GOOS=linux  go build -o bin/stakecli github.com/rocket-protocol/stakebird/cmd/stakecli

docker-test: build-linux
	docker build -f docker/Dockerfile.test -t rocketprotocol/stakebird-relayer-test:latest .

###############################################################################
###                                Protobuf                                 ###
###############################################################################
proto-all: proto-gen proto-lint proto-check-breaking

proto-gen:
	@./contrib/protocgen.sh

proto-lint:
	@buf check lint --error-format=json

proto-check-breaking:
	@buf check breaking --against-input '.git#branch=master'

.PHONY: proto-all proto-gen proto-lint proto-check-breaking
