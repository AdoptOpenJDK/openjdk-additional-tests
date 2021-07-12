 #/bin/bash
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

source $(dirname "$0")/test_base_functions.sh

# Set up Java to be used by the external_custom test

if [ -d /java/jre/bin ];then
	echo "Using mounted Java8"
	export JAVA_BIN=/java/jre/bin
	export JAVA_HOME=/java
	export PATH=$JAVA_BIN:$PATH
elif [ -d /java/bin ]; then
	echo "Using mounted Java"
	export JAVA_BIN=/java/bin
	export JAVA_HOME=/java
	export PATH=$JAVA_BIN:$PATH
else
	echo "Using docker image default Java"
	java_path=$(type -p java)
	suffix="/java"
	java_root=${java_path%$suffix}
	export JAVA_BIN="$java_root"
	$JAVA_BIN/java -version
	export JAVA_HOME="${java_root%/bin}"
fi

echo_setup

external_test_repo="$(echo ${EXTERNAL_CUSTOM_REPO} | awk -F'/' '{print $NF}' | sed 's/.git//g')"
echo ${EXTERNAL_CUSTOM_REPO}
echo ${external_test_repo}
echo ${EXTERNAL_TEST_CMD}
cd /${external_test_repo}
set -e
pwd
echo "Compile and run external tests"
${EXTERNAL_TEST_CMD}
test_exit_code=$?
echo "Build external_custom completed"
set +e
find ./ -type d -name 'surefire-reports' -exec cp -r "{}" /testResults \;
