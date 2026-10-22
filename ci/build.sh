#!/bin/bash
# Builds and checks the addon (run by .github/workflows/build.yml): data from the app, engine tests against
# the app's engine, the API check against Blizzard's own interface code, the clicked-through UI test, the
# screen pictures, and the zip to install.
set -e
mkdir -p build out
exec > >(tee build/build.log) 2>&1
VERSION="$(node -p "require('./package.json').version")"
echo "== TBCrushCalc addon $VERSION, build ${GITHUB_RUN_NUMBER:-?}"

echo "== data from the app"
node tools/export_data.mjs app
git diff --stat --exit-code -- TBCrushCalc_Data || { echo "!! TBCrushCalc_Data is out of date with the app: run npm run data and commit"; exit 1; }

echo "== engine: 400 random characters against the app's engine, the wowsims tanks, rules and share codes"
node tools/oracle.mjs app 400
lua5.1 tests/run.lua | tee build/engine.log
node tools/check_codes.mjs app | tee -a build/engine.log

echo "== only what the TBC Anniversary client has"
lua5.1 tools/check_api.lua wowui | tee build/api.log

echo "== the window, clicked through"
lua5.1 tests/ui.lua | tee build/ui.log
ICONS=1 node tools/render.mjs build/shots

echo "== the zip"
rm -rf out/pkg && mkdir -p out/pkg
cp -r TBCrushCalc TBCrushCalc_Data out/pkg/
cp LICENSE out/pkg/TBCrushCalc/ 2>/dev/null || true
(cd out/pkg && zip -qr ../TBCrushCalc.zip TBCrushCalc TBCrushCalc_Data)
ls -la out
