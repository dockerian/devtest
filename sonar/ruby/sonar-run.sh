# change to script directory
echo `date +"%Y-%m-%d %H:%M:%S"` "Start sonar report for fog"
echo "------------------------------------------------------------"
cd ${BASH_SOURCE[0]%/*}
echo "PWD= $(pwd)"

# git clone sdk source
rm -rf fog
git clone https://github.com/fog/fog.git
cd fog

bundle update

# add and configure simplecov
mv Gemfile Gemfile.org
mv spec/spec_helper.rb spec/spec_helper.rb.org

cat << EOF > Gemfile
gem 'simplecov'
gem 'simplecov-cobertura'
EOF

cat Gemfile.org >> Gemfile

cat << EOF > spec/spec_helper.rb
require "simplecov"
require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
EOF

cat spec/spec_helper.rb.org >> spec/spec_helper.rb

cat << EOF > sonar-project.properties
sonar.projectKey=github:fog
sonar.projectName=Openstack SDK - fog
sonar.projectVersion=master
sonar.branch=master

sonar.language=ruby
sonar.sourceEncoding=UTF-8

sonar.exclusions=spec
sonar.cobertura.reportPath=coverage
sonar.sources=lib/fog/hp,lib/fog/openstack,lib/fog/bin,lib/fog/core
sonar.tests=tests
# sonar.modules=hp,openstack
# openstack.sonar.projectBaseDir=lib/fog/openstack
# openstack.sonar.projectName=Openstack SDK - fog :: openstack
# openstack.sonar.cobertura.reportPath=coverage
# openstack.sonar.sources=.
# hp.sonar.projectBaseDir=lib/fog/hp
# hp.sonar.projectName=Openstack SDK - fog :: hp
# hp.sonar.cobertura.reportPath=coverage
# hp.sonar.sources=.
EOF

# run unit tests and sonar report
COVERAGE=on rake test

# download sonar-runner
rm -rf sonar-temp && mkdir sonar-temp
pushd sonar-temp
curl -O http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/2.4/sonar-runner-dist-2.4.zip
unzip sonar-runner-dist-2.4.zip
popd

# configure sonar-runner
export SONAR_RUNNER_HOME="$(pwd)/sonar-temp/sonar-runner-2.4"

cat << EOF > ${SONAR_RUNNER_HOME}/conf/sonar-runner.properties
sonar.host.url=http://distillery.fc.hp.com:9000
sonar.jdbc.url=jdbc:mysql://distillery.fc.hp.com:3306/sonar?useUnicode=true&characterEncoding=utf8
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
EOF

$SONAR_RUNNER_HOME/bin/sonar-runner
unset SONAR_RUNNER_HOME
cd ..
echo ""
echo `date +"%Y-%m-%d %H:%M:%S"` "DONE."
