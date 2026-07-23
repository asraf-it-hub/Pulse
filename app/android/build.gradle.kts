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

subprojects {
    val configureProject = {
        val ext = project.extensions.findByName("android")
        if (ext != null) {
            try {
                val setCompileSdk = ext.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                setCompileSdk.invoke(ext, 36)
            } catch (e: Exception) {
                try {
                    val compileSdkVersion = ext.javaClass.getMethod("compileSdkVersion", java.lang.Integer::class.java)
                    compileSdkVersion.invoke(ext, 36)
                } catch (e2: Exception) {
                    try {
                        val compileSdkVersionStr = ext.javaClass.getMethod("compileSdkVersion", java.lang.String::class.java)
                        compileSdkVersionStr.invoke(ext, "android-36")
                    } catch (e3: Exception) {}
                }
            }
        }
    }

    if (project.state.executed) {
        configureProject()
    } else {
        project.afterEvaluate {
            configureProject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
