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
RUN quilt push -a
RUN debian/rules binary
