# Builds the Bazel source code in the parent directory using Debian build
# methods and in a Docker container. Subsequent execution runs the Debian
# autopkgtest suite on the newly-built package.
# Used for upstream troubleshooting.
# Build in the parent directory with:
# docker build -f debian/amd64.Dockerfile -t bazel_docker_build .
# Execute autopkgtest suite with: (schroot requires --privileged)
# docker run --privileged bazel_docker_build

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

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends\
 devscripts\
 equivs\
 quilt

# Build Bazel
COPY . /src/bazel
WORKDIR /src/bazel
# needed due to using a "-slim" image that otherwise does not have manpages
RUN mkdir -p /usr/share/man/man1
RUN yes | mk-build-deps -i
ENV http_proxy=127.0.0.1:9
ENV https_proxy=127.0.0.1:9
RUN QUILT_PATCHES="debian/patches" quilt push -a
RUN debian/rules binary

# Create the test script to update the chroot and then run autopkgtest
RUN echo "#!/bin/bash" > /bin/test_command_script
RUN echo "sbuild-update -udr unstable-amd64-sbuild" >> /bin/test_command_script
RUN echo "autopkgtest --apt-upgrade /src/*.deb /src/bazel -- schroot\
 unstable-amd64-sbuild" >> /bin/test_command_script
RUN chmod a+x /bin/test_command_script

# Execute the test script
ENTRYPOINT ["/bin/bash", "/bin/test_command_script"]
