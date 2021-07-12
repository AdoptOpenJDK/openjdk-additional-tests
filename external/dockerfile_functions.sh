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

source $(dirname "$0")/common_functions.sh

# Generate the common license and copyright header
print_legal() {
    local file=$1

    echo -e "# ------------------------------------------------------------------------------" \
          "\n#               NOTE: THIS DOCKERFILE IS GENERATED VIA \"build_image.sh\" or \"build_all.sh\"" \
          "\n#" \
          "\n#" \
          "\n#                       PLEASE DO NOT EDIT IT DIRECTLY." \
          "\n# ------------------------------------------------------------------------------" \
          "\n#" \
          "\n# Licensed under the Apache License, Version 2.0 (the \"License\");" \
          "\n# you may not use this file except in compliance with the License." \
          "\n# You may obtain a copy of the License at" \
          "\n#" \
          "\n#      https://www.apache.org/licenses/LICENSE-2.0" \
          "\n#" \
          "\n# Unless required by applicable law or agreed to in writing, software" \
          "\n# distributed under the License is distributed on an \"AS IS\" BASIS," \
          "\n# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied." \
          "\n# See the License for the specific language governing permissions and" \
          "\n# limitations under the License." \
          "\n" > ${file}
}

# Generate the Adopt Test header
print_adopt_test() {
    local file=$1
    local test=$2

    echo -e "# This Dockerfile in external/${test}/dockerfile dir is used to create an image with" \
          "\n# Adoptium jdk binary installed. Basic test dependent executions" \
          "\n# are installed during the building process." \
          "\n#" \
          "\n# Build example: \`docker build -t adoptopenjdk-${test}-test -f ${file} .\`" \
          "\n#" \
          "\n# This Dockerfile builds image based on adoptopenjdk/openjdk8:latest." \
          "\n# If you want to build image based on other images, please use" \
          "\n# \`--build-arg list\` to specify your base image" \
          "\n#" \
          "\n# Build example: \`docker build --build-arg IMAGE_NAME=<image_name> --build-arg IMAGE_VERSION=<image_version> -t adoptopenjdk-${test}-test .\`" \
          "\n" >> ${file}
}

sanitize_test_names() {
    local test=$1

    mp_tck=$(echo ${test} | awk -F'-' '{print $2"-"$3}')

    if [[ "${mp_tck}" == "mp-tck" ]]; then
        echo "$(echo ${test} | awk -F'-' '{print $1}')"
    elif [[ "${mp_tck}" == "solr-" || "${mp_tck}" == "test-" ]]; then
        echo "$(echo ${test} | sed 's/-/_/g')"
    else
        echo "${test}"
    fi
}

print_image_args() {
    local file=$1
    local os=$2
    local version=$3
    local vm=$4
    local package=$5
    local build=$6

    sdk="openjdk${version}"
    if [[ "${vm}" == "openj9" ]]; then
        sdk="${sdk}-openj9"
    fi

    echo -e "ARG SDK=${sdk}" \
          "\nARG IMAGE_NAME=adoptopenjdk/\$SDK" \
          "\nARG OS=${os}" \
          "\nARG IMAGE_VERSION=nightly" >> ${file}


    if [[ "${package}" == "jre" && "${build}" == "slim" ]]; then
        echo -e "ARG TAG=\$OS-jre-\$IMAGE_VERSION-slim\n" >> ${file}
    elif [[ "${package}" == "jre" && "${build}" == "full" ]]; then
        echo -e "ARG TAG=\$OS-jre-\$IMAGE_VERSION\n" >> ${file}
    elif [[ "${build}" == "slim" ]]; then
        echo -e "ARG TAG=\$OS-\$IMAGE_VERSION-slim\n" >> ${file}
    else
        echo -e "ARG TAG=\$OS-\$IMAGE_VERSION\n" >> ${file}
    fi

    echo -e "FROM \$IMAGE_NAME:\$TAG\n" >> ${file}
}

print_test_tag_arg() {
    local file=$1
    local test=$2
    local tag=$3

    # Cause Test name to be capitalized
    test="$(sanitize_test_names ${test} | tr a-z A-Z)_TAG"

    echo -e "ARG ${test}=${tag}\n" >> ${file}
}


# Select the ubuntu OS packages
print_ubuntu_pkg() {
    local file=$1
    local packages=$2

    echo -e "RUN apt-get update \\" \
            "\n\t&& apt-get install -y --no-install-recommends ${packages} \\" \
            "\n\t&& rm -rf /var/lib/apt/lists/*" \
            "\n" >> ${file}
}

print_debian_pkg() {
    local file=$1
    local packages=$2

    print_ubuntu_pkg ${file} "${packages}"
}

print_debianslim_pkg() {
    local file=$1
    local packages=$2

    # Revert back to calling `print_ubuntu_pkg` once https://github.com/debuerreotype/debuerreotype/issues/10 is resolved
    echo -e "RUN apt-get update \\" \
            "\n\t&& for i in \$(seq 1 8); do mkdir -p \"/usr/share/man/man\${i}\"; done \\" \
            "\n\t&& apt-get install -y --no-install-recommends ${packages} \\" \
            "\n\t&& rm -rf /var/lib/apt/lists/*" \
            "\n" >> ${file}
}

# Select the alpine OS packages.
print_alpine_pkg() {
    local file=$1
    local packages=$2

    echo -e "RUN apk add --no-cache ${packages} \\" \
            "\n\t&& rm -rf /tmp/*.apk /var/cache/apk/*" \
            "\n" >> ${file}
}

# Select the ubi OS packages.
print_ubi_pkg() {
    local file=$1
    local packages=$2

    echo -e "RUN dnf install -y ${packages} \\" \
            "\n\t&& dnf update -y; dnf clean all"  \
            "\n" >> ${file}
}


# Select the ubi OS packages.
print_ubi-minimal_pkg() {
    local file=$1
    local packages=$2

    echo -e "RUN microdnf install -y ${packages} \\" \
            "\n\t&& microdnf update -y; microdnf clean all" \
            "\n" >> ${file}
}

# Select the CentOS packages.
print_centos_pkg() {
    local file=$1
    local packages=$2

    echo -e "RUN yum install -y ${packages} \\" \
            "\n\t&& yum update; yum clean all" \
            "\n" >> ${file}
}


# Select the ClefOS packages.
print_clefos_pkg() {
    local file=$1
    local packages=$2
    print_centos_pkg ${file} ${packages}
}


# Install Ant
print_ant_install() {
    local file=$1
    local ant_version=$2
    local os=$3

    echo -e "ARG ANT_VERSION=${ant_version}" \
          "\nENV ANT_VERSION=\$ANT_VERSION" \
          "\nENV ANT_HOME=/opt/ant" \
          "\n\n# Install Ant" \
          "\nRUN wget --no-check-certificate --no-cookies http://archive.apache.org/dist/ant/binaries/apache-ant-\${ANT_VERSION}-bin.tar.gz \\" \
          "\n\t&& wget --no-check-certificate --no-cookies http://archive.apache.org/dist/ant/binaries/apache-ant-\${ANT_VERSION}-bin.tar.gz.sha512 \\" >> ${file}

    # Alpine sha512sum requires two spaces https://github.com/gliderlabs/docker-alpine/issues/174
    if [[ "${os}" = "alpine" ]]; then
        echo -e "\t&& echo \"\$(cat apache-ant-\${ANT_VERSION}-bin.tar.gz.sha512)  apache-ant-\${ANT_VERSION}-bin.tar.gz\" | sha512sum -c \\" >> ${file}
    else
        echo -e "\t&& echo \"\$(cat apache-ant-\${ANT_VERSION}-bin.tar.gz.sha512) apache-ant-\${ANT_VERSION}-bin.tar.gz\" | sha512sum -c \\" >> ${file}
    fi

    echo -e "\t&& tar -zvxf apache-ant-\${ANT_VERSION}-bin.tar.gz -C /opt/ \\" \
            "\n\t&& ln -s /opt/apache-ant-\${ANT_VERSION} /opt/ant \\" \
            "\n\t&& rm -f apache-ant-\${ANT_VERSION}-bin.tar.gz \\" \
            "\n\t&& rm -f apache-ant-\${ANT_VERSION}-bin.tar.gz.sha512" \
            "\n\n# Add Ant to PATH" \
            "\nENV PATH \${PATH}:\${ANT_HOME}/bin" \
            "\n" >> ${file}
}

# Install Ant Contrib
print_ant_contrib_install() {
    local file=$1
    local ant_contrib_version=$2
    local os=$3

    echo -e "ARG ANT_CONTRIB_VERSION=${ant_contrib_version}" \
          "\nENV ANT_CONTRIB_VERSION=\$ANT_CONTRIB_VERSION" \
          "\n\n# Install Ant Contrib" \
          "\nRUN wget --no-check-certificate --no-cookies https://sourceforge.net/projects/ant-contrib/files/ant-contrib/\${ANT_CONTRIB_VERSION}/ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz \\" \
          "\n\t&& wget --no-check-certificate --no-cookies https://sourceforge.net/projects/ant-contrib/files/ant-contrib/\${ANT_CONTRIB_VERSION}/ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz.md5 \\" >> ${file}

    # Alpine md5sum requires two spaces https://github.com/gliderlabs/docker-alpine/issues/174
    if [[ "${os}" = "alpine" ]]; then
        echo -e "\t&& echo \"\$(cat ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz.md5)  ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz\" | md5sum -c \\" >> ${file}
    else
        echo -e "\t&& echo \"\$(cat ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz.md5) ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz\" | md5sum -c \\" >> ${file}
    fi

    echo -e "\t&& tar -zvxf ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz -C /tmp/ \\" \
            "\n\t&& mv /tmp/ant-contrib/ant-contrib-\${ANT_CONTRIB_VERSION}.jar \${ANT_HOME}/lib/ant-contrib.jar \\" \
            "\n\t&& rm -rf /tmp/ant-contrib \\" \
            "\n\t&& rm -f ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz \\" \
            "\n\t&& rm -f ant-contrib-\${ANT_CONTRIB_VERSION}-bin.tar.gz.md5" \
            "\n" >> ${file}
}

# Install SBT
print_sbt_install() {
    local file=$1
    local sbt_version=$2
    local os=$3

    echo -e "ARG SBT_VERSION=${sbt_version}" \
          "\nENV SBT_VERSION=\$SBT_VERSION" \
          "\nENV SBT_HOME=/opt/sbt" \
          "\n\n# Install SBT" \
          "\nRUN wget --no-check-certificate --no-cookies https://piccolo.link/sbt-\${SBT_VERSION}.tgz \\" \
          "\n\t&& wget --no-check-certificate --no-cookies https://piccolo.link/sbt-\${SBT_VERSION}.tgz.asc \\" \
          "\n\t&& curl \"https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823\" | gpg --import \\" \
          "\n\t&& gpg --verify sbt-\${SBT_VERSION}.tgz.asc sbt-\${SBT_VERSION}.tgz \\" \
          "\n\t&& tar -zvxf sbt-\${SBT_VERSION}.tgz -C /opt/ \\" \
          "\n\t&& rm -f sbt-\${SBT_VERSION}.tgz \\" \
          "\n\t&& rm -f sbt-\${SBT_VERSION}.tgz.asc" \
          "\n\n# Add SBT to PATH" \
          "\nENV PATH \${PATH}:\${SBT_HOME}/bin" \
          "\n" >> ${file}
}

# Install Gradle
print_gradle_install() {
    local file=$1
    local gradle_version=$2
    local os=$3

    echo -e "ARG GRADLE_VERSION=${gradle_version}" \
          "\nENV GRADLE_VERSION=\$GRADLE_VERSION" \
          "\nENV GRADLE_HOME /opt/gradle" \
          "\n\n# Install Gradle" \
          "\nRUN wget --no-check-certificate --no-cookies https://services.gradle.org/distributions/gradle-\${GRADLE_VERSION}-bin.zip \\" \
          "\n\t&& wget --no-check-certificate --no-cookies https://services.gradle.org/distributions/gradle-\${GRADLE_VERSION}-bin.zip.sha256 \\" >> ${file}

    # Alpine sha512sum requires two spaces https://github.com/gliderlabs/docker-alpine/issues/174
    if [[ "${os}" = "alpine" ]]; then
        echo -e "\t&& echo \"\$(cat gradle-\${GRADLE_VERSION}-bin.zip.sha256)  gradle-\${GRADLE_VERSION}-bin.zip\" | sha256sum -c \\" >> ${file}
    else
        echo -e "\t&& echo \"\$(cat gradle-\${GRADLE_VERSION}-bin.zip.sha256) gradle-\${GRADLE_VERSION}-bin.zip\" | sha256sum -c \\" >> ${file}
    fi

    echo -e "\t&& unzip gradle-\${GRADLE_VERSION}-bin.zip -d \${GRADLE_HOME} \\" \
            "\n\t&& ln -s \"\${GRADLE_HOME}/gradle-\${GRADLE_VERSION}/bin/gradle\" /usr/bin/gradle \\" \
            "\n\t&& rm -f gradle-\${GRADLE_VERSION}-bin.zip \\" \
            "\n\t&& rm -f gradle-\${GRADLE_VERSION}-bin.zip.sha256" \
            "\n" >> ${file}
}

# Install Ivy
print_ivy_install() {
    local file=$1
    local ivy_version=$2
    local os=$3

    echo -e "ARG IVY_VERSION=${ivy_version}" \
          "\nENV IVY_VERSION=\$IVY_VERSION" \
          "\n\n# Install Ivy" \
          "\nRUN wget --no-check-certificate --no-cookies https://archive.apache.org/dist/ant/ivy/\${IVY_VERSION}/apache-ivy-\${IVY_VERSION}-bin.tar.gz \\" \
          "\n\t&& wget --no-check-certificate --no-cookies https://archive.apache.org/dist/ant/ivy/\${IVY_VERSION}/apache-ivy-\${IVY_VERSION}-bin.tar.gz.sha512 \\" >> ${file}

    # Alpine sha512sum requires two spaces https://github.com/gliderlabs/docker-alpine/issues/174
    if [[ "${os}" = "alpine" ]]; then
        echo -e "\t&& echo \"\$(cat apache-ivy-\${IVY_VERSION}-bin.tar.gz.sha512)  apache-ivy-\${IVY_VERSION}-bin.tar.gz\" | sha512sum -c \\" >> ${file}
    else
        echo -e "\t&& echo \"\$(cat apache-ivy-\${IVY_VERSION}-bin.tar.gz.sha512) apache-ivy-\${IVY_VERSION}-bin.tar.gz\" | sha512sum -c \\" >> ${file}
    fi

    echo -e "\t&& tar -zvxf apache-ivy-\${IVY_VERSION}-bin.tar.gz apache-ivy-\${IVY_VERSION}/ivy-\${IVY_VERSION}.jar -C \${ANT_HOME}/lib/ \\" \
            "\n\t&& rm -f apache-ivy-\${IVY_VERSION}-bin.tar.gz \\" \
            "\n\t&& rm -f apache-ivy-\${IVY_VERSION}-bin.tar.gz.sha512" \
            "\n" >> ${file}
}

# Install OpenSSL
print_openssl_install() {
    local file=$1
    local openssl_version=$2
    local os=$3

    echo -e "ARG OPENSSL_VERSION=${openssl_version}" \
          "\nENV OPENSSL_VERSION=\$OPENSSL_VERSION" \
          "\nENV OPENSSL_HOME /opt/openssl" \
          "\n\n# Install OpenSSL" \
          "\nRUN  wget --no-check-certificate --no-cookies https://www.openssl.org/source/openssl-\${OPENSSL_VERSION}.tar.gz \\" \
          "\n\t&& wget --no-check-certificate --no-cookies https://www.openssl.org/source/openssl-\${OPENSSL_VERSION}.tar.gz.sha256 \\" >> ${file}

    # Alpine sha512sum requires two spaces https://github.com/gliderlabs/docker-alpine/issues/174
    if [[ "${os}" = "alpine" ]]; then
        echo -e "\t&& echo \"\$(cat openssl-\${OPENSSL_VERSION}.tar.gz.sha256)  openssl-\${OPENSSL_VERSION}.tar.gz\" | sha256sum -c \\" >> ${file}
    else
        echo -e "\t&& echo \"\$(cat openssl-\${OPENSSL_VERSION}.tar.gz.sha256) openssl-\${OPENSSL_VERSION}.tar.gz\" | sha256sum -c \\" >> ${file}
    fi

    echo -e "\t&& tar -zvxf openssl-\${OPENSSL_VERSION}.tar.gz -C /opt/ \\" \
            "\n\t&& ln -s /opt/openssl-\${OPENSSL_VERSION} /opt/openssl \\" \
            "\n\t&& rm -f openssl-\${OPENSSL_VERSION}.tar.gz \\" \
            "\n\t&& rm -f openssl-\${OPENSSL_VERSION}.tar.gz.sha256 \\" \
            "\n\t&& cd \${OPENSSL_HOME} \\" \
            "\n\t&& ./config -Wl,--enable-new-dtags,-rpath,'\$(LIBRPATH)' \\" \
            "\n\t&& make \\" \
            "\n\t&& make install" \
            "\n" >> ${file}
}

# Install Bazel
print_bazel_install() {
    local file=$1
    local bazel_version=$2
    local os=$3

    echo -e "ARG BAZEL_VERSION=${bazel_version}" \
          "\nENV BAZEL_VERSION=\$BAZEL_VERSION" \
          "\nENV BAZEL_HOME /opt/bazel" \
          "\n\n# Install Bazel" \
          "\nRUN  wget --no-check-certificate --no-cookies https://github.com/bazelbuild/bazel/releases/download/\${BAZEL_VERSION}/bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh \\" \
          "\n\t&&  wget --no-check-certificate --no-cookies https://github.com/bazelbuild/bazel/releases/download/\${BAZEL_VERSION}/bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh.sha256 \\" >> ${file}

    # Alpine sha512sum requires two spaces https://github.com/gliderlabs/docker-alpine/issues/174
    if [[ "${os}" = "alpine" ]]; then
        echo -e "\t&& echo \"\$(cat bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh.sha256)\" | sha256sum -c \\" >> ${file}
    else
        echo -e "\t&& echo \"\$(cat bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh.sha256)\" | sha256sum -c \\" >> ${file}
    fi

    echo -e "\t&& chmod +x bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh \\" \
            "\n\t&& ./bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh --prefix=\${BAZEL_HOME} \\" \
            "\n\t&& rm -f bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh \\" \
            "\n\t&& rm -f bazel-\${BAZEL_VERSION}-installer-linux-x86_64.sh.sha256" \
            "\n\n# Add Bazel to PATH" \
            "\nENV PATH \${PATH}:\${BAZEL_HOME}/bin" \
            "\n" >> ${file}
}

# Prints Java Tool Options
print_java_tool_options() {
    local file=$1

    echo -e "ENV JAVA_TOOL_OPTIONS=\"-Dfile.encoding=UTF8 -Djava.security.egd=file:/dev/./urandom\"\n" >> ${file}
}

print_environment_variable() {
    local file=$1
    local environment_variable=$2

    echo -e "ENV ${environment_variable}\n" >> ${file}
}

print_home_path() {
    local file=$1
    local test=$2
    local path=$3

    # Cause Test name to be capitalized
    test="$(sanitize_test_names ${test} | tr a-z A-Z)_HOME"

    echo -e "ENV ${test} ${path}\n" >> ${file}
}

print_test_results() {
    local file=$1

    echo -e "RUN mkdir testResults\n" >> ${file}
}

print_test_script() {
    local file=$1
    local test=$2
    local script=$3

    echo -e "# This is the main script to run ${test} tests" \
            "\nCOPY ${test}/dockerfile/${script} /${script}" \
            "\nCOPY test_base_functions.sh test_base_functions.sh\n" >> ${file}
}

print_testInfo_env() {
    local test=$1
    local test_tag=$2
    local OS=$3
    echo -e "ENV APPLICATION_NAME=${test}" \
            "\nENV APPLICATION_TAG=${test_tag}" \
            "\nENV OS_TAG=${OS}" \
            "\n" >> ${file}
}

print_clone_project() {
    local file=$1
    local test=$2
    local github_url=$3

    # Cause Test name to be capitalized
    test_tag="$(sanitize_test_names ${test} | tr a-z A-Z)_TAG"

    # Get Github folder name
    folder="$(echo ${github_url} | awk -F'/' '{print $NF}' | sed 's/.git//g')"

    echo -e "# Clone ${test} source" \
            "\nENV ${test_tag}=\$${test_tag}" \
            "\nRUN git clone ${github_url}" \
            "\nWORKDIR /${folder}/" \
            "\nRUN git checkout \$${test_tag}" \
            "\nWORKDIR /" \
            "\n" >> ${file}
}

print_entrypoint() {
    local file=$1
    local script=$2
    local os=$3

    if [[ "${os}" = "alpine" ]]; then
        echo -e "ENTRYPOINT [\"/bin/ash\", \"/${script}\"]" >> ${file}
    else
        echo -e "ENTRYPOINT [\"/bin/bash\", \"/${script}\"]" >> ${file}
    fi
}

print_cmd() {
    local file=$1
    local cmd=$2

    echo -e "CMD [\"${cmd}\"]" >> ${file}
}

remove_trailing_spaces() {
    local file=$1

    # Make the Dockerfile after we set the base image
    if [[ "$(uname)" == 'Darwin' ]]; then
        sed -i '' 's/[[:space:]]*$//g' ${file}
    else
        sed -i 's/[[:space:]]*$//g' ${file}
    fi
}


# Generate the dockerfile for a given build
generate_dockerfile() {
    file=$1
    test=$2
    version=$3
    vm=$4
    os=$5
    package=$6
    build=$7
    testtarget=$8
    
    if [[ '${test}'=='external_custom' ]]; then
        echo "EXTERNAL_CUSTOM_REPO points to ${EXTERNAL_CUSTOM_REPO} in dockerfile_functions.sh"
        echo "EXTERNAL_CUSTOM_BRANCH pounts to ${EXTERNAL_REPO_BRANCH} in dockerfile_functions.sh"
        test="$(echo ${EXTERNAL_CUSTOM_REPO} | awk -F'/' '{print $NF}' | sed 's/.git//g')"
        echo ${test}
        tag_version=${EXTERNAL_REPO_BRANCH}
    fi

    set_test_info ${test}
    packages=$(echo ${os}_packages | sed 's/-/_/')

    jhome="/opt/java/openjdk"

    mkdir -p `dirname ${file}` 2>/dev/null
    echo
    echo -n "Writing ${file} ... "
    print_legal ${file};
    print_adopt_test ${file} ${test};
    print_image_args ${file} ${os} ${version} ${vm} ${package} ${build};
    print_test_tag_arg ${file} ${test} ${tag_version};
    print_${os}_pkg ${file} "${!packages}";

    if [[ ! -z ${ant_version} ]]; then
        print_ant_install ${file} ${ant_version} ${os};
    fi

    if [[ ! -z ${ant_contrib_version} ]]; then
        print_ant_contrib_install ${file} ${ant_contrib_version} ${os};
    fi

    if [[ ! -z ${ivy_version} ]]; then
        print_ivy_install ${file} ${ivy_version} ${os};
    fi

    if [[ ! -z ${sbt_version} ]]; then
        print_sbt_install ${file} ${sbt_version} ${os};
    fi

    if [[ ! -z ${gradle_version} ]]; then
        print_gradle_install ${file} ${gradle_version} ${os};
    fi

    if [[ ! -z ${openssl_version} ]]; then
        print_openssl_install ${file} ${openssl_version} ${os};
    fi

    if [[ ! -z ${bazel_version} ]]; then
        print_bazel_install ${file} ${bazel_version} ${os};
    fi

    print_java_tool_options ${file};

    if [[ ! -z ${environment_variable} ]]; then
        print_environment_variable ${file} ${environment_variable};
    fi

    if [[ ! -z ${home_path} ]]; then
        print_home_path ${file} ${test} ${home_path};
    fi

    if [[ ! -z ${test_results} ]]; then
        print_test_results ${file};
    fi

    if [[ ! -z ${script} ]]; then
        print_test_script ${file} ${test} ${script};
    fi

    print_testInfo_env ${test} ${tag_version} ${os}
    print_clone_project ${file} ${test} ${github_url};
    print_entrypoint ${file} ${script} ${os};

    if [[ ! -z ${testtarget} ]]; then
        print_cmd ${file} ${testtarget};
    fi

    remove_trailing_spaces ${file};

    echo "done"
    echo
}
