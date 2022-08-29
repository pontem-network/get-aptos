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
  # aptos_version="aptos-cli-v0.1.2";
  # version_tag="aptos-cli-devnet-2022-06-09"
  # version_tag=$(cat "$releases_path" | jq -r '.[] | select(("${select_prerelease}") and (.tag_name | contains("cli"))) .tag_name' | head -n1);
  aptos_version=$(cat "$releases_path" | jq -r '.[] | select(("${select_prerelease}") and (.tag_name | contains("cli"))) .tag_name' | head -n1);
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
# this is fix for v0.3.1 
asset_filename=aptos-$(echo $filename | sed 's/v//')
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

# ======================================================================================================================
# prover env
# ======================================================================================================================

Z3_VERSION=4.11.0
CVC5_VERSION=0.0.3
DOTNET_VERSION=6.0
BOOGIE_VERSION=2.15.7

function add_to_profile {
  eval "$1"
  FOUND=$(grep -c "$1" < "${HOME}/.profile" || true)  # grep error return would kill the script.
  if [ "$FOUND" == "0" ]; then
    echo "$1" >> "${HOME}"/.profile
  fi
}

function update_path_and_profile {
  touch "${HOME}"/.profile

  DOTNET_ROOT="$HOME/.dotnet"
  BIN_DIR="$HOME/bin"

  add_to_profile "export DOTNET_ROOT=\"${DOTNET_ROOT}\""
  add_to_profile "export PATH=\"${DOTNET_ROOT}/tools:\$PATH\""
  add_to_profile "export Z3_EXE=\"${BIN_DIR}/z3\""
  add_to_profile "export CVC5_EXE=\"${BIN_DIR}/cvc5\""
  add_to_profile "export BOOGIE_EXE=\"${DOTNET_ROOT}/tools/boogie\""
}

function install_pkg {
  package=$1
  PACKAGE_MANAGER=$2
  PRE_COMMAND=()
  if [ "$(whoami)" != 'root' ]; then
    PRE_COMMAND=(sudo)
  fi
  if command -v "$package" &>/dev/null; then
    echo "$package is already installed"
  else
    echo "Installing ${package}."
    if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
      "${PRE_COMMAND[@]}" yum install "${package}" -y
    elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
      "${PRE_COMMAND[@]}" apt-get install "${package}" --no-install-recommends -y
      echo apt-get install result code: $?
    elif [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
      "${PRE_COMMAND[@]}" pacman -Syu "$package" --noconfirm
    elif [[ "$PACKAGE_MANAGER" == "apk" ]]; then
      apk --update add --no-cache "${package}"
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
      dnf install "$package"
    elif [[ "$PACKAGE_MANAGER" == "brew" ]]; then
      brew install "$package"
    fi
  fi
}

function install_dotnet {
  echo "Installing .Net"
  mkdir -p "${DOTNET_INSTALL_DIR}" || true
  if [[ $("${DOTNET_INSTALL_DIR}/dotnet" --list-sdks | grep -c "^${DOTNET_VERSION}" || true) == "0" ]]; then
    if [[ "$(uname)" == "Linux" ]]; then
        # Install various prerequisites for .dotnet. There are known bugs
        # in the dotnet installer to warn even if they are present. We try
        # to install anyway based on the warnings the dotnet installer creates.
        if [ "$PACKAGE_MANAGER" == "apk" ]; then
          install_pkg icu "$PACKAGE_MANAGER"
          install_pkg zlib "$PACKAGE_MANAGER"
          install_pkg libintl "$PACKAGE_MANAGER"
          install_pkg libcurl "$PACKAGE_MANAGER"
        elif [ "$PACKAGE_MANAGER" == "apt-get" ]; then
          install_pkg gettext "$PACKAGE_MANAGER"
          install_pkg zlib1g "$PACKAGE_MANAGER"
        elif [ "$PACKAGE_MANAGER" == "yum" ] || [ "$PACKAGE_MANAGER" == "dnf" ]; then
          install_pkg icu "$PACKAGE_MANAGER"
          install_pkg zlib "$PACKAGE_MANAGER"
        elif [ "$PACKAGE_MANAGER" == "pacman" ]; then
          install_pkg icu "$PACKAGE_MANAGER"
          install_pkg zlib "$PACKAGE_MANAGER"
        fi
    fi
    # Below we need to (a) set TERM variable because the .net installer expects it and it is not set
    # in some environments (b) use bash not sh because the installer uses bash features.
    curl -sSL https://dot.net/v1/dotnet-install.sh \
        | TERM=linux /bin/bash -s -- --channel $DOTNET_VERSION --install-dir "${DOTNET_INSTALL_DIR}" --version latest
  else
    echo Dotnet already installed.
  fi
}

function install_boogie {
  echo "Installing boogie"
  mkdir -p "${DOTNET_INSTALL_DIR}tools/" || true
  if [[ "$("${DOTNET_INSTALL_DIR}dotnet" tool list --tool-path "${DOTNET_INSTALL_DIR}tools/")" =~ .*boogie.*${BOOGIE_VERSION}.* ]]; then
    echo "Boogie $BOOGIE_VERSION already installed"
  else
    "${DOTNET_INSTALL_DIR}dotnet" tool update --tool-path "${DOTNET_INSTALL_DIR}tools/" Boogie --version $BOOGIE_VERSION
  fi
}

function install_z3 {
  echo "Installing Z3"
  if command -v /usr/local/bin/z3 &>/dev/null; then
    echo "z3 already exists at /usr/local/bin/z3"
    echo "but this install will go to ${INSTALL_DIR}/z3."
    echo "you may want to remove the shared instance to avoid version confusion"
  fi
  if command -v "${INSTALL_DIR}z3" &>/dev/null && [[ "$("${INSTALL_DIR}z3" --version || true)" =~ .*${Z3_VERSION}.* ]]; then
     echo "Z3 ${Z3_VERSION} already installed"
     return
  fi
  if [[ "$(uname)" == "Linux" ]]; then
    Z3_PKG="z3-$Z3_VERSION-x64-glibc-2.31"
  elif [[ "$(uname)" == "Darwin" ]]; then
    Z3_PKG="z3-$Z3_VERSION-x64-osx-10.16"
  else
    echo "Z3 support not configured for this platform (uname=$(uname))"
    return
  fi
  TMPFILE=$(mktemp)
  rm "$TMPFILE"
  mkdir -p "$TMPFILE"/
  (
    cd "$TMPFILE" || exit
    curl -LOs "https://github.com/Z3Prover/z3/releases/download/z3-$Z3_VERSION/$Z3_PKG.zip"
    unzip -q "$Z3_PKG.zip"
    cp "$Z3_PKG/bin/z3" "${INSTALL_DIR}"
    chmod +x "${INSTALL_DIR}z3"
  )
  rm -rf "$TMPFILE"
}

function install_cvc5 {
  echo "Installing cvc5"
  if command -v /usr/local/bin/cvc5 &>/dev/null; then
    echo "cvc5 already exists at /usr/local/bin/cvc5"
    echo "but this install will go to $${INSTALL_DIR}cvc5."
    echo "you may want to remove the shared instance to avoid version confusion"
  fi
  if command -v "${INSTALL_DIR}cvc5" &>/dev/null && [[ "$("${INSTALL_DIR}cvc5" --version || true)" =~ .*${CVC5_VERSION}.* ]]; then
     echo "cvc5 ${CVC5_VERSION} already installed"
     return
  fi
  if [[ "$(uname)" == "Linux" ]]; then
    CVC5_PKG="cvc5-Linux"
  elif [[ "$(uname)" == "Darwin" ]]; then
    CVC5_PKG="cvc5-macOS"
  else
    echo "cvc5 support not configured for this platform (uname=$(uname))"
    return
  fi
  TMPFILE=$(mktemp)
  rm "$TMPFILE"
  mkdir -p "$TMPFILE"/
  (
    cd "$TMPFILE" || exit
    curl -LOs "https://github.com/cvc5/cvc5/releases/download/cvc5-$CVC5_VERSION/$CVC5_PKG"
    cp "$CVC5_PKG" "${INSTALL_DIR}cvc5"
    chmod +x "${INSTALL_DIR}cvc5"
  )
  rm -rf "$TMPFILE"
}

PACKAGE_MANAGER=
if [[ "$(uname)" == "Linux" ]]; then
	if command -v yum &> /dev/null; then
		PACKAGE_MANAGER="yum"
	elif command -v apt-get &> /dev/null; then
		PACKAGE_MANAGER="apt-get"
	elif command -v pacman &> /dev/null; then
		PACKAGE_MANAGER="pacman"
  elif command -v apk &>/dev/null; then
		PACKAGE_MANAGER="apk"
  elif command -v dnf &>/dev/null; then
    echo "WARNING: dnf package manager support is experimental"
    PACKAGE_MANAGER="dnf"
	else
		echo "Unable to find supported package manager (yum, apt-get, dnf, or pacman). Abort"
		exit 1
	fi
elif [[ "$(uname)" == "Darwin" ]]; then
	if command -v brew &>/dev/null; then
		PACKAGE_MANAGER="brew"
	else
		echo "Missing package manager Homebrew (https://brew.sh/). Abort"
		exit 1
	fi
else
	echo "Unknown OS. Abort."
	exit 1
fi

if [[ "$PROVER" == "true" ]]; then
  update_path_and_profile
  export DOTNET_INSTALL_DIR="${HOME}/.dotnet/"
  install_z3
  install_cvc5
  install_dotnet
  install_boogie
fi