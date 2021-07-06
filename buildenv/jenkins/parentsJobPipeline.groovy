#!groovy
def JDK_VERSIONS = params.JDK_VERSIONS.trim().split("\\s*,\\s*")
def LEVELS = params.LEVELS.trim().split("\\s*,\\s*")
def SDK_RESOURCE = params.SDK_RESOURCE ? params.SDK_RESOURCE : "nightly"
def CUSTOMIZED_SDK_URL = params.CUSTOMIZED_SDK_URL? params.CUSTOMIZED_SDK_URL : ""
def OS_ARCHKEYS = params.OS_ARCHKEYS ? params.OS_ARCHKEYS : ""
def GROUP = params.GROUP ? params.GROUP : "external"
def osarchKeys = []
if (params.OS_ARCHKEYS) {
    osarchKeys = Arrays.asList(OS_ARCHKEYS.trim().split("\\s*,\\s*"))
}

if (SDK_RESOURCE == 'customized') {
    if (!OS_ARCHKEYS || !CUSTOMIZED_SDK_URL) {
        assert false : "For customized SDK please specify SDK URL, OS and architecture."
    }
}

node {
    stage("trigger the jobs") {
        keep_test_reportdir = "false"
        def jobs = [:]
        LEVELS.each { level ->
            JDK_VERSIONS.each { jdk_version ->
                sh "curl -Os https://raw.githubusercontent.com/adoptium/ci-jenkins-pipelines/master/pipelines/jobs/configurations/jdk${jdk_version}u_pipeline_config.groovy"
                sh "curl -Os https://raw.githubusercontent.com/adoptium/ci-jenkins-pipelines/master/pipelines/jobs/configurations/jdk${jdk_version}u.groovy"
                def buildConfigurations = load "jdk${jdk_version}u_pipeline_config.groovy"
                load "jdk${jdk_version}u.groovy"
                if (osarchKeys.isEmpty()) {
                    if (GROUP == "external") {
                        osarchKeys = ["ppc64leLinux", "s390xLinux" ,"x64Linux"]
                    } 
                }
                if (!osarchKeys.isEmpty()) {
                    targetConfigurations = targetConfigurations.subMap(osarchKeys)
                }
                if (GROUP.contains("jck")) {
                    // Keep test reportdir always for JUnit targets
                    keep_test_reportdir = "true"
                }
                targetConfigurations.keySet().each { osarch ->
                    for (def variant in targetConfigurations.get(osarch)) {
                        switch (variant) {
                            case "openj9": variant = "j9"; break
                            case "corretto": variant = "corretto"; break
                            case "dragonwell": variant = "dragonwell"; break;
                            case "bisheng": variant = "bisheng"; break;
                            default: variant = "hs"
                        }
                        buildConfigurations.keySet().each { key -> 
                            if (key == osarch) {
                                def jobParams = [:]
                                jobParams.put('LIGHT_WEIGHT_CHECKOUT', true)
                                jobParams.put('LEVELS', level)
                                jobParams.put('JDK_VERSIONS', jdk_version)
                                jobParams.put('GROUPS', GROUP)
                                jobParams.put('JDK_IMPL', variant)

                                def arch = buildConfigurations[key]["arch"]
                                def os = buildConfigurations[key]["os"]
                                if (arch == 'x64') {
                                    arch = 'x86-64'
                                }
                                def arch_os = "${arch}_${os}"
                                jobParams.put('ARCH_OS_LIST', arch_os)
                                def jobName = "Test_openjdk${jdk_version}_${variant}_${level}.${GROUP}_${arch_os}"
                                jobParams.put('TEST_JOB_NAME', jobName)
                                def JobHelper = library(identifier: 'openjdk-jenkins-helper@master').JobHelper
                                
                                // Create test job if job doesn't exist or is not runnable
                                // Will enable when external and jck jobs are more healthy
                                //if (!JobHelper.jobIsRunnable(jobName as String)) {
                                //    def templatePath = "${WORKSPACE}/aqa-tests/buildenv/jenkins/testJobTemplate"
                                //    println "Test job doesn't exist, create test job: ${jobName}"
                                //    jobDsl targets: templatePath, ignoreExisting: false, additionalParameters: jobParams
                                //}
                                if (JobHelper.jobIsRunnable(jobName as String)) {
                                    jobs["${jobName}"] = {
                                        build job: jobName,
                                            propagate: false,
                                            parameters: [
                                                string(name: 'SDK_RESOURCE', value: "${SDK_RESOURCE}"),
                                                string(name: 'CUSTOMIZED_SDK_URL', value: "${CUSTOMIZED_SDK_URL}"),
                                                string(name: 'KEEP_REPORTDIR', value: "${keep_test_reportdir}")]
                                    }
                                } else {
                                    println "[WARNING] Requested test job that does not exist or is disabled: ${jobName}"
                                }
                            }
                        }
                    }
                }
            }
        }
        parallel jobs
    }
}
