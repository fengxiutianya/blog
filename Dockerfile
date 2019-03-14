FROM node:6.17.0-jessie

RUN npm config set registry https://registry.npm.taobao.org && \
    apt-get install git 
