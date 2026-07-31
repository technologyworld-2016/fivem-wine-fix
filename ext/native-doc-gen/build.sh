#!/bin/sh

set -xe

ROOT=$(pwd)
LUA53=lua5.3
NODE=node
YARN=yarn

[ "$OS" == "Windows_NT" ] && LUA53=./lua53
[ "$OS" == "Windows_NT" ] && NODE=$ROOT/node
[ "$OS" != "Windows_NT" ] && NODE=/tmp/node/node/bin/node
YARN="$NODE $ROOT/yarn_cli.js --mutex network"

[ "$OS" == "Windows_NT" ] && curl -z node.exe --retry 3 --retry-delay 5 -Lo node.exe https://nodejs.org/dist/v20.12.1/win-x64/node.exe --http1.1
[ "$OS" != "Windows_NT" ] && mkdir /tmp/node && \
	curl -Lo /tmp/node/node.tar.gz https://content.cfx.re/mirrors/vendor/node/v12.22.12/node-v12.22.12-linux-x64-musl.tar.gz && \
	tar -C /tmp/node -xf /tmp/node/node.tar.gz && \
	mv /tmp/node/node-* /tmp/node/node

# install yarn deps
cd $ROOT/../native-doc-tooling/

# node-gyp >= 12.1.0 supports Visual Studio 2026 (18.x) on windows-latest runners
# --ignore-engines: 12.1.0 declares node ^20.17.0, but we use 20.12.1 (pre CVE-2024-27980, spawn EINVAL)
$YARN global add node-gyp@12.1.0 --ignore-engines
# install all deps with node-gyp 12.1.0 locally so node-gyp-build spawns a VS2026-aware node-gyp
# --ignore-scripts: ffi-napi's postinstall would fail; build it manually below
$YARN add node-gyp@12.1.0 --ignore-scripts --ignore-engines

# gyp-next regression vs gyp 9.x: rules whose action already starts with 'call'
# (libffi preprocess_asm) are emitted as `call "call" script.cmd` which cmd.exe
# cannot run ('"call"' is not recognized). node-gyp 9 emitted `call call script.cmd`.
cat > /tmp/patch-msvs.py.js <<'EOF'
const fs = require('fs');
const p = 'node_modules/node-gyp/gyp/pylib/gyp/generator/msvs.py';
const old = "command[1] = '\"%s\"' % command[1]";
const neu = "if command[1] != 'call':\n            command[1] = '\"%s\"' % command[1]";
const s = fs.readFileSync(p, 'utf8');
if (!s.includes(old)) { console.error('PATCH SKIPPED: msvs.py pattern not found'); process.exit(1); }
fs.writeFileSync(p, s.replace(old, neu));
console.log('patched gyp msvs.py: skip quoting when command is already call');
EOF
$NODE /tmp/patch-msvs.py.js

# ffi-napi postinstall was skipped by --ignore-scripts, build it manually
# (node-gyp uses VCINSTALLDIR/VSCMD_VER env vars to find VS2026)
cd node_modules/ffi-napi
PATH="$PWD/../../.bin:$PATH" $NODE ../../node-gyp/bin/node-gyp.js rebuild

cd $ROOT/../natives/

NATIVES_MD_DIR=$ROOT/../native-decls/native_md/ $LUA53 codegen.lua inp/natives_global.lua markdown server rpc

# make out dir
cd $ROOT
mkdir out || true

# enter out dir
cd out

# setup clang and build
[ "$OS" == "Windows_NT" ] && cp -a $ROOT/libclang.dll $PWD/libclang.dll || true
$NODE $ROOT/../native-doc-tooling/index.js $ROOT/../native-decls/

mkdir -p $ROOT/../natives/inp/ || true

NODE_PATH=$ROOT/../native-doc-tooling/node_modules/ $NODE $ROOT/../native-doc-tooling/build-template.js lua CFX > $ROOT/../natives/inp/natives_cfx_new.lua
rm $PWD/libclang.dll || true

# copy outputs
cd $ROOT
cp -a out/natives_test.json natives_cfx.json

# copy new
if [ -e $ROOT/../natives/inp/natives_cfx.lua ]; then
	if ! diff -q $ROOT/../natives/inp/natives_cfx_new.lua $ROOT/../natives/inp/natives_cfx.lua 2>&1 > /dev/null; then
		cp -a $ROOT/../natives/inp/natives_cfx_new.lua $ROOT/../natives/inp/natives_cfx.lua
	fi
else
    cp -a $ROOT/../natives/inp/natives_cfx_new.lua $ROOT/../natives/inp/natives_cfx.lua
fi

[ "$OS" != "Windows_NT" ] && rm -rf /tmp/node || true
