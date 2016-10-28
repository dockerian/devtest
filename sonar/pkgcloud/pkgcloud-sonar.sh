#!/bin/bash
############################################################
# Run pkgcloud test analysis
#
# Steps: -
#   1. Install nodejs modules
#   2. Download and configure sonar-runner
#   3. Configure live tests
#   4. Run unit tests with lcov reporter
#   5. Run integration tests with lcov reporter
#   6. Run test analysis
#
# See repos -
#     https://github.com/pkgcloud/pkgcloud
############################################################
script_source=${BASH_SOURCE[0]}
script_file="${script_source##*/}"
script_path="$( cd "$( echo "${script_source%/*}" )" && pwd )"
script_args=$@

# build up test environment
buildTest() {
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "(1). Build test environment"
  echo "============================================================"
  # pkgcloud repositories
  repo_pkgcloud="https://github.com/pkgcloud/pkgcloud.git"
  nodejs=`which nodejs || which node`

  # list npm config and environment settings
  echo "${nodejs##*/} version= `${nodejs} --version` - `which ${nodejs##*/}`"
  echo -e "npm version= `npm --version` - `which npm`\n`npm config ls -l`"
  echo "------------------------------------------------------------"
  (set -o posix; set)
  echo "------------------------------------------------------------"

  if [[ "$PWD" != "${script_path}" ]]; then
    echo "PWD= $PWD"
    echo `date +"%Y-%m-%d %H:%M:%S"` "Change to ${script_path//$PWD/}"
    cd "${script_path}"
  fi
  echo "PWD= $PWD"

  local devex=`[[ "${script_source}" =~ (devtest/sonar) ]] && echo "true"`
  local clone=`[[ ! -d "pkgcloud" ]] && [[ ! -d "${pkg_test}" ]] && \
     [[ "${PWD##*/}" != "${pkg_test}" ]] && echo "true"`
  # clone repository for devtest environment
  if [[ "${devex}" == "true" ]] || [[ "${clone}" == "true" ]]; then
    echo ""
    echo `date +"%Y-%m-%d %H:%M:%S"` "Cleaning up test environment ..."
    rm -rf "pkgcloud"
    repo="${repo_pkgcloud}"
    echo ""
    echo `date +"%Y-%m-%d %H:%M:%S"` "Cloning pkgcloud - ${repo} ..."
    echo "------------------------------------------------------------"
    git clone "${repo}"

    echo ""
    echo `date +"%Y-%m-%d %H:%M:%S"` "Installing pkgcloud and tests ..."
    echo "------------------------------------------------------------"
    find . -type d -exec chmod u+w {} +
    rm -rf "${script_path}/npm"
    mkdir -p "${script_path}/npm/bin"
    echo "prefix=${script_path}/npm" >> ~/.npmrc
    export PATH=${script_path}/npm/bin:$PATH
    echo "PATH=$PATH"
  fi

  # build test environment
  if [[ -d "pkgcloud" ]]; then
    echo ""
    echo `date +"%Y-%m-%d %H:%M:%S"` "Creating npm link ..."
    echo "------------------------------------------------------------"
    cd pkgcloud

    if [[ -f "../../../aft/pkgcloud/Makefile.mk" ]]; then
      cp -R "../../../aft/pkgcloud/Makefile.mk" .
    fi

    rm -rf node_modules
  	rm -rf lcov-report
    rm -rf reports
    mkdir reports

    npm install
    npm install --upgrade mocha
    npm install mocha-cobertura-reporter
    npm install mocha-lcov-reporter
    npm install mocha-istanbul
    npm install istanbul
  fi
  echo ""
}

# create and update config files for pkgcloud live tests
configLiveTests ()
{
  OS_USERNAME="${OS_USERNAME:=admin}"
  OS_PASSWORD="${OS_PASSWORD:=123456789012345678901234567890}"
  OS_AUTH_URL="${OS_AUTH_URL:=https://10.23.71.11:5000/v2.0/}"

  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "(3). Configure live tests"
  echo "============================================================"
  if [[ "${OS_AUTH_URL}" =~ (https://(([0-9]+\.){3}[0-9]+\:[0-9]+)) ]]; then
    OS_AUTH_URL="https://${BASH_REMATCH[2]}"
  fi
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "Configuring pkgcloud live tests ..."
  cp test/configs/mock/*.json test/configs

  cat << EOF > test/configs/providers.json
["hp", "openstack"]
EOF

  cat << EOF > test/configs/openstack.json
{
  "username": "${OS_USERNAME}",
  "password": "${OS_PASSWORD}",
  "provider": "hp",
  "authUrl": "${OS_AUTH_URL}",
  "region": "regionOne"
}
EOF

  cat << EOF > test/configs/hp.json
{
  "username": "${OS_USERNAME}",
  "password": "${OS_PASSWORD}",
  "provider": "hp",
  "authUrl": "${OS_AUTH_URL}",
  "region": "regionOne"
}
EOF
  echo "test/configs/hp.json"
  echo "------------------------------------------------------------"
  cat test/configs/hp.json
  echo "------------------------------------------------------------"
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "Done live tests configuration."
  echo "------------------------------------------------------------"
}

configSonarRunner() {
  local sonar_host="http://distillery.fc.hp.com:9000"
  local sonar_jdbc="jdbc:mysql://distillery.fc.hp.com:3306/sonar?useUnicode=true&characterEncoding=utf8"
  local sonar_file="sonar-runner-dist-2.4.zip"
  local maven_site="http://repo1.maven.org/maven2/org/codehaus"
  local sonar_prod="sonar/runner/sonar-runner-dist/2.4"
  local sonar_dist="${maven_site}/${sonar_prod}/${sonar_file}"
  local sonar_temp="sonar-temp"

  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "(2). Configure sonar-runner"
  echo "============================================================"
  # download sonar-runner
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "Downloading ${sonar_dist} ..."
  rm -rf sonar-temp && mkdir sonar-temp
  pushd sonar-temp
  curl -O ${sonar_dist}
  unzip ${sonar_file}
  popd

  # configure sonar-runner
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "Configuring sonar-runner ..."
  export SONAR_RUNNER_HOME="$(pwd)/sonar-temp/sonar-runner-2.4"
  cat << EOF > ${SONAR_RUNNER_HOME}/conf/sonar-runner.properties
sonar.host.url=${sonar_host}
sonar.jdbc.url=${sonar_jdbc}
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
EOF
  echo "${SONAR_RUNNER_HOME}/conf/sonar-runner.properties"
  echo "------------------------------------------------------------"
  cat ${SONAR_RUNNER_HOME}/conf/sonar-runner.properties
  echo "------------------------------------------------------------"

  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "Configuring sonar project ..."
  cat << EOF > sonar-project.properties
sonar.projectKey=github:pkgcloud
sonar.projectName=Openstack SDK - pkgcloud
sonar.projectVersion=master

sonar.language=js
sonar.sourceEncoding=UTF-8

# coverage reporting
sonar.javascript.jstest.reportsPath=reports
sonar.javascript.lcov.reportPath=reports/coverage.lcv
sonar.javascript.lcov.itReportPath=reports/it-coverage.lcv

# path to source directories (or set sonar.modules)
# sonar.sources=lib
sonar.tests=test

sonar.modules=hp-module, openstack-module
openstack-module.sonar.projectName=lib/pkgcloud/openstack
openstack-module.sonar.projectBaseDir=.
openstack-module.sonar.sources=lib/pkgcloud/openstack
hp-module.sonar.projectName=lib/pkgcloud/hp
hp-module.sonar.sources=lib/pkgcloud/hp
hp-module.sonar.projectBaseDir=.
EOF
}


# Run customized tests and analysis
buildTest
configSonarRunner
configLiveTests

# Run test with coverage (with lcov reporter)
echo ""
echo `date +"%Y-%m-%d %H:%M:%S"` "(4). Run unit tests with lcov reports ..."
echo "============================================================"
NODE_ENV=test MOCK=on ./node_modules/.bin/mocha --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js --reporter mocha-lcov-reporter > reports/coverage.lcv

# Run live test
echo ""
echo `date +"%Y-%m-%d %H:%M:%S"` "(5). Run live tests with lcov reports ..."
echo "============================================================"
NODE_ENV=test ./node_modules/.bin/mocha --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js --reporter mocha-lcov-reporter > reports/it-coverage.lcv

# Invoke sonar-runner
echo ""
echo `date +"%Y-%m-%d %H:%M:%S"` "(6). Run and publish test analysis ..."
echo "============================================================"
$SONAR_RUNNER_HOME/bin/sonar-runner
unset SONAR_RUNNER_HOME

echo ""
echo "============================================================"
echo `date +"%Y-%m-%d %H:%M:%S"` "DONE."
