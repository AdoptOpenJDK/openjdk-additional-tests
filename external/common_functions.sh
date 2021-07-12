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

# Supported versions
supported_versions="8 9 10 11 12 13 14 15 16 17"

# Supported JVMs
supported_jvms="hotspot openj9"

# Supported distros
# Distros Not Included: windowsservercore-ltsc2016
supported_os="alpine debian debianslim ubi ubi-minimal centos clefos ubuntu"

# Supported packges
supported_packages="jdk jre"

# Supported builds
supported_builds="slim full"

# Supported tests
supported_tests="external_custom camel derby elasticsearch jacoco jenkins functional-test kafka lucene-solr openliberty-mp-tck payara-mp-tck quarkus quarkus_quickstarts scala system-test thorntail-mp-tck tomcat tomee wildfly wycheproof netty spring"

function check_version() {
    version=$1

    for current_version in ${supported_versions}
    do
        if [[ "${version}" == "${current_version}" ]]; then
            return 1
        fi
    done

    return 0
}

# Set a valid version
function set_version() {
    version=$1

    if (check_version ${version}); then
        echo "ERROR: Invalid Version: ${version}"
        echo "Usage: $0 [${supported_versions}]"
        exit 1
    fi
}

function check_os() {
    os=$1

    for current_os in ${supported_os}
    do
        if [[ "${os}" == "${current_os}" ]]; then
            return 1
        fi
    done

    return 0
}

# Set a valid os
function set_os() {
    os=$1
    if (check_os ${os}); then
        echo "ERROR: Invalid OS: ${os}"
        echo "Usage: $0 [${supported_os}]"
        exit 1
    fi
}

function check_test() {
    test=$1

    for current_test in ${supported_tests}
    do
        if [[ "${test}" == "${current_test}" ]]; then
            return 1
        fi
    done

    return 0
}

# Set a valid test
function set_test() {
    test=$1
    if (check_test ${test}); then
        echo "ERROR: Invalid Test: ${test}"
        echo "Usage: $0 [${supported_tests}]"
        exit 1
    fi
}

function check_vm() {
    vm=$1

    for current_vm in ${supported_jvms}
    do
        if [[ "${vm}" == "${current_vm}" ]]; then
            return 1
        fi
    done

    return 0
}

# Set a valid vm
function set_vm() {
    vm=$1
    if (check_vm ${vm}); then
        echo "ERROR: Invalid VM: ${vm}"
        echo "Usage: $0 [${supported_jvms}]"
        exit 1
    fi
}

function check_package() {
    package=$1

    for current_package in ${supported_packages}
    do
        if [[ "${package}" == "${current_package}" ]]; then
            return 1
        fi
    done

    return 0
}

# Set a valid package
function set_package() {
    package=$1
    if (check_package ${package}); then
        echo "ERROR: Invalid Package: ${package}"
        echo "Usage: $0 [${supported_packages}]"
        exit 1
    fi
}

function check_build() {
    build=$1

    for current_build in ${supported_builds}
    do
        if [[ "${build}" == "${current_build}" ]]; then
            return 1
        fi
    done

    return 0
}

# Set a valid build
function set_build() {
    build=$1
    if (check_build ${build}); then
        echo "ERROR: Invalid Build: ${build}"
        echo "Usage: $0 [${supported_builds}]"
        exit 1
    fi
}

# Reading properties of test.properties file
function getProperty() {
    PROP_KEY=$1
    PROP_VALUE=`cat $PROPERTY_FILE | grep "$PROP_KEY" | cut -d'=' -f2`
    echo $PROP_VALUE
}

# Set the valid OSes for the current architectures.
function set_test_info() {
    test=$1
    case ${test} in
    camel)
        github_url="https://github.com/apache/camel-quarkus.git"
        script="camel-test.sh"
        test_results="testResults"
        tag_version="master"
        environment_variable="MODE=\"java\""
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    derby)
        github_url="https://github.com/apache/derby.git"
        script="derby-test.sh"
        home_path="\${WORKDIR}/derby"
        tag_version="trunk"
        ant_version="1.10.6"
        debian_packages="git wget tar"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget tar"
        centos_packages="git wget tar"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget tar"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    elasticsearch)
        github_url="https://github.com/elastic/elasticsearch.git"
        script="elasticsearch-test.sh"
        tag_version="v7.6.2"
        test_results="testResults"
        debian_packages="git wget unzip"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="git wget unzip"
        centos_packages="git wget unzip"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget unzip"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    ${test})
        PROPERTY_FILE=external_custom/test.properties
        GITHUB_URL=$(getProperty "github_url")
        github_url="${EXTERNAL_CUSTOM_REPO}"
        echo "The value of the EXTERNAL_CUSTOM_REPO in common_functions.sh is ${EXTERNAL_CUSTOM_REPO}"
        script="test.sh"
        test_command="${EXTERNAL_TEST_CMD}"
        echo "The value of the EXTERNAL_TEST_CMD in common_functions.sh is ${EXTERNAL_TEST_CMD}"
        test_results="testResults"
        tag_version="${EXTERNAL_REPO_BRANCH}"
        echo "The value of the EXTERNAL_REPO_BRANCH in common_functions.sh is ${EXTERNAL_REPO_BRANCH}"
        environment_variable="MODE=\"java\""
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;   
    functional-test)
        github_url="https://github.com/adoptium/aqa-tests.git"
        script="functional-test.sh"
        home_path=""
        tag_version="master"
        ant_version="1.10.6"
        ant_contrib_version="1.0b3"
        debian_packages="git wget make gcc unzip"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget make gcc unzip"
        centos_packages="git wget make gcc unzip"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget make gcc unzip"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    jacoco)
        github_url="https://github.com/jacoco/jacoco.git"
        script="jacoco-test.sh"
        test_results="testResults"
        tag_version="master"
        environment_variable="MODE=\"java\""
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    jenkins)
        github_url="https://github.com/jenkinsci/jenkins.git"
        script="jenkins-test.sh"
        home_path=""
        test_results="testResults"
        tag_version="jenkins-2.235"
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    kafka)
        github_url="https://github.com/apache/kafka.git"
        script="kafka-test.sh"
        home_path=""
        tag_version="2.5.0"
        gradle_version="5.1"
        debian_packages="git wget unzip"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget unzip"
        centos_packages="git wget unzip"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget unzip"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    lucene-solr)
        github_url="https://github.com/apache/lucene-solr.git"
        script="lucene-solr-test.sh"
        home_path="\${WORKDIR}"
        tag_version="releases/lucene-solr/8.5.1"
        ant_version="1.10.6"
        ivy_version="2.5.0"
        debian_packages="git wget tar"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget tar"
        centos_packages="git wget tar"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget tar"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    openliberty-mp-tck)
        github_url="https://github.com/OpenLiberty/open-liberty.git"
        script="openliberty-mp-tck.sh"
        home_path="\${WORKDIR}"
        test_results="testResults"
        tag_version="gm-20.0.0.4"
        ant_version="1.10.6"
        debian_packages="git wget tar maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget tar maven"
        centos_packages="git wget tar maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget tar maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    payara-mp-tck)
        github_url="https://github.com/payara/MicroProfile-TCK-Runners.git"
        script="payara-mp-tck.sh"
        home_path="\${WORKDIR}"
        test_results="testResults"
        tag_version="2.0"
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    quarkus)
        github_url="https://github.com/quarkusio/quarkus.git"
        script="quarkus-test.sh"
        test_results="testResults"
        tag_version="1.3.2.Final"
        environment_variable="MODE=\"java\""
        debian_packages="git wget"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget"
        centos_packages="git wget"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    quarkus_openshift)
        github_url="https://github.com/quarkus-qe/quarkus-openshift-test-suite.git"
        script="test.sh"
        test_results="testResults"
        tag_version="1.3.2.Final"
        environment_variable="MODE=\"java\""
        debian_packages="git wget"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget"
        centos_packages="git wget"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    quarkus_quickstarts)
        github_url="https://github.com/quarkusio/quarkus-quickstarts.git"
        script="test.sh"
        test_results="testResults"
        tag_version="1.3.2.Final"
        environment_variable="MODE=\"java\""
        debian_packages="git wget maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget maven"
        centos_packages="git wget maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    scala)
        github_url="https://github.com/scala/scala.git"
        script="scala-test.sh"
        home_path=""
        tag_version="v2.13.2"
        sbt_version="1.2.8"
        debian_packages="git wget tar curl gpg gpg-agent"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget tar curl gnupg"
        centos_packages="git wget tar curl gpg"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget tar curl gpg"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    system-test)
        github_url="https://github.com/adoptium/aqa-tests.git"
        script="system-test.sh"
        home_path=""
        tag_version="master"
        ant_version="1.10.6"
        ant_contrib_version="1.0b3"
        debian_packages="git wget make gcc unzip"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget make gcc unzip"
        centos_packages="git wget make gcc unzip"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget make gcc unzip"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    thorntail-mp-tck)
        github_url="https://github.com/thorntail/thorntail.git"
        script="thorntail-mp-tck.sh"
        home_path="\${WORKDIR}"
        test_results="testResults"
        tag_version="2.6.0.Final"
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    tomcat)
        github_url="https://github.com/apache/tomcat.git"
        script="tomcat-test.sh"
        home_path=""
        tag_version="10.0.0-M5"
        ant_version="1.10.6"
        openssl_version="1.1.1d"
        debian_packages="git wget tar make gcc linux-libc-dev libc6-dev perl"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget tar make gcc libc-dev perl linux-headers"
        centos_packages="git wget tar make gcc glibc-devel perl"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget tar make gcc glibc-devel"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    tomee)
        github_url="https://github.com/apache/tomee.git"
        script="tomee-test.sh"
        home_path=""
        test_results="testResults"
        tag_version="tomee-8.0.2"
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    wildfly)
        github_url="https://github.com/wildfly/wildfly.git"
        script="wildfly-test.sh"
        home_path=""
        test_results=""
        tag_version="19.1.0.Final"
        debian_packages="git maven"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    wycheproof)
        github_url="https://github.com/google/wycheproof.git"
        script="wycheproof.sh"
        home_path="\${WORKDIR}"
        test_results="testResults"
        tag_version="master"
        bazel_version="1.2.1"
        debian_packages="git wget unzip zip g++"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget unzip zip g++ bash"
        centos_packages="git wget unzip zip gcc-c++"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget unzip zip gcc-c++"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    netty)
        github_url="https://github.com/netty/netty.git"
        script="netty-test.sh"
        home_path="\${WORKDIR}"
        test_results="testResults"
        tag_version="4.1"
        debian_packages="git maven autoconf automake libtool make tar gcc-multilib libaio-dev"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git maven"
        centos_packages="git maven"
        clefos_packages="${centos_packages}"
        ubi_packages="git maven"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    spring)
        github_url="https://github.com/spring-projects/spring-boot.git"
        script="spring-test.sh"
        home_path="\${WORKDIR}"
        test_results="testResults"
        gradle_version="5.1"
        debian_packages="git wget unzip"
        debianslim_packages="${debian_packages}"
        ubuntu_packages="${debian_packages}"
        alpine_packages="bash git wget unzip"
        centos_packages="git wget unzip"
        clefos_packages="${centos_packages}"
        ubi_packages="git wget unzip"
        ubi_minimal_packages="${ubi_packages}"
        ;;
    *)
        echo "ERROR: Unsupported test:${test}, Exiting"
        exit 1
        ;;
    esac
}

function cleanup_images() {
    # Delete any old containers that have exited.
    docker rm $(docker ps -a | grep "Exited" | awk '{ print $1 }') 2>/dev/null

    # Delete any old images for our target_repo on localhost.
    docker rmi -f $(docker images | grep -e "adoptopenjdk" | awk '{ print $3 }' | sort | uniq) 2>/dev/null
}
