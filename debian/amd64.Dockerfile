# run in the parent directory as `docker build -f debian/amd64.Dockerfile .`
FROM debian:sid-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
  devscripts \
  equivs \
  quilt
COPY . /src
WORKDIR /src
RUN mkdir -p /usr/share/man/man1 # needed due to using a "-slim" image that otherwise does not have manpages
RUN yes | mk-build-deps -i
# RUN uscan --download-current-version --verbose
# RUN dpkg-buildpackage -uc -us
# too slow
ENV http_proxy=127.0.0.1:9
ENV https_proxy=127.0.0.1:9
RUN QUILT_PATCHES="debian/patches" quilt push -a
RUN debian/rules binary
