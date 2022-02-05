#!/usr/bin/env bash

COLOR_OFF="\e[0m";
DIM="\e[2m";

function compile {
  gleam check
}

function run {
  clear;
  tput reset;
  echo -en "\033c\033[3J";

  echo -en "${DIM}";
  date -R;
  echo -en "${COLOR_OFF}";

  compile;
}

run;

find . -type f -name '*.gleam' | xargs chokidar | while read WHATEVER; do
  run;
done;
