APPLICATION_NAME = ruby-hello_world-on-lambda
APPLICATION_SOURCE_DIR = hello_world

PACKAGE_TMPDIR :=$(shell mktemp -d)

APPLICATION_TMPDIR = $(PACKAGE_TMPDIR)/lib/app
RESOURCES_TMPDIR = $(PACKAGE_TMPDIR)/resources
RUBY_TMPDIR = $(PACKAGE_TMPDIR)/lib/ruby

# Traveling ruby details
# Thanks to https://github.com/adomokos/aws-lambda-ruby/blob/master/Makefile
TRAVELING_RUBY_URL_PREFIX = https://github.com/develar/traveling-ruby/releases/download
TRAVELING_RUBY_VERSION = 2.3.1
TRAVELING_RUBY_FILENAME = traveling-ruby-$(TRAVELING_RUBY_VERSION)-linux-x86_64.tar.xz
TRAVELING_RUBY_URL = $(TRAVELING_RUBY_URL_PREFIX)/v$(TRAVELING_RUBY_VERSION)/$(TRAVELING_RUBY_FILENAME)
TRAVELING_RUBY_ARCHIVE_SHA256SUM = 4e83297fa2e5367ea5f3372877b343a480aecf2b1ff15adeaf80f5195f6da565
TRAVELING_RUBY_ARTEFACTS := lib index.js start_app

.DEFAULT_GOAL := help
.PHONY: publish

package: ## Packages the code for AWS Lambda
	@echo 'Package the app for deploy'
	@echo '--------------------------'
	@echo "RESOURCES_TMPDIR: $(RESOURCES_TMPDIR)"
	@mkdir -pv $(RESOURCES_TMPDIR) $(APPLICATION_TMPDIR) $(RUBY_TMPDIR)

	@echo "Downloading traveling ruby $(TRAVELING_RUBY_VERSION) ..."
	@wget -O $(RESOURCES_TMPDIR)/$(TRAVELING_RUBY_FILENAME) -- $(TRAVELING_RUBY_URL)
	@echo "$(TRAVELING_RUBY_ARCHIVE_SHA256SUM)  $(RESOURCES_TMPDIR)/$(TRAVELING_RUBY_FILENAME)" | sha256sum -c

	@echo "Extracting traveling ruby $(TRAVELING_RUBY_VERSION) ..."
	@tar -xf $(PACKAGE_TMPDIR)/resources/$(TRAVELING_RUBY_FILENAME) -C $(RUBY_TMPDIR)

	@echo "Copying application ..."
	@cp -av $(APPLICATION_SOURCE_DIR)/* $(APPLICATION_TMPDIR)

	@mkdir -p $(PACKAGE_TMPDIR)/lib/vendor/.bundle
	@echo -e "BUNDLE_PATH: .\nBUNDLE_WITHOUT: development:test\nBUNDLE_DISABLE_SHARED_GEMS: '1'" > $(PACKAGE_TMPDIR)/lib/vendor/.bundle/config
	@cp -v $(APPLICATION_SOURCE_DIR)/Gemfile* $(PACKAGE_TMPDIR)/lib/vendor || touch $(PACKAGE_TMPDIR)/lib/vendor/{Gemfile,.lock}

	 # install libraries
	@cd $(PACKAGE_TMPDIR)/lib/vendor && bundle package
	@mv -v $(PACKAGE_TMPDIR)/lib/vendor/cache/* $(PACKAGE_TMPDIR)/lib/vendor ||:

	sed "s|#APPLICATION_NAME#|$(APPLICATION_NAME)|g" index.js > $(PACKAGE_TMPDIR)/index.js

	@rm -rf $(RESOURCES_TMPDIR)
	@rm -vf $(HOME)/$(APPLICATION_NAME).zip
	@chmod -R 777 $(APPLICATION_TMPDIR)

	@cd $(PACKAGE_TMPDIR) && zip -r $(HOME)/$(APPLICATION_NAME).zip $(TRAVELING_RUBY_ARTEFACTS)
	@rm -rf $(PACKAGE_TMPDIR)

create:
	aws lambda create-function \
	    --function-name $(APPLICATION_NAME) \
	    --handler index.handler \
	    --runtime nodejs4.3 \
	    --memory 512 \
	    --timeout 10 \
	    --description "Saying hello from MRI Ruby" \
	    --role arn:aws:iam::$(AWS_ACCOUNT_ARN):role/lambda_hello_world \
	    --zip-file fileb://$(HOME)/$(APPLICATION_NAME).zip

deploy:
	 aws lambda update-function-code \
	     --function-name $(APPLICATION_NAME) \
	     --zip-file fileb://$(HOME)/$(APPLICATION_NAME).zip
