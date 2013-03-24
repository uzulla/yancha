#!/bin/sh

install_dbd() {
  echo -n '[1] '
  read which_db

  if [ -z "$which_db" ] || [ $which_db = '1' ] ; then
    cpanm --notest DBD::mysql
    status=$?
    if [ $status -ne 0 ] ; then
      echo '[HINT] インストールに失敗しましたか？ だとしたら、多分mysql-dev 的なライブラリが入ってないので、まずそれを入れて下さい！'
    fi
    return $status
  elif [ $which_db = '2' ] ; then
    cpanm --notest DBD::SQLite
    return $?
  fi

  echo '"MySQL (1)" か "SQLite (2)" のどちらかを指定して下さい.'
  read_db_type
}

cat << message

どのDB を使用しますか? (数字で指定してください).
1: MySQL
2: SQLite
message

install_dbd
return $?
