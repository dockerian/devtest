# change to script directory
echo `date +"%Y-%m-%d %H:%M:%S"` "Start sonar report for jclouds"
echo "------------------------------------------------------------"
cd ${BASH_SOURCE[0]%/*}
echo "PWD= $(pwd)"

# git clone sdk source
rm -rf jclouds
git clone https://github.com/jclouds/jclouds.git
cd jclouds

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

# configure maven settings
local backup_settings="false"

if [[ -f "~/.m2/settings.xml" ]]; then
	cp -R ~/.m2/settings.xml ~/.m2/settings.backup.xml
	backup_settings="true"
fi

mkdir -p ~/.m2
cp -R ../settings.hp.xml ~/.m2/settings.xml

# configure maven projects
cp -R ../project.pom.xml project/pom.xml
cp -R ../pom.xml pom.xml

# run unit tests and sonar report
mvn clean test
mvn sonar:sonar

if [[ "${backup_settings}" == "true" ]]; then
	cp -R ~/.m2/settings.backup.xml ~/.m2/settings.xml
fi

unset SONAR_RUNNER_HOME
cd ..
echo "------------------------------------------------------------"
echo `date +"%Y-%m-%d %H:%M:%S"` "DONE."
