FROM ubuntu:14.04

RUN apt-get update

RUN apt-get install -y ruby ruby-dev build-essential curl mysql-client \
        libmysqlclient-dev

RUN curl http://johnvansickle.com/ffmpeg/builds/ffmpeg-git-64bit-static.tar.xz \
        | tar -xvJ -C /usr/local/bin --strip-components=1 --wildcards \
            \*/ffprobe \*/ffmpeg

RUN gem install aws-sdk bson mimemagic mysql2

ADD . /opt/chimps/
