
set -u -e

name=show-ga

cd $name
pwd

mkdir -p cropped
mkdir -p resized
mkdir -p geom
mkdir -p tmp

crop='800x380'
cropOffset='+5+3'
shave='65x50'
resize='1024x512'

convert -size $resize xc:white tmp/canvas.png

c1screenshot() {
  gnome-screenshot -d 4 -f show-ga/orig/$1.png
}

c2geom() {
  convert tmp/canvas.png orig/$1.png -geometry $2 -flatten geom/$1.png 
}

  rm -f geom/*
  cp orig/[1-3].png geom/.
  c2geom 4 '+100+0'

  for n in 1 2 3
  do 
    orig=orig/$n.png
    geom=geom/$n.png
    cropped=cropped/$n.png
    convert +repage -shave $shave -crop $crop$cropOffset $geom $cropped
    identify -format "\n%wx%h %f" $cropped
  done
  cp geom/4.png cropped/.
  for n in 1 2 3 4
  do 
    cropped=cropped/$n.png
    resized=resized/$n.png
    convert +repage -resize $resize $cropped $resized
    identify -format "\n%wx%h %f" $resized
  done

  identify -format "\n%wx%h %f" resized/[1-4].png
  convert +repage -delay 500 -loop 0 resized/[2-4].png $name-animated.gif
  identify -format "\n%wx%h %f" $name-animated.gif

  ls -l $name-animated.gif
  cp $name-animated.gif ~/Downloads
  google-chrome $name-animated.gif

