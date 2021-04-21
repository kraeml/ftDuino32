FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive

# We need libpython2.7 due to GDB tools
RUN apt-get update && apt-get install -y \
    apt-utils \
    bison \
    ca-certificates \
    ccache \
    check \
    curl \
    flex \
    git \
    gperf \
    lcov \
    libncurses-dev \
    libusb-1.0-0-dev \
    make \
    ninja-build \
    libpython2.7 \
    python3 \
    python3-pip \
    python \
    screen \
    unzip \
    wget \
    xz-utils \
    zip \
   && apt-get autoremove -y \
   && rm -rf /var/lib/apt/lists/* \
   && update-alternatives --install /usr/bin/python python /usr/bin/python3 10

RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install \
      virtualenv \
      pyparsing==2.3.1 \
      esptool \
      adafruit-ampy

# To build the image for a branch or a tag of IDF, pass --build-arg IDF_CLONE_BRANCH_OR_TAG=name.
# To build the image with a specific commit ID of IDF, pass --build-arg IDF_CHECKOUT_REF=commit-id.
# It is possibe to combine both, e.g.:
#   IDF_CLONE_BRANCH_OR_TAG=release/vX.Y
#   IDF_CHECKOUT_REF=<some commit on release/vX.Y branch>.

ARG IDF_CLONE_URL=https://github.com/espressif/esp-idf.git
ARG IDF_CLONE_BRANCH_OR_TAG=master
ARG IDF_CHECKOUT_REF=4c81978a3e2220674a432a588292a4c860eef27b

ENV IDF_PATH=/opt/esp/idf
ENV IDF_TOOLS_PATH=/opt/esp

RUN echo IDF_CHECKOUT_REF=$IDF_CHECKOUT_REF IDF_CLONE_BRANCH_OR_TAG=$IDF_CLONE_BRANCH_OR_TAG && \
    git clone --recursive \
      ${IDF_CLONE_BRANCH_OR_TAG:+-b $IDF_CLONE_BRANCH_OR_TAG} \
      $IDF_CLONE_URL $IDF_PATH && \
    if [ -n "$IDF_CHECKOUT_REF" ]; then \
      cd $IDF_PATH && \
      git checkout $IDF_CHECKOUT_REF && \
      git submodule update --init --recursive; \
    fi

# Install all the required tools, plus CMake
RUN $IDF_PATH/tools/idf_tools.py --non-interactive install required \
  && $IDF_PATH/tools/idf_tools.py --non-interactive install cmake \
  && $IDF_PATH/tools/idf_tools.py --non-interactive install-python-env \
  && rm -rf $IDF_TOOLS_PATH/dist

# Add the latest http server including websocket support to the
COPY patches/esp-idf.patch $IDF_PATH/esp-idf.patch
RUN cd $IDF_PATH && \
    patch -p1 < esp-idf.patch && \
    rm esp-idf.patch

# Ccache is installed, enable it by default
ENV IDF_CCACHE_ENABLE=1

###############################################################################
# Build LV Micropython
###############################################################################

WORKDIR /app/
# RUN git clone https://github.com/derekenos/micropython --branch=1.13
RUN git clone --recurse-submodules https://github.com/littlevgl/lv_micropython.git

# Build the firmare
# https://github.com/micropython/micropython/tree/master/ports/esp32#building-the-firmware
WORKDIR /app/lv_micropython

COPY patches/http_server.patch patches/lvgl.patch patches/uzlib_compression.patch ./
# Build the cross compiler.
RUN patch -p1 < http_server.patch && \
    patch -p1 < lvgl.patch && \
    patch -p1 < uzlib_compression.patch && \
    rm *.patch && \
    make -C mpy-cross

RUN echo 'function freeze(){ /app/lv_micropython/mpy-cross/mpy-cross $1;  '\
    'chown `stat -c%u $1` ${1%%.*}.mpy; }' >>  ~/.bashrc

# Build the desired ports.
WORKDIR ports/esp32

ENV PATH=$PATH:/opt/esp/tools/xtensa-esp32-elf/esp-2019r2-8.2.0/xtensa-esp32-elf/bin

RUN make BOARD=GENERIC_SPIRAM all

###############################################################################
# Install Device Management Utilities
###############################################################################

ENV DEVICE_PORT=/dev/ttyUSB0

RUN echo export DEVICE_PORT=$DEVICE_PORT >>  ~/.bashrc

# Install Adafruit ampy utility for interacting with the pyboard filesystem.
ENV AMPY_PORT=$DEVICE_PORT

RUN echo export AMPY_PORT=$DEVICE_PORT >>  ~/.bashrc


# Confugure esptool
ENV ESPTOOL_PORT=$DEVICE_PORT
RUN echo export ESPTOOL_PORT=$DEVICE_PORT >>  ~/.bashrc

ENV ESPTOOL_BAUD=460800
RUN echo export ESPTOOL_BAUD=460800 >>  ~/.bashrc

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
COPY entrypoint.sh /opt/esp/entrypoint.sh

ENTRYPOINT [ "/opt/esp/entrypoint.sh" ]
###############################################################################
# Copy Custom Scripts
###############################################################################

WORKDIR /app
RUN mkdir scripts
#COPY scripts scripts
RUN mkdir ftduino32

CMD [ "/bin/bash" ]
