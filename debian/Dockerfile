# run in the parent directory as `docker build -f debian/Dockerfile .`
FROM debian:sid-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
  devscripts \
  equivs \
  wget \
  quilt
RUN wget https://people.debian.org/~crusoe/bazel/libchecker-framework-java_3.0.1+ds-1~0bazel_all.deb
RUN apt-get install ./libchecker-framework-java_3.0.1+ds-1~0bazel_all.deb
COPY . /src
WORKDIR /src
RUN mkdir -p /usr/share/man/man1 # needed due to using a "-slim" image that otherwise does not have manpages
RUN yes | mk-build-deps -i
# RUN uscan --download-current-version --verbose
# RUN dpkg-buildpackage -uc -us
# too slow
ENV http_proxy=127.0.0.1:9
ENV https_proxy=127.0.0.1:9

RUN patch -p1 < debian/patches/mock_repos.patch
RUN patch -p1 < debian/patches/remove_grpc_api.patch
RUN patch -p1 < debian/patches/remove_javac.patch
RUN patch -p1 < debian/patches/remove_license_deps.patch
RUN patch -p1 < debian/patches/replace_grpc_java_plugin.patch
RUN patch -p1 < debian/patches/WORKSPACE.patch
RUN patch -p1 < debian/patches/package_before_making_self-extracting.patch
RUN patch -p1 < debian/patches/env_python3.patch
RUN patch -p1 < debian/patches/add-trust_install_base-option.patch
RUN patch -p1 < debian/patches/allow-install-base-symlinks.patch

RUN debian/rules binary
