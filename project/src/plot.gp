## Ultimo aggiornamento 2018-12-17
## Autore: Moreno Marzolla <moreno.marzolla(at)unibo.it>

## Questo e' uno script di gnuplot (http://www.gnuplot.info/) che puo'
## essere usato per produrre una figura simile alla figura 1 nella
## specifica del progetto. Questo script legge un file "out" che deve
## contenere l'output della propria implementazione del modello BK, e
## produce un file "earthquake.png" contenente l'immagine composta da
## due grafici sovrapposti.

## L'uso di gnuplot NON E' RICHIESTO; e' possibile produrre immagini
## usando qualunque altro strumento a vostra disposizione.

set terminal png enhanced notransparent
set output "earthquake.png"
set multiplot layout 2,1
set lmargin 8
set title "Energia media" font ",12"
plot [][0:] "out" using 2 with l notitle lw 2
set xlabel "Timestep"
set title "N. celle con energia > EMAX" font ",12"
plot [][0:] "out" using 1 with p notitle pt 7 ps 0.5
unset multiplot
