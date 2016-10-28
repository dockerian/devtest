# fog test
------------------------------
This is a test project for <a href="https://github.com/fog/fog">fog</a>, the Ruby cloud services library. The devtest provides a test script (`aft/fog/fog-test.sh`) to run (shindo and minitest/Rspec) unit tests and live tests against hp cloud and openstack cloud account.


------------------------------
### How To Run Unit Tests
------------------------------
In `fog` folder (with `lib`, `tests`, and `Rakefile`), run
```
rake test
```
or run mock test for a specific provider (e.g. "hp")
```
rake mock[hp]
```


------------------------------
### How To Run Live Tests
------------------------------
1. Create `tests/.fog` configuration file, as following example
```yaml
#######################################################
# Settings for Fog Live Tests
#
:default:
  :hp_auth_uri: https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/
  :hp_auth_version: v2.0
  :hp_use_upass_auth_style: false
  :hp_avl_zone: region-a.geo-1
  :hp_access_key: 2ADR7XRPG76J8TZ5JJ1S
  :hp_secret_key: BXeT4Dd52uW3NHaEsfwnwYFf3c72UU1uAQyvdrzu
  :hp_tenant_name: Platform-AddIn-QA
  :hp_tenant_id: 10804896732690
  :public_key_path: ~/.ssh/id_rsa
  :private_key_path: ~/.ssh/id_rsa.pub
  :openstack_api_key: 1234567890123456789012345678901234567890
  :openstack_username: admin
  :openstack_auth_url: https://10.23.71.16:5000/v2.0/tokens
  :openstack_tenant: admin
  :openstack_region: regionOne
  :ssl_verify_peer: false
  connection_options:
    ssl_verify_peer: false
  mock: false
#
# End of Fog Live Tests Settings
#######################################################
```
Note:
  * if "hp_use_upass_auth_style" is true, "hp_access_key" will be the user name, and "hp_secret_key" will be the password.
  * The "ssl_verify_peer" (under "connection_options") is set to ignore certificate (less secure but useful with Jenkins job).

2. In `fog` folder (with `lib`, `tests`, and `Rakefile`), run live test for specific provider (e.g. "openstack")
```
rake live[openstack]
```

3. To run a specific test, with PROVIDER specified, use `shindont` to call a ruby test
```
export FOG_MOCK=false PROVIDER=openstack && bundle exec shindont tests/openstack/models/compute/images_tests.rb
```
or (for hp provider)
```
export FOG_MOCK=false PROVIDER=hp && bundle exec shindont tests/hp/compute_tests.rb
```


------------------------------
### Generate Test Coverage Report (HTML)
------------------------------
1. Install `simplecov` and `coco` (see https://github.com/lkdjiin/coco)
```bash
sudo gem install coco
sudo gem install simplecov
sudo gem install simplecov-rcov
```
2. Add `gem "simplecov"` and `gem "simplecov-rcov"` to Gemfile
```ruby
gem "coco"
gem 'simplecov'
gem 'simplecov-rcov'
```
3. Change `spec/spec_helper.rb` (at beginning or before "fog")
```ruby
require "simplecov"
require 'simplecov-rcov'
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
```
4. Add `.coco.yml` to project root
```yaml
  :directories:
  - lib/fog/hp
  :excludes:
  - bin
  - spec
  - config/initializers
  - tests
  :always_run: true
  :exclude_above_threshold: false
  :show_link_in_terminal: true
  :single_line_report: true
```
5. Run unit test with coverage -
```bash
COVERAGE=on rake test
```
6. Open report -
```bash
open coverage/rcov/index.html # rcov style
```
or (simple format)
```bash
open coverage/index.html # simplecov
```


------------------------------
### Generate Test Coverage Report (XML and Sonar)
------------------------------
#### I. Add Sonar Ruby Plugin on SonarQube server (by Administrator)
------------------------------
1. Build ruby-sonar-plugin
```bash
git clone https://github.com/GoDaddy-Hosting/ruby-sonar-plugin.git
cd ruby-sonar-plugin
mvn clean install
```
2. Add Sonar Ruby Plugin to SonarQube (e.g. on distillery server)
```bash
# assume ruby-sonar-plugin project is in current folder
# assume sonarqube is in /var/lib/sonarqube [linux-x86-64]
cp target/sonar-ruby-plugin-1.0.1.jar /var/lib/sonarqube/extensions/plugins
/var/lib/sonarqube-5.1.2/bin/linux-x86-64/sonar.sh restart
```
3. Verify plugin in Settings::System::Update Center
  * Sonar Ruby Plugin [ruby] 1.0.1
4. Add a quality profile
   * Login as Administrator
   * Select "Qulity Profiles" and look into "Ruby Profiles" section
   * Click on "+Create" to add a new profile if no profile exists for Ruby
   * Set the profile as "DEFAULT"

------------------------------
#### II. Configure cobertura
1. Install `simplecov` and `simplecov-cobertura`
```bash
sudo gem install simplecov
sudo gem install simplecov-cobertura
```
2. Add `gem "simplecov"` to Gemfile
```ruby
gem 'simplecov'
gem 'simplecov-cobertura'
```
3. Change `spec/spec_helper.rb` (at beginning or before "fog")
```ruby
require "simplecov"
require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
```
4. Run unit test with coverage for the project -
```bash
bundle update
COVERAGE=on rake test
```
5. Locate the cobertura report -
```bash
open coverage/coverage.xml # cobertura
```

------------------------------
#### III. Run Sonar Report
1. Add `sonar-project.properties` to project directory
```bash
cat <<EOF > sonar-project.properties
sonar.projectKey=github:fog
sonar.projectName=Openstack SDK - fog
sonar.projectVersion=master
sonar.branch=master
sonar.sourceEncoding=UTF-8
sonar.language=ruby

sonar.sources=lib/fog
sonar.tests=tests

sonar.cobertura.reportPath=coverage
EOF
```
2. Download sonar-runner and run sonar analysis
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

# Invoke sonar-runner
$SONAR_RUNNER_HOME/bin/sonar-runner
unset SONAR_RUNNER_HOME
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

for dir in /root/configs /; do
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
cd ./devtest/aft/fog/
./fog-test.sh
```


------------------------------
### Test Procedure (fog-test.sh)
------------------------------
  1. Check fog path in $PWD
  2. Clone fog repository, or cd to existing fog project
  3. Download mpapis public key, install rvm and ruby dependencies
  4. Configure tests/.fog for live tests
  5. Run unit tests, then live tests (if available) recursively
  6. Print test summary report


------------------------------
### The list of tests for HP and Openstack
------------------------------
```
tests/hp/block_storage_tests.rb
tests/hp/cdn_tests.rb
tests/hp/compute_tests.rb
tests/hp/models/block_storage/bootable_volume_tests.rb
tests/hp/models/block_storage/snapshot_tests.rb
tests/hp/models/block_storage/volume_tests.rb
tests/hp/models/block_storage_v2/snapshot_tests.rb
tests/hp/models/block_storage_v2/snapshots_tests.rb
tests/hp/models/block_storage_v2/volume_backup_tests.rb
tests/hp/models/block_storage_v2/volume_backups_tests.rb
tests/hp/models/block_storage_v2/volume_tests.rb
tests/hp/models/block_storage_v2/volumes_tests.rb
tests/hp/models/compute/address_tests.rb
tests/hp/models/compute/addresses_tests.rb
tests/hp/models/compute/key_pair_tests.rb
tests/hp/models/compute/key_pairs_tests.rb
tests/hp/models/compute/metadata_image_tests.rb
tests/hp/models/compute/metadata_server_tests.rb
tests/hp/models/compute/security_group_tests.rb
tests/hp/models/compute/security_groups_tests.rb
tests/hp/models/compute_v2/address_tests.rb
tests/hp/models/compute_v2/addresses_tests.rb
tests/hp/models/compute_v2/availability_zone_tests.rb
tests/hp/models/compute_v2/availability_zones_tests.rb
tests/hp/models/compute_v2/key_pair_tests.rb
tests/hp/models/compute_v2/key_pairs_tests.rb
tests/hp/models/compute_v2/metadata_image_tests.rb
tests/hp/models/compute_v2/metadata_server_tests.rb
tests/hp/models/compute_v2/server_tests.rb
tests/hp/models/compute_v2/servers_tests.rb
tests/hp/models/compute_v2/volume_attachment_tests.rb
tests/hp/models/compute_v2/volume_attachments_tests.rb
tests/hp/models/dns/domain_tests.rb
tests/hp/models/dns/domains_tests.rb
tests/hp/models/dns/record_tests.rb
tests/hp/models/dns/records_tests.rb
tests/hp/models/lb/algorithms_tests.rb
tests/hp/models/lb/load_balancer_node_tests.rb
tests/hp/models/lb/load_balancer_nodes_tests.rb
tests/hp/models/lb/load_balancer_tests.rb
tests/hp/models/lb/load_balancer_virtual_ips_tests.rb
tests/hp/models/lb/load_balancers_tests.rb
tests/hp/models/lb/protocols_tests.rb
tests/hp/models/network/floating_ip_tests.rb
tests/hp/models/network/floating_ips_tests.rb
tests/hp/models/network/network_tests.rb
tests/hp/models/network/networks_tests.rb
tests/hp/models/network/port_tests.rb
tests/hp/models/network/ports_tests.rb
tests/hp/models/network/router_tests.rb
tests/hp/models/network/routers_tests.rb
tests/hp/models/network/security_group_rule_tests.rb
tests/hp/models/network/security_group_rules_tests.rb
tests/hp/models/network/security_group_tests.rb
tests/hp/models/network/security_groups_tests.rb
tests/hp/models/network/subnet_tests.rb
tests/hp/models/network/subnets_tests.rb
tests/hp/models/storage/directories_tests.rb
tests/hp/models/storage/directory_tests.rb
tests/hp/models/storage/file_tests.rb
tests/hp/models/storage/files_tests.rb
tests/hp/requests/block_storage/bootable_volume_tests.rb
tests/hp/requests/block_storage/snapshot_tests.rb
tests/hp/requests/block_storage/volume_tests.rb
tests/hp/requests/block_storage_v2/snapshot_tests.rb
tests/hp/requests/block_storage_v2/volume_backup_tests.rb
tests/hp/requests/block_storage_v2/volume_tests.rb
tests/hp/requests/cdn/container_tests.rb
tests/hp/requests/compute/address_tests.rb
tests/hp/requests/compute/flavor_tests.rb
tests/hp/requests/compute/image_tests.rb
tests/hp/requests/compute/key_pair_tests.rb
tests/hp/requests/compute/metadata_tests.rb
tests/hp/requests/compute/persistent_server_tests.rb
tests/hp/requests/compute/security_group_rule_tests.rb
tests/hp/requests/compute/security_group_tests.rb
tests/hp/requests/compute/server_address_tests.rb
tests/hp/requests/compute/server_tests.rb
tests/hp/requests/compute/server_volume_tests.rb
tests/hp/requests/compute_v2/address_tests.rb
tests/hp/requests/compute_v2/availability_zone_tests.rb
tests/hp/requests/compute_v2/flavor_tests.rb
tests/hp/requests/compute_v2/image_tests.rb
tests/hp/requests/compute_v2/key_pair_tests.rb
tests/hp/requests/compute_v2/metadata_tests.rb
tests/hp/requests/compute_v2/persistent_server_tests.rb
tests/hp/requests/compute_v2/server_address_tests.rb
tests/hp/requests/compute_v2/server_security_group_tests.rb
tests/hp/requests/compute_v2/server_tests.rb
tests/hp/requests/compute_v2/server_volume_tests.rb
tests/hp/requests/dns/domain_tests.rb
tests/hp/requests/dns/records_tests.rb
tests/hp/requests/lb/algorithms_tests.rb
tests/hp/requests/lb/limits_tests.rb
tests/hp/requests/lb/load_balancer_nodes_tests.rb
tests/hp/requests/lb/load_balancer_tests.rb
tests/hp/requests/lb/protocols_tests.rb
tests/hp/requests/lb/versions_tests.rb
tests/hp/requests/lb/virtual_ips_tests.rb
tests/hp/requests/network/floating_ip_tests.rb
tests/hp/requests/network/network_tests.rb
tests/hp/requests/network/port_tests.rb
tests/hp/requests/network/router_tests.rb
tests/hp/requests/network/security_group_rule_tests.rb
tests/hp/requests/network/security_group_tests.rb
tests/hp/requests/network/subnet_tests.rb
tests/hp/requests/storage/container_tests.rb
tests/hp/requests/storage/object_tests.rb
tests/hp/storage_tests.rb
tests/hp/user_agent_tests.rb

tests/openstack/authenticate_tests.rb
tests/openstack/models/compute/images_tests.rb
tests/openstack/models/compute/security_group_tests.rb
tests/openstack/models/compute/server_tests.rb
tests/openstack/models/identity/ec2_credential_tests.rb
tests/openstack/models/identity/ec2_credentials_tests.rb
tests/openstack/models/identity/role_tests.rb
tests/openstack/models/identity/roles_tests.rb
tests/openstack/models/identity/tenant_tests.rb
tests/openstack/models/identity/tenants_tests.rb
tests/openstack/models/identity/user_tests.rb
tests/openstack/models/identity/users_tests.rb
tests/openstack/models/image/image_tests.rb
tests/openstack/models/image/images_tests.rb
tests/openstack/models/network/floating_ip_tests.rb
tests/openstack/models/network/floating_ips_tests.rb
tests/openstack/models/network/lb_health_monitor_tests.rb
tests/openstack/models/network/lb_health_monitors_tests.rb
tests/openstack/models/network/lb_member_tests.rb
tests/openstack/models/network/lb_members_tests.rb
tests/openstack/models/network/lb_pool_tests.rb
tests/openstack/models/network/lb_pools_tests.rb
tests/openstack/models/network/lb_vip_tests.rb
tests/openstack/models/network/lb_vips_tests.rb
tests/openstack/models/network/network_tests.rb
tests/openstack/models/network/networks_tests.rb
tests/openstack/models/network/port_tests.rb
tests/openstack/models/network/ports_tests.rb
tests/openstack/models/network/router_tests.rb
tests/openstack/models/network/routers_tests.rb
tests/openstack/models/network/security_group_rule_tests.rb
tests/openstack/models/network/security_group_rules_tests.rb
tests/openstack/models/network/security_group_tests.rb
tests/openstack/models/network/security_groups_tests.rb
tests/openstack/models/network/subnet_tests.rb
tests/openstack/models/network/subnets_tests.rb
tests/openstack/models/planning/plan_tests.rb
tests/openstack/models/planning/plans_tests.rb
tests/openstack/models/planning/role_tests.rb
tests/openstack/models/storage/file_tests.rb
tests/openstack/requests/baremetal/chassis_tests.rb
tests/openstack/requests/baremetal/driver_tests.rb
tests/openstack/requests/baremetal/node_tests.rb
tests/openstack/requests/baremetal/port_tests.rb
tests/openstack/requests/compute/address_tests.rb
tests/openstack/requests/compute/aggregate_tests.rb
tests/openstack/requests/compute/availability_zone_tests.rb
tests/openstack/requests/compute/flavor_tests.rb
tests/openstack/requests/compute/image_tests.rb
tests/openstack/requests/compute/keypair_tests.rb
tests/openstack/requests/compute/limit_tests.rb
tests/openstack/requests/compute/quota_tests.rb
tests/openstack/requests/compute/security_group_tests.rb
tests/openstack/requests/compute/server_tests.rb
tests/openstack/requests/compute/service_tests.rb
tests/openstack/requests/compute/tenant_tests.rb
tests/openstack/requests/compute/volume_tests.rb
tests/openstack/requests/identity/ec2_credentials_tests.rb
tests/openstack/requests/identity/role_tests.rb
tests/openstack/requests/identity/tenant_tests.rb
tests/openstack/requests/identity/user_tests.rb
tests/openstack/requests/image/image_tests.rb
tests/openstack/requests/metering/meter_tests.rb
tests/openstack/requests/metering/resource_tests.rb
tests/openstack/requests/network/lb_health_monitor_tests.rb
tests/openstack/requests/network/lb_member_tests.rb
tests/openstack/requests/network/lb_pool_tests.rb
tests/openstack/requests/network/lb_vip_tests.rb
tests/openstack/requests/network/network_tests.rb
tests/openstack/requests/network/port_tests.rb
tests/openstack/requests/network/quota_tests.rb
tests/openstack/requests/network/router_tests.rb
tests/openstack/requests/network/security_group_rule_tests.rb
tests/openstack/requests/network/security_group_tests.rb
tests/openstack/requests/network/subnet_tests.rb
tests/openstack/requests/orchestration/stack_tests.rb
tests/openstack/requests/planning/plan_tests.rb
tests/openstack/requests/planning/role_tests.rb
tests/openstack/requests/storage/container_tests.rb
tests/openstack/requests/storage/large_object_tests.rb
tests/openstack/requests/storage/object_tests.rb
tests/openstack/requests/volume/availability_zone_tests.rb
tests/openstack/requests/volume/quota_tests.rb
tests/openstack/storage_tests.rb
tests/openstack/version_tests.rb
tests/openstack/volume_tests.rb
```
