# JClouds Test Examples
----------------------------------------

This project is created as a simple example of using Apache jclouds accessing openstack API service.

For more complete tests (including unit tests and live tests), see devtest/aft/jclouds.

----------------------------------------
## How To Use
----------------------------------------
```bash
# Download OpenStack RC file from openstack "Access & Security"
source openrc.sh

# Run test
make test # or `make debug` for debug mode

# Clean up
make clean

```
