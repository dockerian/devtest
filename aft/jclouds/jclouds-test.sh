#!/bin/bash
############################################################
# Run jcloud unit tests and live tests for HP public cloud
#
# Args 1 - jclouds project (e.g. apis/openstack-keystone)
#      2 - live test vendors (e.g. "hpcloud openstack")
#
# Prerequisites:
#     - bash, JDK, and maven
#     - Environment vars for hp helion cloud live tests
#         $HP_TENANT_NAME $HP_IDENTITY_URL $HP_ACCESSKEY $HP_SECRETKEY
#     - Environment vars for openstack live tests
#         $OS_TENANT_NAME $OS_AUTH_URL $OS_USERNAME $OS_PASSWORD
#
# Steps: -
#     1. Check jclouds path in $PWD
#     2. Clone jclouds repository, or cd to existing jclouds project
#     3. Configure maven settings if proxy is used
#     4. Configure test arguments
#     5. Run unit tests, then live tests (if available) recursively
#     6. Print test summary report
#
# See repos -
#     https://github.com/jclouds/jclouds
############################################################
script_source=${BASH_SOURCE[0]}
script_args=$@

# build up test environment
# args:$1 - jcloud project path (optional, e.g. apis/openstack-keystone)
#      $2 - live test vendors (optional, e.g. "hpcloud openstack")
buildupEnv() {
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "(1). Build test environment"
  echo "============================================================"
  output_file="test.tmp"
  vendors="${2-hpcloud openstack}"
  github_repo="https://github.com/jclouds/jclouds"
  env_jenkins=`[[ "${PWD}" =~ (/var/lib/jenkins/jobs) ]] && echo "true"`

  # get full path to this script itself
  script_file="${script_source##*/}"
  script_path="$( cd "$( echo "${script_source%/*}" )" && pwd )"

  if [[ "${PWD##*/}" == "jclouds" ]] && [[ -f "pom.xml" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Using current jclouds ..."
  elif [[ "${PWD}" =~ (/jclouds/) ]] && [[ -f "pom.xml" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Using jclouds/*/${PWD##*/} ..."
  elif [[ "$PWD" != "${script_path}" ]]; then
    echo "PWD= $PWD"
    echo `date +"%Y-%m-%d %H:%M:%S"` "Change to ${script_path//$PWD/}"
    cd "${script_path}"
  fi

  # if no jclouds repo and nor in devtest or a jclouds project
  local clone=`[[ ! -f "jclouds/pom.xml" ]] && echo "true"`
  local devex=`([[ "${PWD}" =~ (devtest/aft/jclouds) ]] || \
          [[ ! "${PWD}" =~ (jclouds) ]]) && echo "true"`
  if [[ "${devex}" == "true" ]] && [[ "${clone}" == "true" ]]; then
    echo ""
    echo `date +"%Y-%m-%d %H:%M:%S"` "Cleaning up test environment ..."
    find . -type d -exec chmod u+w {} +
    find . -name ${output_file} -delete
    rm -rf "jclouds"
    echo ""
    echo `date +"%Y-%m-%d %H:%M:%S"` "Cloning jclouds - ${github_repo} ..."
    echo "------------------------------------------------------------"
    git clone "${github_repo}"
  fi
  if [[ -f "jclouds/pom.xml" ]] ; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Changing to ${PWD}/jclouds ..."
    cd jclouds
  fi

  CWD_BASE="${PWD}"
  echo ""
  echo "mvn version= `mvn --version` - `which mvn`"
  echo "------------------------------------------------------------"
  (set -o posix; set)
  echo "------------------------------------------------------------"
  if [[ "${output_file}" != "" ]]; then
    echo -e "Use: \"${output_file}\" as temporary output.\n"
  fi
  if [[ "`which mvn`" == "" ]]; then
    echo "Abort: Cannot find mvn."
    exit -1
  elif [[ ! "${PWD}" =~ (/jclouds) ]] && [[ ! -f "pom.xml" ]]; then
    echo "Abort: Cannot find jclouds projects in PWD= $PWD"
    exit -2
  elif [[ "${PWD##*/}" != "jclouds" ]] && [[ ! -f "pom.xml" ]] && [[ ! -f "all/pom.xml" ]]; then
    echo "Abort: Cannot find jclouds in PWD= $PWD"
    exit -3
  fi
  # change directory to specific project, if provided
  if [[ "$1" != "" ]] && [[ -d "${PWD}/$1" ]] && [[ -f "${PWD}/$1/pom.xml" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Changing to project $1 [vendors: ${vendors}] ..."
    cd "${PWD}/$1"
  fi
  echo -e "PWD= ${PWD}\n"

  configTestArgs
  configMaven
}

# configure ~/.m2/settings.xml if proxy is used
configMaven() {
  if [[ "${http_proxy}" != "" ]] || [[ "${https_proxy}" != "" ]]; then
    local http_proxy_host="" http_proxy_port=""
    local secu_proxy_host="" secu_proxy_port=""
    local none_proxy_sets="${no_proxy//,/|}"
    if [[ "${http_proxy}" =~ (http://(.+):(.+)) ]]; then
      http_proxy_host="${BASH_REMATCH[2]}"
      http_proxy_port="${BASH_REMATCH[3]}"
    fi
    if [[ "${https_proxy}" =~ (https?://(.+):(.+)) ]]; then
      secu_proxy_host="${BASH_REMATCH[2]}"
      secu_proxy_port="${BASH_REMATCH[3]}"
    fi
    if [[ "${OS_AUTH_URL}" =~ (https://(([0-9]+\.){3}[0-9]+)) ]]; then
      local endpoint_host="${BASH_REMATCH[2]}"
      none_proxy_sets="${none_proxy_sets}|${endpoint_host}"
    fi
    local mvn_config_file=~/.m2/settings.xml
    echo `date +"%Y-%m-%d %H:%M:%S"` "Configuring ${mvn_config_file} ..."
    cat > "${mvn_config_file}" <<!
<settings>
    <proxies>
        <proxy>
            <active>true</active>
            <protocol>http</protocol>
            <host>${http_proxy_host}</host>
            <port>${http_proxy_port}</port>
            <nonProxyHosts>${none_proxy_sets}</nonProxyHosts>
        </proxy>
        <proxy>
            <active>true</active>
            <protocol>https</protocol>
            <host>${secu_proxy_host}</host>
            <port>${secu_proxy_port}</port>
            <nonProxyHosts>${none_proxy_sets}</nonProxyHosts>
        </proxy>
    </proxies>
</settings>
!
    echo "------------------------------------------------------------"
    cat  "${mvn_config_file}"
    echo "------------------------------------------------------------"
    echo ""
  fi
}

# initialize global configuration and settings (only run once for all tests)
configTestArgs() {
  default_tenantId="admin"
  default_username="admin"
  default_password="1234567890123456789012345678901234567890"
  default_auth_url="https://10.23.71.11:5000/v2.0"
  default_provider="openstack-keystone"
  hpcloud_username="${HP_USERNAME:=Platform-AddIn-QA}"
  hpcloud_password="${HP_PASSWORD}"
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "(2). Start test configurations"
  echo "============================================================"
  echo "PWD= $PWD"

  # default settings for openstack
  configTestArgs_openstack

  # settings for counters of live tests and unit tests
  count_livetest=0
  count_livetest_jfiles=0
  count_livetest_bypass=0 count_livetest_errors=0
  count_livetest_passed=0 count_livetest_failed=0
  count_projects=0
  count_unittest=0
  count_unittest_bypass=0 count_unittest_errors=0
  count_unittest_passed=0 count_unittest_failed=0
  exitcode=0
}

# config settings for vendor, and return if live test is supported
# arg:$1 - vendor name (for now only "hpcloud" or "openstack" is supported)
# return : 0 (succeeded) if the vendor is supported; otherwise, -1 (failed)
configTestArgs_a_vendor() {
  local vendor="$1"
  if [[ "$vendor" == "hpcloud" ]]; then
    configTestArgs_hpcloud
  elif [[ "$vendor" == "openstack" ]]; then
    configTestArgs_openstack
  else
    echo `date +"%Y-%m-%d %H:%M:%S"` "No LiveTest support for vendor [$vendor]"
    return -1
  fi
  return 0
}

# settings for HP Helion cloud account
configTestArgs_hpcloud() {
  helion_end_point="${HP_IDENTITY_URL:=https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/}"
  helion_projectId="${HP_TENANT_NAME:=Platform-AddIn-QA}"
  helion_accessKey="${HP_ACCESSKEY:=2ADR7XRPG76J8TZ5JJ1S}"
  helion_secretKey="${HP_SECRETKEY}"

  auth_url="${helion_end_point}"
  identity="${helion_projectId}:${helion_accessKey}"
  password="${helion_secretKey}"
}

# settings for openstack cloud account
configTestArgs_openstack() {
  auth_url="${OS_AUTH_URL:=$default_auth_url}"
  identity="${OS_TENANT_NAME:=$default_tenantId}:${OS_USERNAME:=$default_username}"
  password="${OS_PASSWORD:=$default_password}"
}

# parse configuration (pom.xml) and start running tests
# args:$1 - current working directory
#      $2 - base directory
configToRunTests() {
  local cwd=${1-$PWD}
  local cwd_base="${2-$PWD}"
  cd "${cwd}"
  if [[ -d "src" ]] && [[ -e "pom.xml" ]]; then
    count_projects=$(($count_projects + 1))
    local provider="${default_provider}"
    local rel_path="${cwd_base##*/}${cwd/$cwd_base/}"
    local endpoint="${auth_url}"
    echo ""
    echo `date +"%Y-%m-%d %H:%M:%S"` "Check project in ${rel_path} ..."
    while read -r line; do
      if [[ "${line}" =~ (\<test\.(.+)\.endpoint\>(.+)\</test\.(.+)\.endpoint\>) ]]; then
        if [[ "${BASH_REMATCH[2]}" != "${provider}" ]]; then
          printf -- "%20s--- provider: ${BASH_REMATCH[2]} [${cwd##*/}]\n" " "
          provider="${BASH_REMATCH[2]}"
        fi
      fi
    done < "pom.xml"
    runSuiteTests "${cwd}" "${endpoint}" "${provider}" "${cwd_base}"
  fi
}

# search tests recursively in specified directory
# args:$1 - current working directory
#      $2 - base directory
checkTests() {
  local dir_path="${1-$PWD}"
  local dir_base="${2-$PWD}"
  local has_test=""
  for item in "${dir_path}"/*; do
    if [[ -d "${item}" ]] && \
       [[ "${item##*/}" != "src" ]] && [[ "${item##*/}" != "target" ]]; then
      pushd "${item}" >/dev/null 2>&1 || break
      checkTests "${item}" "${dir_base}"
      popd >/dev/null 2>&1 || break
    fi
  done

  if [[ "${has_test}" == "" ]] && [[ -d "src" ]] && [[ -e "pom.xml" ]]; then
    has_test="true"
    configToRunTests "${dir_path}" "${dir_base}"
    echo "............................................................"
  fi
}

# parse output from test result and update test counters
# args:$1 - output result (multi-lined) from previous command
#      $2 - test suite name or live test (e.g. *LiveTest)
#      $3 - project name (e.g. hpcloud-compute)
parseOutput() {
  local output="$1"
  local counts=0 builds_failed=""
  local counts_bypass=0 counts_errors=0
  local counts_failed=0 counts_passed=0
  local IFS_SAVED=$IFS

  if [[ -f "${output}" ]]; then
    while read -r line && [[ "${counts}" == "0" ]]; do
      parseOutputCounters "${line}" "$2"
    done < "${output}"
  else
    while IFS='\n' read -r line && [[ "${counts}" == "0" ]]; do
      parseOutputCounters "${line}" "$2"
    done <<< "${output}"
  fi
  IFS=$IFS_SAVED

  local mvn_info=`[[ "${builds_failed}" == "" ]] && echo "SEE TEST RESULT:" || echo "BUILD FAILED ***"`
  if [[ "${builds_failed}" != "" ]] || [[ "${counts_failed}" != 0 ]]; then
    printf -- "%20s--- ${mvn_info}\n" " "
    echo "_______________________________________________________[TLDR]"
    if [[ -f "${output}" ]]; then cat "${output}"; else echo "${output}"; fi
    echo -e "[/TLDR]\n"
  fi

  # summarizing counts for final report
  exitcode=$(($exitcode + $counts_failed))
  if [[ "$2" =~ (LiveTest$) ]]; then
    local livetest_remark=`[[ "${counts_passed}" != "${counts}" ]] && echo " *"`
    names_livetest_failed="$3 : $2 [ $counts_passed + $counts_failed + $counts_errors : $counts ]${livetest_remark}\n${names_livetest_failed}"
    count_livetest=$(($count_livetest + $counts))
    count_livetest_bypass=$(($count_livetest_bypass + $counts_bypass))
    count_livetest_errors=$(($count_livetest_errors + $counts_errors))
    count_livetest_failed=$(($count_livetest_failed + $counts_failed))
    count_livetest_passed=$(($count_livetest_passed + $counts_passed))
  else
    count_unittest=$(($count_unittest + $counts))
    count_unittest_bypass=$(($count_unittest_bypass + $counts_bypass))
    count_unittest_errors=$(($count_unittest_errors + $counts_errors))
    count_unittest_failed=$(($count_unittest_failed + $counts_failed))
    count_unittest_passed=$(($count_unittest_passed + $counts_passed))
  fi
  if [[ "${builds_failed}" == "true" ]]; then
    names_mvnbuild_failed="${names_mvnbuild_failed}\n\t$3 - ${2/$3/}"
  fi
}

# parse output from test result and update test counters
# args:$1 - output result (multi-lined) from previous command
#      $2 - test suite name or live test (e.g. *LiveTest)
parseOutputCounters() {
  local regexp="Tests run: ([0-9]+), Failures: ([0-9]+), Errors: ([0-9]+), Skipped: ([0-9]+)"
  if [[ "${1}" =~ ($regexp) ]]; then
    # skipping zero counts
    if [[ "${BASH_REMATCH[2]}" == "0" ]]; then return; fi
    # calculating local counts
    counts="${BASH_REMATCH[2]}"
    counts_failed="${BASH_REMATCH[3]}"
    counts_errors="${BASH_REMATCH[4]}"
    counts_bypass="${BASH_REMATCH[5]}"
    counts_passed=$(($counts - $counts_failed))
    counts_passed=$(($counts_passed - $counts_errors))
    counts_passed=$(($counts_passed - $counts_bypass))
    local dd=`[[ "${counts_failed}" == "0" ]] && echo "---" || echo "***" `
    printf -- "%20s$dd %4s passed, %4s failed, %4s errors, %4s runs [%s] %s" \
    " " "${counts_passed}" "${counts_failed}" "${counts_errors}" "${counts}" \
    "$2" "${counts_bypass} skipped"; printf "\n"
  elif [[ "${1}" =~ (BUILD.FAILURE) ]]; then
    builds_failed="true"
  fi
}

# run unit tests and live tests for matched vendors
# args:$1 - current working directory
#      $2 - endpoint (e.g. https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/)
#      $3 - provider (e.g. openstack-keystone, hpcloud-compute)
#      $4 - base directory
runSuiteTests() {
  local cwd="${1-$PWD}"
  local rel_path="${4##*/}${cwd/$4/}"
  local provider="${3-$default_provider}"
  local endpoint="${2-$auth_url}"
  local m_vendor=""
  # checking supported vendors
  for v in ${vendors}; do
    if [[ "${rel_path}" =~ ($v) ]] || [[ "${rel_path}" =~ (${vendors}) ]]; then
      if configTestArgs_a_vendor "$v"; then
        endpoint="${auth_url}"
        m_vendor="$v"
        break;
      fi
    fi
  done

  if [[ "${m_vendor}" == "" ]] && [[ "${env_jenkins}" == "true" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "The unit tests are skipped on Jenkins."
    return
  fi

  cd "${cwd}"
  # run unit tests
  echo `date +"%Y-%m-%d %H:%M:%S"` "Run unit tests for ${rel_path} ..."
  local output_unittests="${output_file}"
  if [[ "${output_unittests}" == "" ]]; then
    output_unittests=$(mvn clean test 2>&1)
  else
    mvn clean test > "${output_unittests}" 2>&1
  fi
  parseOutput "${output_unittests}" "${cwd##*/}" "${provider}"

  if [[ "${m_vendor}" == "" ]]; then return; fi
  if [[ "${endpoint}" =~ (\$\{.+\}) ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "The live tests are skipped, "\
         "due to unset endpoint: ${endpoint}"
    return
  fi

  # run live tests
  local test_cmd="mvn -Plive test"
  local test_url="test.${provider}.endpoint=${endpoint}"
  local test_usr="test.${provider}.identity=${identity}"
  local test_pas="test.${provider}.credential=${password}"
  local test_arg="\"-D${test_url}\" \"-D${test_usr}\" \"-D${test_pas}\""
  local test_out="${output_file}"
  echo `date +"%Y-%m-%d %H:%M:%S"` "Run live tests for ${rel_path} ..."
  printf -- "%20s${test_cmd} ${test_arg}\n" " "
  for test in `find . -name *LiveTest.java`; do
    if [[ -f "$test" ]]; then
      local testname=$(basename ${test%.*})
      echo `date +"%Y-%m-%d %H:%M:%S"` "--- ${provider}::${testname} ---"
      local args="${test_arg} -Dtest=${testname}"
      count_livetest_jfiles=$(($count_livetest_jfiles + 1))
      if [[ "${test_out}" == "" ]]; then
        test_out=$(${test_cmd} ${args} 2>&1)
      else
        ${test_cmd} ${args} > "${test_out}" 2>&1
      fi
      parseOutput "${test_out}" "${testname}" "${cwd##*/}"
    fi
  done
}

# run summary reports
runSummary() {
  echo ""
  echo `date +"%Y-%m-%d %H:%M:%S"` "Cleaning up ..."
  # mvn clean > /dev/null
  if [[ "${output_file}" != "" ]]; then find . -name ${output_file} -delete; fi

  echo ""
  if [[ "${names_mvnbuild_failed}" != "" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Build Failures:"
    echo "------------------------------------------------------------"
    echo -e "${names_mvnbuild_failed}" | sort | grep -v '^$'; echo -e "\n"
  fi
  if [[ "${names_livetest_failed}" != "" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Live Tests [#pass + #fail + #err : #run]"
    echo "------------------------------------------------------------"
    echo -e "${names_livetest_failed}" | sort | grep -v '^$'; echo -e "\n"
  fi

  echo `date +"%Y-%m-%d %H:%M:%S"` "(*). Summary Reports"
  echo "============================================================"
  echo "               Projects: ${count_projects}"
  echo ""
  echo "         --- Live Tests: ${count_livetest}"
  echo "                  Files: ${count_livetest_jfiles}"
  echo "                Success: ${count_livetest_passed}"
  echo "                Skipped: ${count_livetest_bypass}"
  echo "                 Failed: ${count_livetest_failed}"
  echo "                 Errors: ${count_livetest_errors}"
  echo ""
  echo "         --- Unit Tests: ${count_unittest}"
  echo "                Success: ${count_unittest_passed}"
  echo "                Skipped: ${count_unittest_bypass}"
  echo "                 Failed: ${count_unittest_failed}"
  echo "                 Errors: ${count_unittest_errors}"
  echo ""
}

# run all/customized tests
buildupEnv ${script_args}
echo ""
echo `date +"%Y-%m-%d %H:%M:%S"` "(3). Run all/customized tests"
echo "============================================================"
checkTests "${PWD}" "${CWD_BASE}"
runSummary

echo "DONE: "`[[ "${exitcode}" == "0" ]] && echo "PASSED" || echo "FAILED (${exitcode})"`
exit ${exitcode}
