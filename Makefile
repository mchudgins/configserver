#
# Makefile for configServer
#
# this file requires that maven 3 and xml_grep (from xml-twig-tools)
# have been previously installed.
#

MVN=./mvnw

BUILD_NUMBER_FILE=build.num
BUILD_NUM := $(shell cat build.num)

APP_VERSION := $(shell xml_grep --root /project/version --text pom.xml)
ARTIFACT_NAME := $(shell xml_grep --root /project/artifactId --text pom.xml)
ARTIFACT := $(ARTIFACT_NAME)-$(APP_VERSION).jar

DOCKER_DIR=src/main/docker


container_deps := $(DOCKER_DIR)/Dockerfile target/$(ARTIFACT) $(BUILD_NUMBER_FILE)

.PHONY: container clean push $(BUILD_NUMBER_FILE)

all: container

target/$(ARTIFACT):
	$(MVN) package

container: $(container_deps)
	cp target/$(ARTIFACT) $(DOCKER_DIR)/app.jar
	sudo docker build -t $(ARTIFACT_NAME):$(APP_VERSION) $(DOCKER_DIR)

run_container:
	sudo docker run -it --rm -p 8888:8888 \
		-e GIT_REPO_URL="https://github.com/mchudgins/testRepo.git" \
		$(ARTIFACT_NAME):$(APP_VERSION)

push:
	- sudo docker rmi mchudgins/$(ARTIFACT_NAME):$(APP_VERSION)
	sudo docker tag $(ARTIFACT_NAME):$(APP_VERSION) mchudgins/$(ARTIFACT_NAME):$(APP_VERSION)
	sudo docker push mchudgins/$(ARTIFACT_NAME):$(APP_VERSION)

$(BUILD_NUMBER_FILE):
	@if ! test -f $(BUILD_NUMBER_FILE); then echo 0 > $(BUILD_NUMBER_FILE); echo setting file to zero; fi
	@echo $$(($$(cat $(BUILD_NUMBER_FILE)) + 1)) > $(BUILD_NUMBER_FILE)

clean:
	$(MVN) clean
	- rm -f *.jar
