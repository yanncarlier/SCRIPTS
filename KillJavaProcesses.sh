#!/bin/bash
# When developing for Android on Linux using Flutter, the lingering Java processes you see are primarily Gradle Daemons. 


set -e

# Why these processes stay running
# Gradle Daemons: These are long-lived background processes designed to speed up subsequent builds by keeping the build environment and classes in memory. They remain active even after you stop a Flutter build or close your IDE.
# Multiple Instances: If you use different JDK or Gradle versions across projects, or if you close your IDE abruptly, multiple independent daemons may spawn and remain active.
# IDE Dependencies: Tools like Android Studio and VS Code often spawn their own Java processes for internal tasks like code analysis and background sync. 

# How to kill them
# You can use the following terminal commands to clean up these processes:
# Graceful Stop (Recommended):
# If you have Gradle installed on your path, you can stop all daemons belonging to the current user safely:



#./gradlew --stop

# Kill All Java Processes (Forceful):
# To immediately terminate every Java-based process on your system:
killall -9 java

# Targeted Kill:
# If you only want to kill processes that appear to be Gradle-related without affecting your IDE:
pkill -f 'gradle'



# How to prevent it
# To stop these processes from staying alive in the future, you can disable the Gradle Daemon globally or per project:
# Navigate to your Gradle properties (e.g., android/gradle.properties in your Flutter project).
# Add or modify the following line

# properties
# org.gradle.daemon=false


pkill antigravity || killall antigravity



# Fix for Ubuntu 24.04 (AppArmor/OpenSSL) 

# export OPENSSL_ia32cap="~0x4000000000000000"
# in ~/.bashrc


# antigravity --no-sandbox


#rm -rf ~/.config/Antigravity
#rm -rf ~/.antigravity

#export OPENSSL_ia32cap="~0x4000000000000000"
# antigravity --no-sandbox
