## Setup instructions (only required once)
## From the Bazel source root directory:
# apt install qemu-user-static ninja-build debian-ports-archive-keyring
# cd ..
# git clone https://github.com/qemu/qemu.git
# cd qemu
# ./configure --static --disable-system --target-list=riscv64-linux-user
# make
# make docker-image-debian-bootstrap V=1 J=9 DEB_TYPE=sid DEB_ARCH=riscv64 DEB_VARIANT=buildd DEB_URL=http://ftp.ports.debian.org/debian-ports/ DEB_KEYRING="/usr/share/keyrings/debian-ports-archive-keyring.gpg --include=debian-ports-archive-keyring" EXECUTABLE=./riscv64-linux-user/qemu-riscv64
##
## Subsequently, run the build in the Bazel source root directory:
# docker build -f debian/riscv64.Dockerfile .
##
FROM qemu/debian-bootstrap
RUN apt-get update && apt-get install -y --no-install-recommends \
  devscripts \
  equivs \
  quilt
COPY . /src
WORKDIR /src
RUN yes | mk-build-deps -i
ENV http_proxy=127.0.0.1:9
ENV https_proxy=127.0.0.1:9
RUN QUILT_PATCHES="debian/patches" quilt push -a
RUN debian/rules binary
