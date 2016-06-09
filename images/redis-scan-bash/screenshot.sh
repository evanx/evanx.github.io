

cd

c1screenshot() {
  name=$1
  image=Pictures/$name.png  
  echo "name $name, image $image"
  sleep 2 
  gnome-screenshot -a -f $image
  sleep 1
  ls -l ~/$image
  eog $image  & 
}

name=screenshot
if [ $# -eq 1 ]
then
  name=$1
fi 

c1screenshot $name



