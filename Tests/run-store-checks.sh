#!/bin/zsh
set -eu
cd "${0:A:h:h}"
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path /tmp/TeacherStoreModuleCache 'Teacher Lesson Organizer/Models.swift' Tests/StoreChecks.swift -o /tmp/TeacherStoreChecks
/tmp/TeacherStoreChecks
