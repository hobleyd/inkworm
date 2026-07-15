allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Flutter plugin modules (e.g. url_launcher_android) crash during
// :<plugin>:lintVitalAnalyzeRelease: lint's CommentDetector calls
// java.util.List.removeLast() (a Java 21 API) while the Gradle daemon runs on an
// older JDK, throwing NoSuchMethodError. Under AGP 9.3.0 the lint DSL (disable /
// checkReleaseBuilds) is finalised during configuration, so mutating it from these
// root callbacks races that read and fails with "too late to modify". Disabling the
// vital-lint tasks themselves is not subject to that ordering and skips the buggy
// detector across every subproject (equivalent to not running lint on release).
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
