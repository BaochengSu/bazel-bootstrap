#!/bin/bash
#
# Copyright 2020 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Tests that bazel runs projects with Java 14 features.

# --- begin runfiles.bash initialization ---
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
    if [[ -f "$0.runfiles_manifest" ]]; then
      export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
    elif [[ -f "$0.runfiles/MANIFEST" ]]; then
      export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
    elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
      export RUNFILES_DIR="$0.runfiles"
    fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

source "$(rlocation "io_bazel/src/test/shell/integration_test_setup.sh")" \
  || { echo "integration_test_setup.sh not found!" >&2; exit 1; }

case "$(uname -s | tr [:upper:] [:lower:])" in
msys*|mingw*|cygwin*)
  declare -r is_windows=true
  ;;
*)
  declare -r is_windows=false
  ;;
esac

if "$is_windows"; then
  export MSYS_NO_PATHCONV=1
  export MSYS2_ARG_CONV_EXCL="*"
fi

JAVA_TOOLCHAIN="$1"; shift
JAVA_TOOLS_ZIP="$1"; shift
JAVA_RUNTIME="$1"; shift

echo "JAVA_TOOLS_ZIP=$JAVA_TOOLS_ZIP"


JAVA_TOOLS_RLOCATION=$(rlocation io_bazel/$JAVA_TOOLS_ZIP)

if "$is_windows"; then
    JAVA_TOOLS_ZIP_FILE_URL="file:///${JAVA_TOOLS_RLOCATION}"
else
    JAVA_TOOLS_ZIP_FILE_URL="file://${JAVA_TOOLS_RLOCATION}"
fi
JAVA_TOOLS_ZIP_FILE_URL=${JAVA_TOOLS_ZIP_FILE_URL:-}

add_to_bazelrc "build --java_toolchain=${JAVA_TOOLCHAIN}"
add_to_bazelrc "build --host_java_toolchain=${JAVA_TOOLCHAIN}"
add_to_bazelrc "build --javabase=${JAVA_RUNTIME}"
add_to_bazelrc "build --host_javabase=${JAVA_RUNTIME}"

function set_up() {
    cat >>WORKSPACE <<EOF
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
# java_tools versions only used to test Bazel with various JDK toolchains.

http_archive(
    name = "local_java_tools",
    urls = ["${JAVA_TOOLS_ZIP_FILE_URL}"]
)
EOF
    cat $(rlocation io_bazel/src/test/shell/bazel/testdata/jdk_http_archives) >> WORKSPACE
}

function test_java14_record_type() {
  mkdir -p java/main
  cat >java/main/BUILD <<EOF
java_binary(
    name = 'Javac14Example',
    srcs = ['Javac14Example.java'],
    main_class = 'Javac14Example',
    javacopts = ["--enable-preview"],
    jvm_flags = ["--enable-preview"],
)
EOF

  cat >java/main/Javac14Example.java <<EOF
public class Javac14Example {
  record Point(int x, int y) {}
  public static void main(String[] args) {
    Point point = new Point(0, 1);
    System.out.println(point.x);
  }
}
EOF
  bazel run java/main:Javac14Example --test_output=all --verbose_failures &>"${TEST_log}"
  expect_log "0"
}

# Regression test for https://github.com/bazelbuild/bazel/issues/12605
function test_java15_plugins() {
  mkdir -p java/main
  cat >java/main/BUILD <<EOF
java_library(
    name = "Anno",
    srcs = ["Anno.java"],
)

java_plugin(
    name = "Proc",
    srcs = ["Proc.java"],
    deps = [":Anno"],
    processor_class = "ex.Proc",
    generates_api = True,
)

java_library(
    name = "C1",
    srcs = ["C1.java"],
    deps = [":Anno"],
    plugins = [":Proc"],
)

java_library(
    name = "C2",
    srcs = ["C2.java"],
    deps = [":C1"],
)
EOF

  cat >java/main/C1.java <<EOF
package ex;

public class C1 {
    @Anno
    @Deprecated
    public void m() {}
}
EOF


  cat >java/main/C2.java <<EOF
package ex;

public class C2 {
    public void m() {
        new C1().m();
    }
}

EOF

  cat >java/main/Anno.java <<EOF
package ex;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD})
public @interface Anno {}
EOF

  cat >java/main/Proc.java <<EOF
package ex;

import java.util.Set;

import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.RoundEnvironment;
import javax.annotation.processing.SupportedAnnotationTypes;
import javax.annotation.processing.SupportedSourceVersion;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.TypeElement;
import javax.lang.model.util.Elements;
import javax.tools.Diagnostic.Kind;

@SupportedSourceVersion(SourceVersion.RELEASE_8)
@SupportedAnnotationTypes("ex.Anno")
public class Proc extends AbstractProcessor {
    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
        Elements els = processingEnv.getElementUtils();
        for (Element el : roundEnv.getElementsAnnotatedWith(Anno.class)) {
            if (els.isDeprecated(el)) {
                processingEnv.getMessager().printMessage(Kind.WARNING, "deprecated");
            }
        }
        return true;
    }
}
EOF

  bazel build //java/main:C2 &>"${TEST_log}" || fail "Expected to build"
}

run_suite "Tests new Java 14 language features"
