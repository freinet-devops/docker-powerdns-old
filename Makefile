COMMIT_ID := $$(git log -1 --date=short --pretty=format:%cd.%h)
TAG   := $$(git describe --exact-match --tags $$(git log -n1 --pretty='%h'))

NAME   := freinet/powerdns
IMG    := ${NAME}:${COMMIT_ID}
GIT_TAGGED := ${NAME}:${TAG}
LATEST := ${NAME}:latest
TEST := ${NAME}:test

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

build: ## build the container
	@docker build -t ${IMG} .
	@if [ ! -z $$(git describe --exact-match --tags $$(git log -n1 --pretty='%h')) ] ; then \
		echo ${GIT_TAGGED} ; \
		docker tag ${IMG} ${GIT_TAGGED}; \
	fi ;

build-test:
	@docker build -t ${IMG} .
	@docker tag ${IMG} ${TEST}


build-latest:
	@docker build -t ${IMG} .
	@docker tag ${IMG} ${LATEST}

push: build-latest ## push image to repo
	@docker push ${NAME}
