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

// file_picker 8.3.7 hardcodes `compileSdk 34`, but flutter_plugin_android_lifecycle
// (compiled against 36) refuses consumers below 36, so the build fails at
// :file_picker:checkDebugAarMetadata. Lift each plugin subproject to at least the
// app's compileSdk (36) so one outdated plugin can't hold the whole build back.
// `:app` is skipped — it already uses flutter.compileSdkVersion, and the
// `evaluationDependsOn(":app")` above force-evaluates it early, so trying to
// register an afterEvaluate on it would throw "project already evaluated". The
// dynamic call keeps AGP types off the root script's classpath (unresolvable
// there). Remove when file_picker ships a build compiled against a current SDK.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.withGroovyBuilder {
                "compileSdkVersion"(36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
