#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# script runs in 3 modes - build / run / clean

set -e
tag=nightly
docker_os=ubuntu
build_type=full
package=jdk
command_type=build
version=8
impl=hotspot
test=derby
testtarget=""
reportdst="false"
reportsrc="false"
docker_args=""

usage () {
	echo 'Usage : external.sh  --dir TESTDIR --tag DOCKERIMAGE_TAG --version JDK_VERSION --impl JDK_IMPL [--reportsrc appReportDir] [--reportdst REPORTDIR] [--testtarget target] [--docker_args EXTRA_DOCKER_ARGS] [--build|--run|--clean]'
}

parseCommandLineArgs() {
	while [[ $# -gt 0 ]] && [[ ."$1" = .-* ]] ; do
		opt="$1";
		shift; 

		case "$opt" in
			"--dir" | "-d" )
				test="$1"; shift;;
			
			"--version" | "-v" )
				version="$1"; shift;;
			
			"--impl" | "-i" )
				impl="$1"; shift;;

			"--docker_args" )
				if [ -z ${1+x} ]; then 
					echo "No EXTRA_DOCKER_ARGS set"; 
				else 
  					docker_args="--rm $1"; shift;
				fi;;
				
			"--tag" | "-t" )
				if [ -z "$1" ]; then 
					echo "No DOCKERIMAGE_TAG set, tag as default 'nightly'"; 
				else 
  					tag="$1";
				fi
				shift;
				parse_tag;;

			"--reportsrc" )
				reportsrc="$1"; shift;;

			"--reportdst" )
				reportdst="$1"; shift;;

			"--testtarget" )
				testtarget="$1"; shift;;

			"--build" | "-b" )
				command_type=build;; 

			"--run" | "-r" )
				command_type=run;;
			
			"--clean" | "-c" )
				command_type=clean;;

			"--help" | "-h" )
				usage; exit 0;;

			*) echo >&2 "Invalid option: ${opt}"; echo "This option was unrecognized."; usage; exit 1;
		esac
	done	
}

# Parse environment variable DOCKERIMAGE_TAG
# to set docker_os, build_type, package
function parse_tag() { 

	# set PACKAGE
	case $tag in
   		*jre*) 
    		package=jre
		;;
	esac
	# set BUILD_TYPE
	case $tag in
   		*-slim*|*_slim*) 
   			build_type=slim
   		;;
	esac
	# set DOCKER_OS
	case $tag in
   		*alpine*) 
	   		docker_os=alpine;;
   		*debianslim*) 
	   		docker_os=debianslim;;
		*debian*) 
	   		docker_os=debian;;
		*centos*) 
	   		docker_os=centos;;
		*clefos*) 
	   		docker_os=clefos;;
		*ubi-minimal*) 
	   		docker_os=ubi-minimal;;
		*ubi*) 
	   		docker_os=ubi;;
		*ubuntu*|*latest*|*nightly*) 
	   		docker_os=ubuntu;;
   		*) echo "Unable to recognize DOCKER_OS from DOCKERIMAGE_TAG = $tag!";;
	esac     
}

function docker-ip() {
  docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$@"
}

parseCommandLineArgs "$@"

# set DOCKER_HOST env variables 
# DOCKER_HOST=$(docker-ip $test-test)

if [ $command_type == "build" ]; then
	source $(dirname "$0")/build_image.sh $test $version $impl $docker_os $package $build_type
fi

if [ $command_type == "run" ]; then
	if [ $reportsrc != "false" ]; then
		echo "docker run $docker_args --name $test-test adoptopenjdk-$test-test:${JDK_VERSION}-$package-$docker_os-${JDK_IMPL}-$build_type $testtarget"
		docker run $docker_args --name $test-test adoptopenjdk-$test-test:${JDK_VERSION}-$package-$docker_os-${JDK_IMPL}-$build_type $testtarget;
		docker cp $test-test:$reportsrc $reportdst/external_test_reports;
	else
		echo "docker run $docker_args --rm adoptopenjdk-$test-test:${JDK_VERSION}-$package-$docker_os-${JDK_IMPL}-$build_type $testtarget"
		docker run $docker_args --rm adoptopenjdk-$test-test:${JDK_VERSION}-$package-$docker_os-${JDK_IMPL}-$build_type $testtarget;
	fi
fi

if [ $command_type == "clean" ]; then
	if [ $reportsrc != "false" ]; then
		docker rm -f $test-test;
	fi
	docker rmi -f adoptopenjdk-$test-test:${JDK_VERSION}-$package-$docker_os-${JDK_IMPL}-$build_type
fi
