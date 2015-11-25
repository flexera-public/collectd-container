FROM debian
MAINTAINER tve@rightscale.com

# Install dependencies of collectd so we get most plugins included that are useful in a cloud
# environment.
RUN apt-get update -qq && \
    apt-get install -yqq build-essential curl libcurl4-gnutls-dev libmysqlclient-dev \
                         libhiredis-dev liboping-dev libyajl-dev libpq-dev &&\
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Compile collectd from source in order to change the location of /proc to /host/proc,
# this assumes the container is launched with -v /proc:/host/proc
RUN curl https://collectd.org/files/collectd-5.5.0.tar.gz | tar zxf - &&\
    cd collectd* &&\
    ./configure --prefix=/usr --sysconfdir=/etc/collectd --localstatedir=/var --enable-debug &&\
    grep -rl /proc/ . | xargs sed -i "s/\/proc\//\/host\/proc\//g" &&\
    make all install &&\
    make clean

WORKDIR /root
COPY configure.sh /root/configure.sh
RUN chmod +x /root/configure.sh
RUN mkdir -p /host

