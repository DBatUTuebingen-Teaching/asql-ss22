#! /bin/bash
# SQL-based animation of Conway's Game of Life
#
# Usage: ./conway.sh ‹number of generations to display›

clear
for N in `jot $1 1 $1`
do
  echo -ne '\033[0;0H'
  echo Generation \#$N
  psql -Xq -d scratch --set=N=$N -f game-of-life.sql
  sleep 0.2
done
