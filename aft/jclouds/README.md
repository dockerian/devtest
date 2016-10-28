# jclouds test
------------------------------
This is a test project for <a href="https://github.com/jclouds/jclouds">jclouds</a>, an open source multi-cloud toolkit for the Java platform in order to create portable applications across clouds and to use cloud-specific features. The devtest provides a test script (aft/jclouds/jclouds-test.sh) to run (TestNG) unit tests and live tests against hp cloud and openstack cloud account.


------------------------------
### Test Procedure (jclouds-test.sh)
------------------------------
  1. Check jclouds path in $PWD
  2. Clone jclouds repository, or cd to existing jclouds project
  3. Configure maven settings if proxy is used
  4. Configure test arguments
  5. Run unit tests, then live tests (if available) recursively
  6. Print test summary report


------------------------------
### How To Run Unit Tests
------------------------------
In any jclouds project folder (with `src` and `pom.xml`), run
```
mvn clean install
```


------------------------------
### How To Run Live Tests
------------------------------
In a jclouds project folder (with `src` and `pom.xml`, e.g. `apis/openstack-keystone`), run
```
mvn -Plive clean install "-Dtest.openstack-keystone.endpoint=https://10.23.71.11:5000/v2.0" "-Dtest.openstack-keystone.identity=admin:admin" "-Dtest.openstack-keystone.credential=password"
```
or in `providers/hpcloud-compute`, run
```
mvn -Plive clean install "-Dtest.hpcloud-compute.api-version=2.0" "-Dtest.hpcloud-compute.endpoint=https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/" "-Dtest.hpcloud-compute.identity=tenant_name:accessKey" "-Dtest.hpcloud-compute.credential=secreteKey"
```

------------------------------
### Sonar Test Coverage (with `jacoco` plugin)
------------------------------
1. Add a "sonar" profile in ``~/.m2/settings.xml` or `project/pom.xml`
```json
<profile>
    <id>sonar</id>
    <activation>
        <activeByDefault>true</activeByDefault>
    </activation>
    <properties>
        <sonar.jdbc.url>jdbc:mysql://distillery.fc.hp.com:3306/sonar?</sonar.jdbc.url>
        <sonar.jdbc.username>sonar</sonar.jdbc.username>
        <sonar.jdbc.password>sonar</sonar.jdbc.password>
        <sonar.host.url>http://distillery.fc.hp.com:9000</sonar.host.url>
    </properties>
</profile>
```
2. Add `jacoco` plugin to `project/pom.xml`, under build/plugins segment
```json
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.7.4.201502262128</version>
    <executions>
        <execution>
            <id>default-prepare-agent</id>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <execution>
            <id>default-report</id>
            <phase>prepare-package</phase>
            <goals><goal>report</goal></goals>
        </execution>
        <execution>
          <id>prepare-integration-test-agent</id>
          <goals><goal>prepare-agent-integration</goal></goals>
        </execution>
        <execution>
          <id>generate-integration-test-report</id>
          <goals><goal>report-integration</goal></goals>
        </execution>
    </executions>
</plugin>
```
3. Run maven in command line
```bash
  mvn clean install  # or `mvn clean test` and `mvn -Plive test`
  mvn sonar:sonar
```


------------------------------
### The project list of jclouds LiveTests
------------------------------
```
./apis/atmos
./apis/byon
./apis/chef
./apis/cloudstack
./apis/cloudwatch
./apis/ec2
./apis/elasticstack
./apis/oauth
./apis/openstack-cinder
./apis/openstack-keystone
./apis/openstack-nova
./apis/openstack-swift
./apis/openstack-trove
./apis/rackspace-clouddns
./apis/rackspace-cloudfiles
./apis/rackspace-cloudidentity
./apis/rackspace-cloudloadbalancers
./apis/route53
./apis/s3
./apis/sqs
./apis/swift

./blobstore
./compute
./core
./drivers
./loadbalancer

./providers/aws-cloudwatch
./providers/aws-ec2
./providers/aws-route53
./providers/aws-s3
./providers/aws-sqs
./providers/azureblob
./providers/dynect
./providers/elastichosts-ams-e
./providers/elastichosts-hkg-e
./providers/elastichosts-lax-p
./providers/elastichosts-lon-b
./providers/elastichosts-sat-p
./providers/elastichosts-sjc-c
./providers/elastichosts-tor-p
./providers/enterprisechef
./providers/glesys
./providers/go2cloud-jhb1
./providers/gogrid
./providers/google-compute-engine
./providers/hpcloud-blockstorage
./providers/hpcloud-compute
./providers/hpcloud-objectstorage
./providers/openhosting-east1
./providers/rackspace-cloudblockstorage-uk
./providers/rackspace-cloudblockstorage-us
./providers/rackspace-clouddatabases-uk
./providers/rackspace-clouddatabases-us
./providers/rackspace-clouddns-uk
./providers/rackspace-clouddns-us
./providers/rackspace-cloudfiles-uk
./providers/rackspace-cloudfiles-us
./providers/rackspace-cloudloadbalancers-uk
./providers/rackspace-cloudloadbalancers-us
./providers/rackspace-cloudservers-uk
./providers/rackspace-cloudservers-us
./providers/serverlove-z1-man
./providers/skalicloud-sdg-my
./providers/softlayer
./providers/ultradns-ws

./skeletons/standalone-compute

```
