#!/usr/bin/env bash

fork=starship/starship
target=unknown-linux-musl
release="$1"
key='Luke Carrier (starship-repo signing) <luke+starship-repo@carrier.family>'

gh release view --json assets --repo "$fork" "v${release}" >assets.json

jq '[.assets[] | select(.name | contains("-'$target'."))]' assets.json >target-assets.json

jq -r '.[].url' target-assets.json >wget-files
wget --input-file wget-files

for a in *.tar.gz; do
  gunzip --keep $a
done

# FIXME: checksums don't seem to match. This might be down to the gzip
# implementation?
# truncate --size 0 sha256sum
# for s in *.sha256; do
#   echo "$(cat $s)"$'\t'"${s::-10}" >>sha256sum
# done
# sha256sum --check sha256sum

for t in *.tar; do
  triple="${t:9:-4}"
  arch="${triple%%-*}"
  case $arch in
    x86_64)
      arch=amd64
      ;;
  esac
  name="starship-${release}-${arch}"

  mkdir -p "$triple/$name"
  pushd "$triple" >/dev/null
  pushd "$name" >/dev/null
  cp -R ../../../DEBIAN .
  sed -i "s/VERSION/${release}/g;s/ARCHITECTURE/${arch}/g" DEBIAN/control

  tar -xf "../../${t}"
  mkdir -p usr/bin
  mv starship usr/bin
  sudo chown -R root:root usr
  sudo chmod 0755 usr/bin/starship

  popd >/dev/null
  dpkg -b "$name"
  popd >/dev/null
done

mv */*.deb ../docs
pushd ../docs >/dev/null
dpkg-scanpackages --multiversion . >Packages
apt-ftparchive release . >Release
gpg --default-key "$key" -abs -o - Release >Release.gpg
gpg --default-key "$key" --clearsign -o - Release >InRelease

git add .
git commit --message "Release ${release}"
git push origin main
popd >/dev/null
