.PHONY: clean version build pipeline_containers splunk_8_0_1 eventgen7 appinspect

APP_ROOT := testing_app
VERSION := $(if $(CI_COMMIT_TAG),$(CI_COMMIT_TAG),$(shell git describe --long))
APP_PACKAGE_NAME := $(APP_ROOT)_$(VERSION).tgz
COLON := :

clean:
	rm -rf ./build || true
	rm -rf ./output || true
	docker kill splunk_8_0_1 || true
	docker continer rm splunk_8_0_1 || true
	docker continer rm cypress_runner || true
	docker network rm testingnet || true

version: ## Update the apps' versions
	# SHORT_HASH is the part after the tag number from 'git describe'. Format:
	# ${number of commits since last annotated tag}-g${commit short SHA}
	SHORT_HASH=`git describe --long | cut -d '-' -f 2,3` \
	LATEST_TAG=`git describe --abbrev=0` && \
	sed -i -e "s/AUTOBUMPED/$$LATEST_TAG/" -e "s/BUILD_SHORT_HASH/$$SHORT_HASH/" $(APP_ROOT)/default/app.conf

build: clean version ## Build tar balls containing the apps
	mkdir -p ./build
	tar -czvf ./build/$(APP_PACKAGE_NAME) ./$(APP_ROOT)

splunk_8_0_1:
	docker build ./cicd/dockerfiles -t splunk_8_0_1 -f cicd/dockerfiles/splunk_8_0_1.dockerfile

eventgen7:
	docker build ./cicd/dockerfiles -t eventgen7 -f cicd/dockerfiles/eventgen_7_0_0.dockerfile

appinspect:
	docker build ./cicd/dockerfiles -t appinspect -f cicd/dockerfiles/appinspect.dockerfile

pipeline_containers: splunk_8_0_1 eventgen7 appinspect

generate-data: ## generate log data to cmc-app/output using eventgen container and use local sample log files
	mkdir -p output
	docker run \
	-v `pwd`/output:/output/ \
	-v `pwd`/cicd/eventgen.conf:/conf/eventgen.conf \
	-v `pwd`/cicd/samples:/samples \
	weberjas/eventgen7:latest \
	bash -c 'splunk_eventgen -v generate /conf/eventgen.conf'

start-801:  ## Splunk 8.0.1 container
	docker run -d --rm --name splunk801 \
		-p 8000:8000 -p 8089:8089 \
		--hostname 'idx-example.splunkcloud.com' \
		-v `pwd`/$(APP_ROOT):/opt/splunk/etc/apps/$(APP_ROOT) \
		-v `pwd`/output:/output \
		-v `pwd`/cicd/inputs.conf:/opt/splunk/etc/system/local/inputs.conf \
		-e LD_LIBRARY_PATH=/opt/splunk/lib \
		splunk_8_0_1$(COLON)latest

cypress_local: ## Open the Cypress GUI to run tests
	export CYPRESS_cookie_timeout=5000 \
	&& export CYPRESS_BASE_URL=http://localhost:8000 \
	&& cd cicd/test/ && npm install && npm run debug

