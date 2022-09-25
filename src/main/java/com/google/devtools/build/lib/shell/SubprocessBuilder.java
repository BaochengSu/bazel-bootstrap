// Copyright 2016 The Bazel Authors. All rights reserved.
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

package com.google.devtools.build.lib.shell;

import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import java.io.File;
import java.io.IOException;
import java.util.Map;
import javax.annotation.Nullable;

/**
 * A builder class that starts a subprocess.
 */
public class SubprocessBuilder {
  /**
   * What to do with an output stream of the process.
   */
  public enum StreamAction {
    /** Redirect to a file */
    REDIRECT,

    /** Discard. */
    DISCARD,

    /** Stream back to the parent process using an output stream. */
    STREAM
  }

  private final SubprocessFactory factory;
  private ImmutableList<String> argv;
  private ImmutableMap<String, String> env;
  private StreamAction stdoutAction;
  private File stdoutFile;
  private StreamAction stderrAction;
  private File stderrFile;
  private File workingDirectory;
  private long timeoutMillis;
  private boolean redirectErrorStream;

  static SubprocessFactory defaultFactory = JavaSubprocessFactory.INSTANCE;

  /**
   * Sets the default factory class for creating subprocesses. Passing {@code null} resets it to the
   * initial state.
   */
  public static void setDefaultSubprocessFactory(SubprocessFactory factory) {
    SubprocessBuilder.defaultFactory = factory != null ? factory : JavaSubprocessFactory.INSTANCE;
  }

  public SubprocessBuilder() {
    this(defaultFactory);
  }

  public SubprocessBuilder(SubprocessFactory factory) {
    stdoutAction = StreamAction.STREAM;
    stderrAction = StreamAction.STREAM;
    this.factory = factory;
  }

  /**
   * Returns the complete argv, including argv0.
   *
   * <p>argv[0] is either absolute (e.g. "/foo/bar" or "c:/foo/bar.exe"), or is a single file name
   * (no directory component, e.g. "true" or "cmd.exe"). It might be non-normalized though (e.g.
   * "/foo/../bar/./baz").
   */
  public ImmutableList<String> getArgv() {
    return argv;
  }

  /**
   * Sets the argv, including argv[0], that is, the binary to execute.
   *
   * <p>argv[0] must be either absolute (e.g. "/foo/bar" or "c:/foo/bar.exe"), or a single file name
   * (no directory component, e.g. "true" or "cmd.exe") which should be on the OS-specific search
   * path (PATH on Unixes, Windows-specific lookup paths on Windows).
   *
   * @throws IllegalArgumentException if argv is empty, or its first element (which becomes
   *     this.argv[0]) is neither an absolute path nor just a single file name
   */
  public SubprocessBuilder setArgv(ImmutableList<String> argv) {
    this.argv = Preconditions.checkNotNull(argv);
    Preconditions.checkArgument(!this.argv.isEmpty());
    File argv0 = new File(this.argv.get(0));
    Preconditions.checkArgument(
        argv0.isAbsolute() || argv0.getParent() == null,
        "argv[0] = '%s'; it should be either absolute or just a single file name"
            + " (no directory component)",
        this.argv.get(0));
    return this;
  }

  public ImmutableMap<String, String> getEnv() {
    return env;
  }

  /**
   * Sets the environment passed to the child process. If null, inherit the environment of the
   * server.
   */
  public SubprocessBuilder setEnv(@Nullable Map<String, String> env) {
    this.env = env == null ? null : ImmutableMap.copyOf(env);
    return this;
  }

  public StreamAction getStdout() {
    return stdoutAction;
  }

  public File getStdoutFile() {
    return stdoutFile;
  }

  /**
   * Tells the object what to do with stdout: either stream as a {@code InputStream} or discard.
   *
   * <p>It can also be redirected to a file using {@link #setStdout(File)}.
   */
  public SubprocessBuilder setStdout(StreamAction action) {
    if (action == StreamAction.REDIRECT) {
      throw new IllegalStateException();
    }
    this.stdoutAction = action;
    this.stdoutFile = null;
    return this;
  }

  /**
   * Sets the file stdout is appended to. If null, the stdout will be available as an input stream
   * on the resulting object representing the process.
   */
  public SubprocessBuilder setStdout(File file) {
    this.stdoutAction = StreamAction.REDIRECT;
    this.stdoutFile = file;
    return this;
  }

  public SubprocessBuilder setTimeoutMillis(long timeoutMillis) {
    this.timeoutMillis = timeoutMillis;
    return this;
  }

  public long getTimeoutMillis() {
    return timeoutMillis;
  }

  public StreamAction getStderr() {
    return stderrAction;
  }

  public File getStderrFile() {
    return stderrFile;
  }

  /**
   * Tells the object what to do with stderr: either stream as a {@code InputStream} or discard.
   *
   * <p>It can also be redirected to a file using {@link #setStderr(File)}.
   */
  public SubprocessBuilder setStderr(StreamAction action) {
    if (action == StreamAction.REDIRECT) {
      throw new IllegalStateException();
    }
    this.stderrAction = action;
    this.stderrFile = null;
    return this;
  }

  /**
   * Sets the file stderr is appended to. If null, the stderr will be available as an input stream
   * on the resulting object representing the process. When {@code redirectErrorStream} is set to
   * True, this method has no effect.
   */
  public SubprocessBuilder setStderr(File file) {
    this.stderrAction = StreamAction.REDIRECT;
    this.stderrFile = file;
    return this;
  }

  /**
   * Tells whether this process builder merges standard error and standard output.
   *
   * @return this process builder's {@code redirectErrorStream} property
   */
  public boolean redirectErrorStream() {
    return redirectErrorStream;
  }

  /**
   * Sets whether this process builder merges standard error and standard output.
   *
   * <p>If this property is {@code true}, then any error output generated by subprocesses
   * subsequently started by this object's {@link #start()} method will be merged with the standard
   * output, so that both can be read using the {@link Subprocess#getInputStream()} method. This
   * makes it easier to correlate error messages with the corresponding output. The initial value is
   * {@code false}.
   */
  public SubprocessBuilder redirectErrorStream(boolean redirectErrorStream) {
    this.redirectErrorStream = redirectErrorStream;
    return this;
  }

  public File getWorkingDirectory() {
    return workingDirectory;
  }

  /**
   * Sets the current working directory. If null, it will be that of this process.
   */
  public SubprocessBuilder setWorkingDirectory(File workingDirectory) {
    this.workingDirectory = workingDirectory;
    return this;
  }

  public Subprocess start() throws IOException {
    return factory.create(this);
  }
}
