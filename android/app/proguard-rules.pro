# R8 rules for release builds (see `notelyMinify` in app/build.gradle.kts).
#
# Deliberately short: every plugin ships its own consumer rules inside its AAR, and
# Flutter's engine does the same, so most "add -keep or it crashes" advice found
# online is either obsolete or hides a real bug.
#
# Add a rule only with a stack trace that proves it is needed, and write the reason
# next to it. If a release build fails in `minifyReleaseWithR8`, the escape hatch is
#   bin/build_apk --release --sign-debug --abi arm64 -PnotelyMinify=false

# Keep line numbers so Crashlytics/Firebase stack traces stay readable after R8.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
