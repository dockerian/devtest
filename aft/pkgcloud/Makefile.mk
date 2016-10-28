############################################################
# Makefile: Run unit tests and sonar reports for pkgcloud
############################################################
MOCHA_MOCK = MOCK=on ./node_modules/.bin/mocha
MOCHA_OPTS = --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js
REPORT_OPTS = --reporter mocha-lcov-reporter > reports/coverage.lcv
REPORT_OPTS_COBERTURA = --reporter mocha-cobertura-reporter > reports/coverage.xml
REPORT_OPTS_HTML = --reporter html-cov > reports/coverage.html
REPORT_OPTS_ISTANBUL = --reporter mocha-istanbul
REPORT_OPTS_SPEC = --reporter spec
CMD_ISTANBUL = node_modules/.bin/istanbul
CMD_TEST = $(MOCHA_MOCK) $(MOCHA_OPTS)
CMD_TEST_COV_HTML = $(CMD_TEST) $(REPORT_OPTS_HTML)
LIB_EXISTS = $(shell [[ -d lib ]] && [[ -d test ]] && echo 1 || echo 0 )

.PHONY: clean cover sonar test

clean:
	@echo "PWD=${PWD}"
	# clean up
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Start cleaning up ..."
	@rm -rf node_modules
	@rm -rf lcov-report
	@rm -rf reports
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@\n"

clean-build: clean
	# clean up reports
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Start cleaning up reports ..."
ifeq ($(LIB_EXISTS), 1)
	@mkdir reports
	@echo ""
	# install npm packages locally (in ./node_modules)
	@npm install
	@echo ""
	# update npm packages locally (in ./node_modules)
	@npm install mocha
	@npm install mocha-cobertura-reporter
	@npm install mocha-lcov-reporter
	@npm install mocha-istanbul
	@npm install istanbul
endif
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@"
	@echo ""

cover: test
	# running test analysis
	@sonar-runner -Dsonar.javascript.lcov.reportPath=reports/coverage.lcv
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@\n"

cover-cobertura: test-cobertura
	# running test analysis
	@sonar-runner -Dsonar.js.coveragePlugin=cobertura -Dsonar.cobertura.reportsPath=reports/coverage.xml
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@\n"

cover-html: clean-build
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Start generating html coverage report ..."
	@echo "$(CMD_TEST_COV_HTML)"
	@NODE_ENV=test $(CMD_TEST_COV_HTML)
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@\n"

test: clean-build
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Start testing with lcov reporter ..."
	@echo "$(CMD_TEST) $(REPORT_OPTS)"
	@NODE_ENV=test $(CMD_TEST) $(REPORT_OPTS)
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@\n"

test-cobertura: clean-build
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Start testing with cobertura reporter ..."
	@echo "$(CMD_TEST) $(REPORT_OPTS_COBERTURA)"
	@NODE_ENV=test $(CMD_TEST) $(REPORT_OPTS_COBERTURA)
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@\n"

sonar: clean-build
ifeq ($(LIB_EXISTS), 1)
	# create test instrument
	$(CMD_ISTANBUL) instrument --output lib-cov lib
	# move original lib code and replace it by the instrumented one
	mv lib lib-orig && mv lib-cov lib
	@echo ""
	# set istanbul reporters to only generate the lcov file
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Start running tests with lcov reports ..."
	ISTANBUL_REPORTERS=lcovonly NODE_ENV=test $(CMD_TEST) $(REPORT_OPTS_ISTANBUL)
	@echo ""
	# place the lcov report in the report folder
	cp -R lcov.info reports/coverage.lcv
	# remove instrumented code and put back lib at its place
	rm -rf lib && mv lib-orig lib
	# generate html reports
	# genhtml reports/lcov.info --output-directory reports/
  # running test analysis
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Start publishing test reports ..."
	@sonar-runner
endif
	@echo `date +"%Y-%m-%d %H:%M:%S"` "DONE: $@\n"
