#!/usr/bin/env sh

set -ev

SCRIPT_DIR=$(dirname "$0")

CODE_DIR=$(cd $SCRIPT_DIR/..; pwd)
echo $CODE_DIR
 
mkdir -p $CODE_DIR/build
BUILD_DIR=$CODE_DIR/build

cp -r $CODE_DIR/docker $BUILD_DIR/
cp -r $CODE_DIR/images/ $BUILD_DIR/docker/catalogue/images/
cp -r $CODE_DIR/cmd/ $BUILD_DIR/docker/catalogue/cmd/
cp $CODE_DIR/*.go $BUILD_DIR/docker/catalogue/
mkdir -p $BUILD_DIR/docker/catalogue/vendor/ && \
cp $CODE_DIR/vendor/manifest $BUILD_DIR/docker/catalogue/vendor/

# docker build -t jbraeuer/catalogue:latest -f $BUILD_DIR/docker/catalogue/Dockerfile $BUILD_DIR/docker/catalogue;

# docker build -t jbraeuer/catalogue-db:latest -f $BUILD_DIR/docker/catalogue-db/Dockerfile $BUILD_DIR/docker/catalogue-db/;

# rm -rf $BUILD_DIR

# docker push jbraeuer/catalogue:latest

# docker push jbraeuer/catalogue-db:latest
