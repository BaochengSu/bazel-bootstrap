# Fetches the current experimental bazel-bootstrap package and runs the
# autopkgtest suite on it in a sid (unstable) container.
# Used for upstream troubleshooting.
# Build with:
# docker build -f bazel_autopkgtest.Dockerfile -t bazel_autopkgtest .
# Execute with: (schroot requires --privileged)
# docker run --privileged bazel_autopkgtest

FROM debian:sid-slim
RUN apt-get update && apt-get install -y --install-recommends\
 autopkgtest\
 eatmydata\
 sbuild\
 && rm -rf /var/lib/apt/lists/*
# Use eatmydata to speed up the test
# Use no-deb-src to improve performance by not fetching source repo in chroot
# Make tarball since union-type doesn't work in a Docker container
# Make the conf filename standardized
RUN sbuild-createchroot --arch=amd64 --include=eatmydata --no-deb-src\
 --make-sbuild-tarball=/srv/chroot/unstable-amd64.tar.xz\
 --alias=sid --command-prefix=eatmydata\
 unstable /srv/sbuild/unstable\
 http://deb.debian.org/debian &&\
 mv /etc/schroot/chroot.d/unstable-amd64-sbuild-* /etc/schroot/chroot.d/unstable-amd64-sbuild.conf

# Update chroot then run autopkgtest from Debian experimental
ENTRYPOINT sbuild-update -udr unstable-amd64-sbuild &&\
 autopkgtest\
 '--setup-commands=echo '"'"'Acquire::Retries "10";'"'"' > /etc/apt/apt.conf.d/75retry 2>&1 || true'\
## Experimental
# --apt-upgrade --pin-packages=experimental=src:bazel-bootstrap\
# '--add-apt-source=deb-src http://deb.debian.org/debian experimental main\
# deb http://deb.debian.org/debian experimental main'\
## Unstable
 --apt-upgrade --pin-packages=unstable=src:bazel-bootstrap\
 '--add-apt-source=deb-src http://deb.debian.org/debian unstable main\
 deb http://deb.debian.org/debian unstable main'\
 bazel-bootstrap -- schroot unstable-amd64-sbuild
