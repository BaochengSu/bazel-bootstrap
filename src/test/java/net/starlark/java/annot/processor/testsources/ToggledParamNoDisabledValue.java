// Copyright 2018 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package net.starlark.java.annot.processor.testsources;

import com.google.devtools.build.lib.syntax.StarlarkSemantics.FlagIdentifier;
import com.google.devtools.build.lib.syntax.StarlarkValue;
import net.starlark.java.annot.Param;
import net.starlark.java.annot.StarlarkMethod;

/**
 * Test case for a StarlarkMethod method which has a parameter which may be disabled with semantic
 * flag but has no "disabled value".
 */
public class ToggledParamNoDisabledValue implements StarlarkValue {

  @StarlarkMethod(
      name = "no_disabled_value_method",
      documented = false,
      parameters = {
        @Param(name = "one", named = true, positional = true),
        @Param(
            name = "two",
            named = true,
            enableOnlyWithFlag = FlagIdentifier.EXPERIMENTAL_GOOGLE_LEGACY_API,
            positional = true)
      })
  public Integer noDisabledValueMethod(Integer one, Integer two) {
    return 42;
  }
}
