#!/bin/bash

run_sanity_test() {
  now_path=$(pwd)
  echo $now_path

  cd ~
  goman_path=$(find . -path \*go/src/github.com/tbcasoft/goman/api)
  sanity_config_file=$(find . -path \*go/src/github.com/tbcasoft/goman/config/SANITY.cfg)
  echo $sanity_config_file
  cd $goman_path
  echo "go to $(pwd)"

  go clean -testcache
  export CONFIG_FILE=~/go/go/src/github.com/tbcasoft/goman/config/SANITY.cfg
  go test -v ./envvar_test.go ./sanity_test.go
  echo "Finished Sanity test"
  cd $now_path
}

echo "Running Sanity test"
run_sanity_test