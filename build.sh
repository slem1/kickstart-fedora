#!/bin/sh

if [[ ! -d target/ ]]; then
  mkdir target/
fi

cat install-src.ks > target/install.ks

echo "%post" >> target/install.ks

cat post-install.sh >> target/install.ks

echo "%end" >> target/install.ks

echo "Compilation end"
