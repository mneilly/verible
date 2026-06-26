# -*- Python -*-
# Copyright 2017-2021 The Verible Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Bazel rule to run bison toolchain
"""

def genyacc(
        name,
        src,
        header_out,
        source_out,
        extra_options = [],
        extra_outs = []):
    """Build rule for generating C or C++ sources with Bison.
    """

    # Bazel 8 no longer allows select() in genrule.toolchains. Keep the
    # toolchain-provided executables on the configurable tools attribute, and
    # use PATH-provided bison/win_bison for the local Windows paths.
    bison_args = "--defines=$(location " + header_out + ") " + \
                 "--output-file=$(location " + source_out + ") " + \
                 " ".join(extra_options) + " $<"
    windows_cmd = "WIN_BISON=$$(command -v win_bison.exe || command -v win_bison || true); " + \
                  "if [ -z \"$$WIN_BISON\" ]; then " + \
                  "WIN_BISON=$$(find '/c/Program Files' '/c/Program Files (x86)' -maxdepth 2 -type f -name win_bison.exe 2>/dev/null | head -n 1 || true); " + \
                  "fi; " + \
                  "if [ -z \"$$WIN_BISON\" ]; then " + \
                  "echo 'win_bison.exe not found in PATH or standard Program Files locations' >&2; exit 127; fi; " + \
                  "M4=$$(cygpath -aw '$(execpath @rules_m4//m4:current_m4_toolchain)') " + \
                  "\"$$WIN_BISON\" " + bison_args
    default_cmd = "BISON=; " + \
                  "for tool in $(execpaths @rules_bison//bison:current_bison_toolchain); do " + \
                  "case $$tool in */bin/bison|*/bin/bison.exe) BISON=$$tool ;; esac; " + \
                  "done; " + \
                  "M4=$(execpath @rules_m4//m4:current_m4_toolchain) $$BISON " + \
                  bison_args

    native.genrule(
        name = name,
        srcs = [src],
        outs = [header_out, source_out] + extra_outs,
        cmd = select({
            "//bazel:use_local_flex_bison_enabled": "bison " + bison_args,
            "@platforms//os:windows": windows_cmd,
            "//conditions:default": default_cmd,
        }),
        tools = select({
            "//bazel:use_local_flex_bison_enabled": [],
            "@platforms//os:windows": [
                "@rules_m4//m4:current_m4_toolchain",
            ],
            "//conditions:default": [
                "@rules_bison//bison:current_bison_toolchain",
                "@rules_m4//m4:current_m4_toolchain",
            ],
        }),
    )
