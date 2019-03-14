# Requires make v4+
# Windows build is available here https://sourceforge.net/projects/ezwinports/files/

## Makefile requirements:
# - It should be located in repository root
# - It should provide VERIFY variable which contains list of targets to make

## Configuration variables
# Number of CPUs which are going to be used for verification (more = faster if
# project contains targets which can run in parallel)
export CPUS ?= 2
# Commit which is going to be verified
export COMMIT ?= $(shell git rev-parse --short HEAD)
# Verify workspace directory which will contain clean checkout of project repo
export VERIFY_WORKSPACE := .verify-workspace
# Location of Dockerfile which will be used to create sandbox for `make verify'
export VERIFY_DOCKERFILE ?= Dockerfile.verify
# Tag used for successfully verified commit
export OK_TAG ?= OK
# Tag used for failed commit
export FAIL_TAG ?= FAIL

SELFDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash
.SHELLFLAGS = -e -c -o pipefail
export LOG := $(CURDIR)/.verify.log
export GIT_ROOT := $(CURDIR)
export GIT_PROJECT := $(shell basename ${GIT_ROOT})
export VERIFY_DOCKER_IMAGE := ${GIT_PROJECT}/verify:${COMMIT}

## Utils
path2target = $(shell git diff --name-only HEAD^.. | grep "^$(1)" > /dev/null && echo $(2))

# notify(message, icon)
ifdef OS
	# Windows specific implementation
	# Install https://github.com/Windos/BurntToast. Note that there might be difference in search path, either Program Files\WindowsPowerShell\Modules\ or Program Files (x86)...
	notify = powershell -ExecutionPolicy RemoteSigned New-BurntToastNotification -UniqueIdentifier ${COMMIT} -Text \"Commit Verify - ${GIT_PROJECT}\", \"$(1)\" -AppLogo \"${SELFDIR}/images/$(2).png\" &
else
	# Mac specific implementation
	notify = terminal-notifier -group ${COMMIT} -title "Commit Verify - ${GIT_PROJECT}" -message "$(1)" -contentImage "${SELFDIR}/images/$(2).png" -execute "open ${LOG}"
endif

## Targets
noop:
	echo Nothing to do

clean:
	rm -rf ${VERIFY_WORKSPACE}
	rm -rf ${LOG}

ifdef DOCKER
verify-sandbox: ${VERIFY_WORKSPACE}-sync
	docker build -t ${VERIFY_DOCKER_IMAGE} -f ${VERIFY_DOCKERFILE} ${VERIFY_WORKSPACE}
	docker run --cpus ${CPUS} -t ${VERIFY_DOCKER_IMAGE} COMMIT="${COMMIT}" ${VERIFY}
else
verify-sandbox: ${VERIFY_WORKSPACE}-sync
	make -j ${CPUS} --output-sync -C ${VERIFY_WORKSPACE} COMMIT="${COMMIT}" ${VERIFY}
endif

${VERIFY_WORKSPACE}:
	git clone --local --recurse-submodules . ${VERIFY_WORKSPACE}

${VERIFY_WORKSPACE}-sync: ${VERIFY_WORKSPACE}
	cd ${VERIFY_WORKSPACE} && git fetch --all --recurse-submodules=on-demand && git reset --hard ${COMMIT} \
		&& git submodule init && git submodule sync && git submodule update

.ONESHELL:
# Same as verify, but it makes sure that we verify HEAD (or given commit)
comfy:
	rm -f ${LOG} && touch ${LOG}
	$(call notify,Running...,running)
	pass=false
	function finally {
		if $$pass; then
			$(call notify,Passed in $$SECONDS seconds,pass)
			git tag --force ${OK_TAG} ${COMMIT}
		else
			$(call notify,Failed in $$SECONDS seconds,fail)
			git tag --force ${FAIL_TAG} ${COMMIT}
		fi
	}
	trap finally EXIT

	make verify-sandbox | tee ${LOG}
	pass=true

verify-commit: comfy
	@echo "DEPRECATION WARNING (MakeComfy): Please use comfy target instead of verify-commit"
