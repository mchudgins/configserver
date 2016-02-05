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
	cp target/$(ARTIFACT) $(DOCKER_DIR)
	sudo docker build -t $(ARTIFACT_NAME):$(APP_VERSION) $(DOCKER_DIR)
	
run_container:
	sudo docker run -it --rm -p 9080:8080 -e POD_NAMESPACE=k8s-dev turbine
	
push:
	- sudo docker rmi registry.dstresearch.com/turbine
	sudo docker tag turbine registry.dstresearch.com/turbine
	sudo docker push registry.dstresearch.com/turbine

$(BUILD_NUMBER_FILE):
	@if ! test -f $(BUILD_NUMBER_FILE); then echo 0 > $(BUILD_NUMBER_FILE); echo setting file to zero; fi
	@echo $$(($$(cat $(BUILD_NUMBER_FILE)) + 1)) > $(BUILD_NUMBER_FILE)

clean:
	mvn clean
	- rm -f *.jar
