#!/bin/bash

# ======================================================================================================================
# Aptos folder
# ======================================================================================================================
aptosfolder="$HOME/.aptos"
if [ ! -e $aptosfolder ]; then
  echo "Create aptos folder: $aptosfolder";
  mkdir -p $aptosfolder;
fi;

# ======================================================================================================================
# Token
# ======================================================================================================================
if [[ -z $SECRET_TOKEN ]]; then
  SECRET_TOKEN="";
  if [[ ! -z $2 ]]; then
    SECRET_TOKEN=$2;
  fi;
fi;
if [[ ! -z $SECRET_TOKEN ]]; then
  echo "Token: ***";
fi;

# ======================================================================================================================
# releases.json
# ======================================================================================================================
releases_path="$aptosfolder/releases.json";
if [ ! -e $releases_path ] || [ $(($(date "+%s")-$(date -r $releases_path "+%s" ))) -ge 600 ]; then
  echo "Download: releases.json";
  if [ -z $SECRET_TOKEN ]; then
    curl -o "$releases_path.tmp" \
        -s https://api.github.com/repos/aptos-labs/aptos-core/releases;
  else
    curl -o "$releases_path.tmp" \
        -H "Authorization: Bearer ${SECRET_TOKEN}" \
        -s https://api.github.com/repos/aptos-labs/aptos-core/releases;
  fi;
  mv "$releases_path.tmp" $releases_path;
fi;
# check release.json
message=$(jq '.message?' -r $releases_path);
if [[ ! -z $message ]]; then
  echo "Message: $message";
  rm $releases_path;
  exit 4;
fi

# ======================================================================================================================
# pre-release (prerelease=true)
# ======================================================================================================================
if [[ -z $APTOS_PRERELEASE ]]; then
  APTOS_PRERELEASE="false";
  if [[ ! -z $3 ]]; then
    APTOS_PRERELEASE=$3;
  fi;
else
  if [ $APTOS_PRERELEASE != "true" ] && [ $APTOS_PRERELEASE != "false" ]; then
    APTOS_PRERELEASE="false";
  fi;
fi;
echo "Pre-release: $APTOS_PRERELEASE";
select_prerelease="";
if [ $APTOS_PRERELEASE == "false" ]; then
  select_prerelease=".prerelease==false";
else
  select_prerelease=".";
fi
# ======================================================================================================================
# Aptos version
# ======================================================================================================================
aptos_version=""
if [[ ! -z $APTOS_VERSION ]]; then
  aptos_version=$APTOS_VERSION;
elif [[ ! -z $1 ]]; then
  aptos_version=$1;
fi;
if [[ $aptos_version == "latest" || $aptos_version == "new" || $aptos_version == "last" || -z $aptos_version ]]; then
  # Get the latest version
  # !! Temporary fix due to Aptos not using the same standard release names and versions every time
  aptos_version="aptos-cli-v0.1.2";
  version_tag="aptos-cli-devnet-2022-06-09"
  #version_tag=$(cat "$releases_path" | jq -r '.[] | select(("${select_prerelease}") and (.tag_name | contains("cli"))) .tag_name' | head -n1);
  # aptos_version=$(cat "$releases_path" | jq -r '.[] | select(("${select_prerelease}") and (.tag_name | contains("cli"))) .tag_name' | head -n1);
  # if [[ -z $aptos_version ]]; then
  #       echo "{$aptos_version|$APTOS_PRERELEASE} The specified version of aptos was not found";
  #       exit 5;
  #fi
else
  if [ ! $(cat "$releases_path" | jq ".[] | select("${select_prerelease}" and .tag_name==\"${aptos_version}\") .tag_name") ]; then
    echo "{$aptos_version} The specified version of aptos was not found";
    exit 1;
  fi;
fi;
echo "version: $aptos_version";

if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "freebsd"* || "$OSTYPE" == "cygwin" ]]; then
  download_type="Ubuntu-$HOSTTYPE"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  download_type="MacOSX-$HOSTTYPE"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  echo "Windows is not supported at the moment"
else
  echo "Unknown OS"
  exit 2
fi
# ======================================================================================================================
# Download
# ======================================================================================================================
filename="${aptos_version}-${download_type}.zip"
asset_filename=$(echo $filename | sed 's/v//')
file_path="$aptosfolder/$filename"
unziped_file_path="$aptosfolder/aptos"

if [[ -z $version_tag ]]; then
    download_url=$(cat "$releases_path" | 
      jq -r ".[] | select(${select_prerelease} and .tag_name==\"${aptos_version}\") .assets | .[] | select(.name|test(\"^${asset_filename}\")) | .browser_download_url")
else
    download_url=$(cat "$releases_path" | 
      jq -r ".[] | select(${select_prerelease} and .tag_name==\"${version_tag}\") .assets | .[] | select(.name|test(\"^${asset_filename}\")) | .browser_download_url")
fi
if [ -z $download_url ]; then
    download_url=$(cat "$releases_path" |
      jq -r ".[] | select(${select_prerelease} and .tag_name==\"${aptos_version}\") .assets | .[] | select(.name|test(\"^${aptos_version}-${download_type}\")) | .browser_download_url")
  if [ -z $download_url ]; then
    echo "Releases \"${aptos_version}-${download_type}\" not found"
    exit 3
  fi
fi

if [ ! -e $file_path ]; then
  echo "Download: $download_url"
  if [ -z $SECRET_TOKEN ]; then
    curl -sL --fail \
      -H "Accept: application/octet-stream" \
      -o "$file_path.tmp" \
      -s $download_url
  else
    curl -sL --fail \
      -H "Accept: application/octet-stream" \
      -H "Authorization: Bearer ${SECRET_TOKEN}" \
      -o "$file_path.tmp" \
      -s $download_url
  fi
  mv "$file_path.tmp" $file_path
  unzip $file_path -d $aptosfolder
fi

echo "chmod 1755 $unziped_file_path"
chmod 1755 $unziped_file_path

echo "create link $unziped_file_path"
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "freebsd"* || "$OSTYPE" == "cygwin" ]]; then
  mkdir -p $HOME/.local/bin
  ln -sf "$unziped_file_path" $HOME/.local/bin/aptos
  echo "$HOME/.local/bin" >> $GITHUB_PATH
elif [[ "$OSTYPE" == "darwin"* ]]; then
   ln -sf "$unziped_file_path" /usr/local/bin/aptos
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
#   mkdir -p "$HOME/.local/bin"
#   ln -sf "$unziped_file_path" "$HOME/.local/bin/aptos"
#   echo "$HOME/.local/bin" >> $GITHUB_PATH
  echo "Windows is not supported at the moment"
else
  echo "Unknown OS"
  exit 2
fi
# ======================================================================================================================
# run
# ======================================================================================================================
echo "run: $unziped_file_path -V"
#$unziped_file_path -V
aptos -V
