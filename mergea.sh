
make_mri() {
  echo create $1
  shift 1
  for a in $@; do
    test -f $a && echo "addlib $a"
  done
  echo save
  echo end
}

echo mergea $@...
MRI=${1}.mri
make_mri $@ > $MRI
cat $MRI
llvm-ar -M < $MRI