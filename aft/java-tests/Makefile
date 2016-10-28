#
# Basic jclouds test for openstack
# See https://jclouds.apache.org/guides/openstack/
#
GDEBUG = -g
JFLAGS = -classpath ".:lib/*"
JCLASS = JCloudsNovaTest
JCC = javac
RUN = java
MVN = mvn

default: test

build: clean mvn_jclouds
	@echo ""
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Compiling *.java ..."
	$(JCC) $(GDEBUG):none $(JFLAGS) *.java

build_debug: clean mvn_jclouds
	@echo ""
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Compiling *.java [with debug info] ..."
	$(JCC) $(GDEBUG) $(JFLAGS) *.java

clean:
	@echo ""
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Cleaning up ..."
	$(RM) *.class
	$(RM) -rf lib

debug: build_debug
	@echo ""
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Run $(JCLASS) ..."
	$(RUN) $(JFLAGS) $(JCLASS)
	@echo ""
	@echo "DONE [$@]."

mvn_jclouds:
	@echo ""
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Building jclouds lib ..."
	$(MVN) dependency:copy-dependencies "-DoutputDirectory=./lib"

test: build
	@echo ""
	@echo `date +"%Y-%m-%d %H:%M:%S"` "Run ..."
	$(RUN) $(JFLAGS) $(JCLASS)
	@echo ""
	@echo "DONE [$@]."
