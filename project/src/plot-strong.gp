set terminal png size 900,600 enhanced notransparent
set output "omp-strong.png"
set lmargin 8
set grid
set logscale x 2
set key on title "Lato dominio"
set title "Strong Scaling Efficiency OpenMP" font ",18"
set xlabel "Thread(s)" font ", 14"
set ylabel "Efficienza" font ", 14"
plot \
    for [COL=2:4] 'omp-strong.dat' using 1:COL title columnheader linewidth 2 with lines
