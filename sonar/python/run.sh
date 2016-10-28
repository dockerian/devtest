# git clone sdk source
rm -rf python-openstacksdk
git clone https://github.com/stackforge/python-openstacksdk.git
cd python-openstacksdk

# download sonar-runner
rm -rf sonar-temp && mkdir sonar-temp
pushd sonar-temp
curl -O http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/2.4/sonar-runner-dist-2.4.zip
unzip sonar-runner-dist-2.4.zip
popd

# configure sonar-runner
export SONAR_RUNNER_HOME="$(pwd)/sonar-temp/sonar-runner-2.4"
cat << EOF > ${SONAR_RUNNER_HOME}/conf/sonar-runner.properties
sonar.host.url=http://localhost:9000
sonar.jdbc.url=jdbc:mysql://localhost:3307/sonar?useUnicode=true&characterEncoding=utf8
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
sonar.login=admin
sonar.password=admin
EOF

cat << EOF > ${SONAR_RUNNER_HOME}/conf/sonar-runner.properties
sonar.host.url=http://distillery.fc.hp.com:9000
sonar.jdbc.url=jdbc:mysql://distillery.fc.hp.com:3306/sonar?useUnicode=true&characterEncoding=utf8
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
EOF

# configure sonar project
cat << EOF > sonar-project.properties
sonar.projectKey=github:openstacksdk
sonar.projectName=OpenStack SDK - python
sonar.projectVersion=1.0

# Path is relative to the sonar-project.properties file.
sonar.sources=openstack
sonar.language=py

# Encoding of the source code. Default is default system encoding
sonar.sourceEncoding=UTF-8

sonar.dynamicAnalysis=reuseReports
sonar.core.codeCoveragePlugin=cobertura
sonar.python.coverage.reportPath=coverage.xml
EOF

# create virtual environment
virtualenv .venv && source .venv/bin/activate

# install python modules
pip install -r requirements.txt
pip install coverage
pip install fixtures
pip install mock
pip install requests_mock
pip install testtools
pip install --upgrade setuptools
pip install --upgrade distribute
pip install nose

# run tests with coverage
coverage run `which nosetests`
coverage report --omit=".venv/*" # printing out to stdout
coverage xml --omit=".venv/*" # generating coverage.xml
deactivate

$SONAR_RUNNER_HOME/bin/sonar-runner
unset SONAR_RUNNER_HOME
