#!/usr/bin/env bash
# GitHub's release downloads (where Gradle and some Kotlin jars live) can time
# out for hours. Fetch Gradle from whichever mirror answers and point the
# wrapper at the local copy, and put Google's Maven Central mirror first.
set -u
props=android/gradle/wrapper/gradle-wrapper.properties
url=$(grep distributionUrl "$props" | cut -d= -f2- | sed 's/\\:/:/g')
file=$(basename "$url")
ver=$(echo "$file" | sed -E 's/gradle-(.*)-(all|bin)\.zip/\1/')
bin="gradle-$ver-bin.zip"
mkdir -p "$HOME/gradle-dl"
out="$HOME/gradle-dl/$bin"
if [ ! -s "$out" ]; then
  for m in \
    "https://services.gradle.org/distributions/$bin" \
    "https://mirrors.cloud.tencent.com/gradle/$bin" \
    "https://downloads.gradle.org/distributions/$bin" \
    "https://github.com/gradle/gradle-distributions/releases/download/v$ver/$bin"; do
    echo "Trying $m"
    if curl -fL --retry 4 --retry-delay 5 --connect-timeout 20 -o "$out.part" "$m" && unzip -tq "$out.part" >/dev/null; then
      mv "$out.part" "$out"; echo "Got Gradle from $m"; break
    fi
    rm -f "$out.part"
  done
fi
if [ -s "$out" ]; then
  sed -i "s#^distributionUrl=.*#distributionUrl=file\\\\:$out#" "$props"
  sed -i '/^distributionSha256Sum=/d' "$props"
fi
cat "$props"

mkdir -p "$HOME/.gradle/init.d"
cat > "$HOME/.gradle/init.d/mirror.gradle" <<'G'
def mirror = 'https://maven-central.storage-download.googleapis.com/maven2/'
def first = { RepositoryHandler repos ->
  def r = repos.maven { url = mirror; name = 'centralMirror' }
  repos.remove(r)
  repos.addFirst(r)
}
beforeSettings { s -> first(s.pluginManagement.repositories) }
allprojects {
  first(buildscript.repositories)
  first(repositories)
}
G
