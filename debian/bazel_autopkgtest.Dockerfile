# Fetches the current unstable or experimental bazel-bootstrap package and
# runs the autopkgtest suite on it in a sid (unstable) container.
# Used for upstream troubleshooting.
# Build in parent directory with:
# docker build -f debian/bazel_autopkgtest.Dockerfile -t bazel_autopkgtest .
# Execute with: (schroot requires --privileged)
# docker run --privileged bazel_autopkgtest [exp]
# The optional "exp" parameter will test the experimental package, otherwise
# the unstable package will be tested.

FROM debian:sid-slim
# Add deb-src for use by autopkgtest
RUN echo "deb-src http://deb.debian.org/debian sid main" >\
 /etc/apt/sources.list.d/deb-src.list

# Set up autopkgtest
RUN apt-get update && apt-get install -y --install-recommends\
 autopkgtest\
 eatmydata\
 sbuild\
 && rm -rf /var/lib/apt/lists/*
# Use eatmydata to speed up the test
# Make tarball since union-type doesn't work in a Docker container
# Make the conf filename standardized
RUN sbuild-createchroot --arch=amd64 --include=eatmydata\
 --make-sbuild-tarball=/srv/chroot/unstable-amd64.tar.xz\
 --alias=sid --command-prefix=eatmydata\
 unstable /srv/sbuild/unstable\
 http://deb.debian.org/debian &&\
 mv /etc/schroot/chroot.d/unstable-amd64-sbuild-*\
 /etc/schroot/chroot.d/unstable-amd64-sbuild.conf

# Variable to use Unstable package for test
ENV sid_test --pin-packages=unstable=src:bazel-bootstrap

# Variable to use Experimental package for test
ENV exp_test --pin-packages=experimental=src:bazel-bootstrap --add-apt-source=\'deb-src http://deb.debian.org/debian experimental main\' --add-apt-source=\'deb http://deb.debian.org/debian experimental main\'

# Placeholder variable for actual test arguments
ENV test_command " "

# Create the test script to determine which pageages to use,
# update the chroot, then run autopkgtest
RUN echo "#!/bin/bash" > /bin/test_command_script
RUN echo "if [ \${1}x = 'expx' ]; then" >> /bin/test_command_script
RUN echo 'test_command="${exp_test}"' >> /bin/test_command_script
RUN echo "else" >> /bin/test_command_script
RUN echo 'test_command="${sid_test}"' >> /bin/test_command_script
RUN echo "fi" >> /bin/test_command_script
RUN echo "sbuild-update -udr unstable-amd64-sbuild" >> /bin/test_command_script
RUN echo "autopkgtest --apt-upgrade \${test_command} bazel-bootstrap -- schroot unstable-amd64-sbuild" >> /bin/test_command_script
RUN chmod a+x /bin/test_command_script

# Update chroot then run autopkgtest
ENTRYPOINT ["/bin/bash", "/bin/test_command_script"]CMD [""]
