;; coding: utf-8

;;; Text strings used for unit testing

(define string-data-ascii               "abcdefghijklmnopqrstuvwxyz")
(define string-presentation-ascii       "abcdefghijklmnopqrstuvwxyz")
(define position-presentation-ascii     (iota 27))

(define string-data-hanzi               "章掌杖仗丈障彰璋樟張嶂瘴遧弡鱆慞")
(define string-presentation-hanzi       "章掌杖仗丈障彰璋樟張嶂瘴遧弡鱆慞")
(define position-presentation-hanzi
  '(0 2 4 8 10 12 14 16 18 20 22 24 26 28 30 32))

(define string-data-hanzi-odd           ":章掌杖仗丈障彰璋樟張嶂瘴遧弡鱆:")
(define string-presentation-hanzi-odd   ":章掌杖仗丈障彰璋樟張嶂瘴遧弡鱆:")
(define position-presentation-hanzi-odd
  '(0 1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31 32))

(define string-data-tabs                "\ta\tb\tc\td\te")
(define string-presentation-tabs
  "        a       b       c       d       e")
(define position-position-tabs      '(0 8 9 16 17 24 25 32 33 40 41))

;; The Raven, by Edgar Allan Poe
(define text-ascii-short
  '("\tOnce upon"
    "a midnight dreary"
    "as I pondered"
    "weak and weary"
    ""))

;; Psalm 16 KJV
(define text-ascii-long
  '("\tPreserve me, O God: for in thee do I put my trust."
    "\tO my soul, thou has said unto the LORD, Thou art my Lord: my goodness"
    "extendeth not to thee;"
    "\tBut to the saints that are in the earth, and to the excellent, in whom"
    "is all my delight."
    "\tTheir sorrows shall be multiplied that hasten after another god: their"
    "drink offerings of blood will I not offer, nor take up their names"
    "into my lips."
    "\tThe LORD is the portion of mine inheritance and of my cup: thou"
    "maintainest my lot."
    "\tThe lines are fallen unto me in pleasant places; yea, I have a goodly"
    "heritage."
    "\tI will bless the LORD, who hath given me counsel: my reins also"
    "instruct me in the night seasons."
    "\tI have set the LORD always before me: because he is at my right hand,"
    "I shall not be moved."
    "\tTherefore my heart is glad, and my glory rejoiceth: my flesh also"
    "shall rest in hope."
    "\tFor thou wilt not leave my soul in hell; neither wilt thou suffer"
    "thine Holy One to see corruption."
    "\tThou wilt shew me the path of life: in thy presence is fulness of joy;"
    "at thy right hand there are pleasures for evermore."))
 bc  asda g
abc	def

;; from RASHOMON by AKUTAGAWA Ryunosuke
;; Gutenberg etext #1982
(define text-kanji-short
  '("　老婆は、一目下人を見ると、まるで弩（いしゆみ）にでも弾かれたように　飛び上がっ"
    "た。"
    "　「おのれ、どこへ行く。」"))


;; from RASHOMON by AKUTAGAWA Ryunosuke
;; Gutenberg etext #1982
(define text-kanji-long
  '("　下人は、老婆をつき放すと、いきなり、太刀の鞘を払って、白い鋼（はがね）の色を"
    "その眼の前へつきつけた。けれども、老婆は黙っている。両手をわなわなふるわせて、"
    "肩で息を切りながら、眼を、眼球がまぶたの外へ出そうになる程、見開いて、唖のよう"
    "に執拗（しゅうね）く黙っている。これを見ると、下人は始めて明白にこの老婆の生死"
    "が、全然、自分の意志に支配されていると云う事を意識した。そうして、この意識は、"
    "今まではげしく燃えていた憎悪の心を何時（いつ）の間にか冷ましてしまった。後に残っ"
    "たのは、唯、或仕事をして、それが円満に成就した時の、安らかな得意と満足とがある"
    "ばかりである。そこで、下人は、老婆を、見下げながら、少し声を柔げてこう云った。"
    "　「己は検非違使（けびいし）の庁の役人などではない。今し方この門の下を通りかかっ"
    "た旅の者だ。だからお前に縄をかけて、どうしようと云うような事はない。唯今時分、"
    "この門の上で、何をしていたのだか、それを己に話さえすればいいのだ。」"))

(define text-mixed-short
  '("Title: 刺靑 (Shisei)"
    "Author: 谷崎潤一郞 (Junichiro Tanizaki)"
    "Language: Japanese"))

(define text-mixed-long
  '("《...》 shows ruby (short runs of text alongside the base text to indicate"
    "pronunciation)."
    "Eg. 其《そ》"
    "｜ marks the start of a string of ruby-attached characters."
    "Eg. 十三｜年目《ねんめ》"
    "［＃...］ explains the formatting of the original text."
    "Eg. ［＃ここから３字下げ］"))
