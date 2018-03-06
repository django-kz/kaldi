#!/bin/bash

# Copyright 2015    Hossein Hadian
# Apache 2.0

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

# this is only called for decoding purposes. This is not necessary for training.
lmsrc="grammar::lexicon"  # Can be either a text file in the format of train/text or arpa file
lang=data/lang_test # output dir for e.g. data/test/lang
test=$lang
ngram=$3
[ -z $ngram ] && ngram=2
tmpdir=$lang/temp


mkdir -p $tmpdir

if [[ $lmsrc == "grammar::lexicon"  ]]; then
  echo "$0: Creating a GRAMMAR LM --------------------"
  echo "$0:test loc"$test
  #sed "s| [[:digit:]]\+||g" $test/words.txt | grep -v "[<&(#s]"  >$tmpdir/just_words.txt
  #python local/lex2G.py $tmpdir/just_words.txt >$tmpdir/pG.txt
  cat data/train/text | cut -d' ' -f3 > $tmpdir/all_words.txt
  cat data/test/text | cut -d' ' -f3 >> $tmpdir/all_words.txt
  cat $tmpdir/all_words.txt | python local/make_isolated_word_grammar.py >$tmpdir/pG.txt
  fstcompile --isymbols=$test/words.txt --osymbols=$test/words.txt $tmpdir/pG.txt >$test/G.fst

elif [[ $lmsrc == *".arpa" ]]; then
  echo "-------------------- ARPA LM -----------------------"
  echo "$0: Using arpa LM: "$lmsrc
  arpa=$lmsrc
else
  echo "$0: No Arpa file provided..Creating a $ngram-gram LM from provided text: "$lmsrc;
  if [ -z $IRSTLM ]; then
    export IRSTLM=$PWD/../../../tools/irstlm
    export PATH=$PWD/../../../tools/irstlm/bin:$PATH
    echo "$0: Assuming irstlm is at: "$IRSTLM
  fi
#  [ -z "$IRSTLM" ] && \
#    echo "LM building won't work without setting the IRSTLM env variable" && exit 1;
  ! which build-lm.sh 2>/dev/null  && \
    echo "$0: IRSTLM does not seem to be installed (build-lm.sh not on your path): " && \
    echo "go to <kaldi-root>/tools and try 'make irstlm_tgt'" && exit 1;

  cut -d' ' -f2- $lmsrc | sed -e 's:^:<s> :' -e 's:$: </s>:' \
    > $tmpdir/tmp_lm_train
  build-lm.sh -k 1 -i $tmpdir/tmp_lm_train -n $ngram -o $tmpdir/tmp_lm_bg.ilm.gz

  compile-lm $tmpdir/tmp_lm_bg.ilm.gz -t=yes /dev/stdout | \
  grep -v unk > $tmpdir/lm_phone_bg.arpa

  arpa=$tmpdir/lm_phone_bg.arpa
fi

# cat $arpa | utils/find_arpa_oovs.pl $lang/words.txt  > $tmpdir/oovs.txt

# cat $arpa | \
#     grep -v '<s> <s>' | \
#     grep -v '</s> <s>' | \
#     grep -v '</s> </s>' | \
#     arpa2fst - | fstprint | \
#     utils/remove_oovs.pl $tmpdir/oovs.txt | \
#     utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=$lang/words.txt \
#       --osymbols=$lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
#      fstrmepsilon | fstarcsort --sort_type=ilabel >$lang/G.fst || exit 1;

echo "$0: Done preparing the LM"
