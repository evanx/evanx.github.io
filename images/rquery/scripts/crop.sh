
set -u -e

name=$1

crop='600x300+0+0'

  cd $name
  for n in 1 2 3 4 
  do 
    cropped=cropped/$n.png
    convert -crop $crop orig/$n.png $cropped
    identify -format "\n%wx%h %f" $cropped
  done
  cd ..
  convert -delay 200 -loop 0 $name/cropped/[1-4].png $name-animated.gif
  ls -l $name-animated.gif
  xdg-open $name-animated.gif

