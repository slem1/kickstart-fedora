#!/bin/sh

if [[ ! -d target/ ]]; then
  mkdir target/
fi

echo "# generated on $(date)" > target/install.ks

cat install-src.ks >> target/install.ks

echo "%post" >> target/install.ks

cat post-install.sh >> target/install.ks

echo "%end" >> target/install.ks

echo "Compilation end"
