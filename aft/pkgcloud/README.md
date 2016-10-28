# pkgcloud test
------------------------------
This is a test project for <a href="https://github.com/pkgcloud/pkgcloud">pkgcloud</a>, a standard nodejs library that abstracts away differences among multiple cloud providers. The project is using <a href="https://github.com/pkgcloud/pkgcloud-integration-tests">pkgcloud-integration-tests</a> to simplify the API testing by using a single provider config. The devtest provides a test script (aft/pkgcloud/pkgcloud-test.sh) to run (mocha) unit tests and live tests against an openstack cloud account.

------------------------------
### Test Procedure
------------------------------
1. Build test environment
   1. Clone pkgcloud repository
   2. Clone pkgcloud-integration-tests repository
   3. Change to 'pkgcloud' folder
   4. Run `npm install`
      * Install additional reporters (see [Test Coverage](#test-coverage))
```bash
        npm install --upgrade mocha
        npm install mocha-cobertura-reporter
        npm install mocha-lcov-reporter
        npm install mocha-istanbul
        npm install istanbul
```
      * Note: How to run `npm install` without sudo
```
rm -rf "~/npm-local"
mkdir -p "~/npm-local/bin"
echo "prefix=~/npm-local" >> ~/.npmrc
export PATH=~/npm-local/bin:$PATH
```
   5. Run `make test` (for mocha unit tests)
   6. Change to 'pkgcloud-integration-tests' folder
   7. Run `npm link` (to pkgcloud)

2. Create cloud configuration
  - Create config file (if not existing)
  - Example of `config/hp.config.json`

```json
{
  "admin": {
    "username": "admin",
    "password": "1234567890123456789012345678901234567890",
    "provider": "hp",
    "strictSSL": false,
    "useInternal": true,
    "authUrl": "https://10.23.71.11:5000",
    "region": "regionOne"
  }
}
```

3. Run tests, e.g.
```bash
nodejs "lib/compute/floating-ips/getIps.js" hp
```


<a name="test-coverage"></a>
------------------------------
### Test Coverage
------------------------------
There are a few reporters can be used to generate test coverage. It requires to update `package.json` or install/update following modules -
```
npm install --upgrade mocha
npm install mocha-cobertura-reporter
npm install mocha-lcov-reporter
npm install mocha-istanbul
npm install istanbul
```
#### html-cov (html)
```
NODE_ENV=test MOCK=on ./node_modules/.bin/mocha --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js --reporter html-cov > reports/coverage.html
```

#### mocha-lcov-reporter (lcov)
```
NODE_ENV=test MOCK=on ./node_modules/.bin/mocha --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js --reporter mocha-lcov-reporter > reports/coverage.lcv
```

#### mocha-cobertura-reporter (cobertura)
```
NODE_ENV=test MOCK=on ./node_modules/.bin/mocha --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js --reporter mocha-cobertura-reporter > reports/coverage.xml
```

#### mocha-istanbul
```
# create test instrument
./node_modules/.bin/istanbul instrument --output lib-cov lib
# move original lib code and replace it by the instrumented one
mv lib lib-orig && mv lib-cov lib

# set istanbul reporters and run test
ISTANBUL_REPORTERS=lcovonly NODE_ENV=test MOCK=on ./node_modules/.bin/mocha --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js --reporter mocha-istanbul

# remove instrumented code and put back lib at its place
rm -rf lib && mv lib-orig lib
# place the lcov report in the report folder
cp -R lcov.info reports/coverage.lcv

```


------------------------------
### Integration Test with Coverage
------------------------------
For live/integratrion test, for each provider (e.g. "hp"), a live config (e.g. `test/configs/hp.json`) needs to be created as following -

```json
{
  "username": "admin",
  "password": "1234567890123456789012345678901234567890",
  "provider": "hp",
  "authUrl": "https://10.23.71.15:5000",
  "region": "regionOne"
}
```
And updated `test/configs/providers.json` to select which providers to be tested. Note: Even if a provider is not selected in `providers.json`, the live test still requires the config file present to continue the execution. The live test can run without `MOCK` set and generate a different lcov report (than the coverage for unit tests) -

```
NODE_ENV=test ./node_modules/.bin/mocha --require blanket -t 4000 test/*/*/*-test.js test/*/*/*/*-test.js --reporter mocha-lcov-reporter > reports/it-coverage.lcv
```


------------------------------
### SonarQube report
------------------------------
In order to publish test analysis to SonarQube dashboard, the `sonar-runner` needs to collect lcov info and send to the server.
#### 1. Configure project
  * create `sonar-project.properties` under project root with following content -

```bash
cat <<EOF > sonar-project.properties
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
```

#### 2. Run sonar analysis
```bash
# download sonar-runner
[ -d sonar ] || mkdir sonar
pushd sonar
curl -O http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/2.4/sonar-runner-dist-2.4.zip
unzip sonar-runner-dist-2.4.zip
popd

# configure sonar-runner
export SONAR_RUNNER_HOME="$(pwd)/sonar/sonar-runner-2.4"
cat <<EOF > $SONAR_RUNNER_HOME/conf/sonar-runner.properties
sonar.host.url=http://distillery.fc.hp.com:9000
sonar.jdbc.url=jdbc:mysql://distillery.fc.hp.com:3306/sonar?useUnicode=true&characterEncoding=utf8
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
EOF

# Run test with coverage (with lcov reporter)

# Invoke sonar-runner
$SONAR_RUNNER_HOME/bin/sonar-runner
unset SONAR_RUNNER_HOME
```

Note: Another example of `sonar-runner.properties` -
```
sonar.host.url=http://philj-ux1.fc.hp.com:9000
sonar.jdbc.url=jdbc:mysql://philj-ux1.fc.hp.com:3306/sonar?useUnicode=true&
characterEncoding=utf8
sonar.jdbc.username=sonar
sonar.jdbc.password=sonar
```



------------------------------
### Config Jenkins job
------------------------------
Compose the Build Command as below -
```
#!/bin/bash

rcfile="overcloud.stackrc"
cacert="ephemeralca-cacert.crt"
scparg="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# /root/devplat-install.sh -b  # update /root/configs/overcloud.stackrc
for dir in /root/configs; do
  if [[ ! -f "$cacert" ]] && [[ -f "$dir/$cacert" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Copying $dir/$cacert ..."
    scp ${scparg} root@localhost:$dir/$cacert .
    OS_CACERT="${WORKSPACE}/$cacert"
  fi
  if [[ ! -f "$rcfile" ]] && [[ -f "$dir/$rcfile" ]]; then
    echo `date +"%Y-%m-%d %H:%M:%S"` "Copying $dir/$rcfile ..."
    scp ${scparg} root@localhost:$dir/$rcfile .
    source "${WORKSPACE}/$rcfile"
  fi
done

env | grep OS_

rm -rf devtest
git clone git://git01-external.ae1.gozer.hpcloud.net/hp/devtest
cd ./devtest/aft/pkgcloud/
./pkgcloud-test.sh
```

------------------------------
### The list of pkgcloud API calls
------------------------------
```
lib/pkgcloud/openstack/blockstorage/client/snapshots.js
    getSnapshots
    getSnapshot
    updateSnapshot
    deleteSnapshot

lib/pkgcloud/openstack/blockstorage/client/volumes.js
    getVolumes
    getVolume
    createVolume
    updateVolume
    deleteVolume

lib/pkgcloud/openstack/blockstorage/client/volumetypes.js
    getVolumeType

lib/pkgcloud/openstack/computeClient.js
  getVersion
  getLimits (*)

lib/pkgcloud/openstack/compute/client/extensions/floating-ips.js
  getFloatingIps
  dellocateFloatingIp
  addFloatingIp
  removeFloatingIp

lib/pkgcloud/openstack/compute/client/extensions/keys.js
  listKeys
  addKey
  destroyKey
  getKey

lib/pkgcloud/openstack/compute/client/extensions/network-base.js
  getNetwork
  getNetworks
  createNetwork
  addNetwork
  addNetworkToHost (*)
  removeNetworkFromHost (*)
  disassociateNetworkFromProject (*)
  disassociateProjectFromNetwork (*)
  deleteNetwork

lib/pkgcloud/openstack/compute/client/extensions/servers.js
  startServer (*)
  stopServer (*)

lib/pkgcloud/openstack/compute/client/extensions/volume-attachments.js
    getVolumeAttachmentDetails
    attachVolume

lib/pkgcloud/openstack/compute/client/flavors.js
  getFlavors
  getFlavor

lib/pkgcloud/openstack/compute/client/images.js
  getImages
  getImage
  createImage
  destroyImage
  updateImageMeta (*)

lib/pkgcloud/openstack/compute/client/servers.js
  getServers
  getServer
  createServer
  destroyServer
  rebootServer (*)
  rebuildServer (*)
  resizeServer (*)
  confirmServerResize (*)
  revertServerResize (*)
  renameServer (*)
  getServerAddresses (*)

lib/pkgcloud/openstack/network/client/network.js
  getNetworks
  getNetwork
  createNetwork
  updateNetwork
  destroyNetwork

lib/pkgcloud/openstack/network/client/ports.js
  getPorts
  getPort
  createPort
  updatePort
  destroyPort

lib/pkgcloud/openstack/network/client/securityGroupRules.js
  getSecurityGroupRules (*)
  getSecurityGroupRule (*)
  createSecurityGroupRule (*)
  destroySecurityGroupRule (*)

lib/pkgcloud/openstack/network/client/securityGroups.js
  getSecurityGroups
  getSecurityGroup
  createSecurityGroup
  destroySecurityGroup

lib/pkgcloud/openstack/network/client/subnets.js
  getSubnets
  getSubnet
  createSubnet
  destroySubnet

lib/pkgcloud/openstack/orchestration/client/events.js
    getEvent
    getResourceEvents

lib/pkgcloud/openstack/orchestration/client/resources.js
    getResource
    getResources
    getResourceTypes
    getResourceSchema
    getResourceTemplate

lib/pkgcloud/openstack/orchestration/client/stacks.js
    getStack
    getStacks
    createStack
    previewStack
    adoptStack
    updateStack
    deleteStack
    abandonStack

lib/pkgcloud/openstack/orchestration/client/templates.js
    getTemplate
    validateTemplate

lib/pkgcloud/openstack/storage/client/containers.js
  getContainers
  getContainer
  createContainer
  updateContainerMetadata (*)
  removeContainerMetadata (*)
  destroyContainer

lib/pkgcloud/openstack/storage/client/files.js
  removeFile
  upload
  download
  getFile
  getFiles
  updateFileMetadata (*)
  copy (*)
```
