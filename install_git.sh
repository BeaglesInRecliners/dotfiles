#!/bin/bash

if [[ ! -f git-2.5.0.tar.gz ]] ; then
  wget https://www.kernel.org/pub/software/scm/git/git-2.5.0.tar.gz
fi

if [[ ! -d git-2.5.0 ]] ; then
  tar zxf git-2.5.0.tar.gz
fi

#sudo yum install asciidoc xmlto docbook2x
#sudo apt-get install asciidoc xmlto docbook2x

cd git-2.5.0
make configure
./configure --prefix=/$HOME/local
make all -j 10
make install
cd ../


