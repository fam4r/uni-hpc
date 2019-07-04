#! /bin/sh
name=$1
sed -i 's/set output "\(.*\)".*/set output "'$1'"/g' plot.gp
gnuplot plot.gp
