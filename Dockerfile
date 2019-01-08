FROM node:8.15.0-jessie

RUN npm config set registry https://registry.npm.taobao.org && \
    apt-get install git 
