;;
;; This is an implementation of wcwidth() and wcswidth() (defined in
;; IEEE Std 1002.1-2001) for Unicode.
;;
;; http://www.opengroup.org/onlinepubs/007904975/functions/wcwidth.html
;; http://www.opengroup.org/onlinepubs/007904975/functions/wcswidth.html
;;
;; In fixed-width output devices, Latin characters all occupy a single
;; "cell" position of equal width, whereas ideographic CJK characters
;; occupy two such cells. Interoperability between terminal-line
;; applications and (teletype-style) character terminals using the
;; UTF-8 encoding requires agreement on which character should advance
;; the cursor by how many cell positions. No established formal
;; standards exist at present on which Unicode character shall occupy
;; how many cell positions on character terminals. These routines are
;; a first attempt of defining such behavior based on simple rules
;; applied to data provided by the Unicode Consortium.
;;
;; For some graphical characters, the Unicode standard explicitly
;; defines a character-cell width via the definition of the East Asian
;; FullWidth (F), Wide (W), Half-width (H), and Narrow (Na) classes.
;; In all these cases, there is no ambiguity about which width a
;; terminal shall use. For characters in the East Asian Ambiguous (A)
;; class, the width choice depends purely on a preference of backward
;; compatibility with either historic CJK or Western practice.
;; Choosing single-width for these characters is easy to justify as
;; the appropriate long-term solution, as the CJK practice of
;; displaying these characters as double-width comes from historic
;; implementation simplicity (8-bit encoded characters were displayed
;; single-width and 16-bit ones double-width, even for Greek,
;; Cyrillic, etc.) and not any typographic considerations.
;;
;; Much less clear is the choice of width for the Not East Asian
;; (Neutral) class. Existing practice does not dictate a width for any
;; of these characters. It would nevertheless make sense
;; typographically to allocate two character cells to characters such
;; as for instance EM SPACE or VOLUME INTEGRAL, which cannot be
;; represented adequately with a single-width glyph. The following
;; routines at present merely assign a single-cell width to all
;; neutral characters, in the interest of simplicity. This is not
;; entirely satisfactory and should be reconsidered before
;; establishing a formal standard in this area. At the moment, the
;; decision which Not East Asian (Neutral) characters should be
;; represented by double-width glyphs cannot yet be answered by
;; applying a simple rule from the Unicode database content. Setting
;; up a proper standard for the behavior of UTF-8 character terminals
;; will require a careful analysis not only of each Unicode character,
;; but also of each presentation form, something the author of these
;; routines has avoided to do so far.
;;
;; http://www.unicode.org/unicode/reports/tr11/
;;
;; Markus Kuhn -- 2007-05-26 (Unicode 5.0)
;;
;; Permission to use, copy, modify, and distribute this software
;; for any purpose and without fee is hereby granted. The author
;; disclaims all warranties with regard to this software.
;;
;; Latest version: http://www.cl.cam.ac.uk/~mgk25/ucs/wcwidth.c
;;

(define (_bisearch ucs table)
  "Auxiliary function for binary search in interval table"
  (let ((xmid 0)
        (xmax (- (length table) 1)))
    (cond
      ((or (< ucs (car (list-ref table 0)))
           (> ucs (cdr (list-ref table xmax))))
       #f)
      (else
       (let loop ((xmin 0) (xmax xmax))
         (set! xmid (floor (/ (+ xmin xmax) 2)))
         (cond
           ((< xmax xmin)
            #f)
           ((> ucs (cdr (list-ref table xmid)))
            (loop (+ xmid 1) xmax))
           ((< ucs (car (list-ref table xmid)))
            (loop xmin (- xmid 1)))
           (else
            #t)))))))

;; The following two functions define the column width of an ISO 10646
;; character as follows:
;;
;;    - The null character (U+0000) has a column width of 0.
;;
;;    - Other C0/C1 control characters and DEL will lead to a return
;;      value of -1.
;;
;;    - Non-spacing and enclosing combining characters (general
;;      category code Mn or Me in the Unicode database) have a
;;      column width of 0.
;;
;;    - SOFT HYPHEN (U+00AD) has a column width of 1.
;;
;;    - Other format characters (general category code Cf in the Unicode
;;      database) and ZERO WIDTH SPACE (U+200B) have a column width of 0.
;;
;;    - Hangul Jamo medial vowels and final consonants (U+1160-U+11FF)
;;      have a column width of 0.
;;
;;    - Spacing characters in the East Asian Wide (W) or East Asian
;;      Full-width (F) category as defined in Unicode Technical
;;      Report #11 have a column width of 2.
;;
;;    - All remaining characters (including all printable
;;      ISO 8859-1 and WGL4 characters, Unicode control characters,
;;      etc.) have a column width of 1.
;;

(define (_mk-wcwidth ucs)
  (let ((combining
         ;; sorted list of non-overlapping intervals of non-spacing characters
         '(( #x0300 . #x036F ) ( #x0483 . #x0486 ) ( #x0488 . #x0489 )
           ( #x0591 . #x05BD ) ( #x05BF . #x05BF ) ( #x05C1 . #x05C2 )
           ( #x05C4 . #x05C5 ) ( #x05C7 . #x05C7 ) ( #x0600 . #x0603 )
           ( #x0610 . #x0615 ) ( #x064B . #x065E ) ( #x0670 . #x0670 )
           ( #x06D6 . #x06E4 ) ( #x06E7 . #x06E8 ) ( #x06EA . #x06ED )
           ( #x070F . #x070F ) ( #x0711 . #x0711 ) ( #x0730 . #x074A )
           ( #x07A6 . #x07B0 ) ( #x07EB . #x07F3 ) ( #x0901 . #x0902 )
           ( #x093C . #x093C ) ( #x0941 . #x0948 ) ( #x094D . #x094D )
           ( #x0951 . #x0954 ) ( #x0962 . #x0963 ) ( #x0981 . #x0981 )
           ( #x09BC . #x09BC ) ( #x09C1 . #x09C4 ) ( #x09CD . #x09CD )
           ( #x09E2 . #x09E3 ) ( #x0A01 . #x0A02 ) ( #x0A3C . #x0A3C )
           ( #x0A41 . #x0A42 ) ( #x0A47 . #x0A48 ) ( #x0A4B . #x0A4D )
           ( #x0A70 . #x0A71 ) ( #x0A81 . #x0A82 ) ( #x0ABC . #x0ABC )
           ( #x0AC1 . #x0AC5 ) ( #x0AC7 . #x0AC8 ) ( #x0ACD . #x0ACD )
           ( #x0AE2 . #x0AE3 ) ( #x0B01 . #x0B01 ) ( #x0B3C . #x0B3C )
           ( #x0B3F . #x0B3F ) ( #x0B41 . #x0B43 ) ( #x0B4D . #x0B4D )
           ( #x0B56 . #x0B56 ) ( #x0B82 . #x0B82 ) ( #x0BC0 . #x0BC0 )
           ( #x0BCD . #x0BCD ) ( #x0C3E . #x0C40 ) ( #x0C46 . #x0C48 )
           ( #x0C4A . #x0C4D ) ( #x0C55 . #x0C56 ) ( #x0CBC . #x0CBC )
           ( #x0CBF . #x0CBF ) ( #x0CC6 . #x0CC6 ) ( #x0CCC . #x0CCD )
           ( #x0CE2 . #x0CE3 ) ( #x0D41 . #x0D43 ) ( #x0D4D . #x0D4D )
           ( #x0DCA . #x0DCA ) ( #x0DD2 . #x0DD4 ) ( #x0DD6 . #x0DD6 )
           ( #x0E31 . #x0E31 ) ( #x0E34 . #x0E3A ) ( #x0E47 . #x0E4E )
           ( #x0EB1 . #x0EB1 ) ( #x0EB4 . #x0EB9 ) ( #x0EBB . #x0EBC )
           ( #x0EC8 . #x0ECD ) ( #x0F18 . #x0F19 ) ( #x0F35 . #x0F35 )
           ( #x0F37 . #x0F37 ) ( #x0F39 . #x0F39 ) ( #x0F71 . #x0F7E )
           ( #x0F80 . #x0F84 ) ( #x0F86 . #x0F87 ) ( #x0F90 . #x0F97 )
           ( #x0F99 . #x0FBC ) ( #x0FC6 . #x0FC6 ) ( #x102D . #x1030 )
           ( #x1032 . #x1032 ) ( #x1036 . #x1037 ) ( #x1039 . #x1039 )
           ( #x1058 . #x1059 ) ( #x1160 . #x11FF ) ( #x135F . #x135F )
           ( #x1712 . #x1714 ) ( #x1732 . #x1734 ) ( #x1752 . #x1753 )
           ( #x1772 . #x1773 ) ( #x17B4 . #x17B5 ) ( #x17B7 . #x17BD )
           ( #x17C6 . #x17C6 ) ( #x17C9 . #x17D3 ) ( #x17DD . #x17DD )
           ( #x180B . #x180D ) ( #x18A9 . #x18A9 ) ( #x1920 . #x1922 )
           ( #x1927 . #x1928 ) ( #x1932 . #x1932 ) ( #x1939 . #x193B )
           ( #x1A17 . #x1A18 ) ( #x1B00 . #x1B03 ) ( #x1B34 . #x1B34 )
           ( #x1B36 . #x1B3A ) ( #x1B3C . #x1B3C ) ( #x1B42 . #x1B42 )
           ( #x1B6B . #x1B73 ) ( #x1DC0 . #x1DCA ) ( #x1DFE . #x1DFF )
           ( #x200B . #x200F ) ( #x202A . #x202E ) ( #x2060 . #x2063 )
           ( #x206A . #x206F ) ( #x20D0 . #x20EF ) ( #x302A . #x302F )
           ( #x3099 . #x309A ) ( #xA806 . #xA806 ) ( #xA80B . #xA80B )
           ( #xA825 . #xA826 ) ( #xFB1E . #xFB1E ) ( #xFE00 . #xFE0F )
           ( #xFE20 . #xFE23 ) ( #xFEFF . #xFEFF ) ( #xFFF9 . #xFFFB )
           ( #x10A01 . #x10A03 ) ( #x10A05 . #x10A06 ) ( #x10A0C . #x10A0F )
           ( #x10A38 . #x10A3A ) ( #x10A3F . #x10A3F ) ( #x1D167 . #x1D169 )
           ( #x1D173 . #x1D182 ) ( #x1D185 . #x1D18B ) ( #x1D1AA . #x1D1AD )
           ( #x1D242 . #x1D244 ) ( #xE0001 . #xE0001 ) ( #xE0020 . #xE007F )
           ( #xE0100 . #xE01EF ))))

    (cond
     ;; test for 8-bit control characters
     ((= ucs 0)
      0)
     ((or (< ucs 32) (and (>= ucs #x7f) (< ucs #xa0)))
      -1)

     ;; binary search in table of non-spacing characters
     ((_bisearch ucs combining)
      0)

     ;; If we arrive here, ucs is not a combining or C0/C1 control character.
     ((and (>= ucs #x1100)
           (or (<= ucs #x115f)
               (= ucs #x2329)
               (= ucs #x232a)
               ;; CJK
               (and (>= ucs #x2e80)
                    (<= ucs #xa4cf)
                    (not (= ucs #x303f)))
               ;; Hangul Syllables
               (and (>= ucs #xac00) (<= ucs #xd7a3))
               ;; CJK Compatibility Ideographs
               (and (>= ucs #xf900) (<= ucs #xfaff))
               ;; Vertical forms
               (and (>= ucs #xfe10) (<= ucs #xfe19))
               ;; CJK Compatibility Forms
               (and (>= ucs #xfe30) (<= ucs #xfe6f))
               ;; Fullwidth forms
               (and (>= ucs #xff00) (<= ucs #xff60))
               (and (>= ucs #xffe0) (<= ucs #xffe6))
               (and (>= ucs #x20000) (<= ucs #x2fffd))
               (and (>= ucs #x30000) (<= ucs #x3fffd))))
      2)
     (else 1))))

;;
;; The following functions are the same as mk_wcwidth() and
;; mk_wcswidth(), except that spacing characters in the East Asian
;; Ambiguous (A) category as defined in Unicode Technical Report #11
;; have a column width of 2. This variant might be useful for users of
;; CJK legacy encodings who want to migrate to UCS without changing
;; the traditional terminal character-width behaviour. It is not
;; otherwise recommended for general use.

(define (_mk-wcwidth-cjk ucs)
  (let ((ambiguous
         ;; sorted list of non-overlapping intervals of East Asian Ambiguous
         ;; characters
         '(( #x00A1 . #x00A1 ) ( #x00A4 . #x00A4 ) ( #x00A7 . #x00A8 )
           ( #x00AA . #x00AA ) ( #x00AE . #x00AE ) ( #x00B0 . #x00B4 )
           ( #x00B6 . #x00BA ) ( #x00BC . #x00BF ) ( #x00C6 . #x00C6 )
           ( #x00D0 . #x00D0 ) ( #x00D7 . #x00D8 ) ( #x00DE . #x00E1 )
           ( #x00E6 . #x00E6 ) ( #x00E8 . #x00EA ) ( #x00EC . #x00ED )
           ( #x00F0 . #x00F0 ) ( #x00F2 . #x00F3 ) ( #x00F7 . #x00FA )
           ( #x00FC . #x00FC ) ( #x00FE . #x00FE ) ( #x0101 . #x0101 )
           ( #x0111 . #x0111 ) ( #x0113 . #x0113 ) ( #x011B . #x011B )
           ( #x0126 . #x0127 ) ( #x012B . #x012B ) ( #x0131 . #x0133 )
           ( #x0138 . #x0138 ) ( #x013F . #x0142 ) ( #x0144 . #x0144 )
           ( #x0148 . #x014B ) ( #x014D . #x014D ) ( #x0152 . #x0153 )
           ( #x0166 . #x0167 ) ( #x016B . #x016B ) ( #x01CE . #x01CE )
           ( #x01D0 . #x01D0 ) ( #x01D2 . #x01D2 ) ( #x01D4 . #x01D4 )
           ( #x01D6 . #x01D6 ) ( #x01D8 . #x01D8 ) ( #x01DA . #x01DA )
           ( #x01DC . #x01DC ) ( #x0251 . #x0251 ) ( #x0261 . #x0261 )
           ( #x02C4 . #x02C4 ) ( #x02C7 . #x02C7 ) ( #x02C9 . #x02CB )
           ( #x02CD . #x02CD ) ( #x02D0 . #x02D0 ) ( #x02D8 . #x02DB )
           ( #x02DD . #x02DD ) ( #x02DF . #x02DF ) ( #x0391 . #x03A1 )
           ( #x03A3 . #x03A9 ) ( #x03B1 . #x03C1 ) ( #x03C3 . #x03C9 )
           ( #x0401 . #x0401 ) ( #x0410 . #x044F ) ( #x0451 . #x0451 )
           ( #x2010 . #x2010 ) ( #x2013 . #x2016 ) ( #x2018 . #x2019 )
           ( #x201C . #x201D ) ( #x2020 . #x2022 ) ( #x2024 . #x2027 )
           ( #x2030 . #x2030 ) ( #x2032 . #x2033 ) ( #x2035 . #x2035 )
           ( #x203B . #x203B ) ( #x203E . #x203E ) ( #x2074 . #x2074 )
           ( #x207F . #x207F ) ( #x2081 . #x2084 ) ( #x20AC . #x20AC )
           ( #x2103 . #x2103 ) ( #x2105 . #x2105 ) ( #x2109 . #x2109 )
           ( #x2113 . #x2113 ) ( #x2116 . #x2116 ) ( #x2121 . #x2122 )
           ( #x2126 . #x2126 ) ( #x212B . #x212B ) ( #x2153 . #x2154 )
           ( #x215B . #x215E ) ( #x2160 . #x216B ) ( #x2170 . #x2179 )
           ( #x2190 . #x2199 ) ( #x21B8 . #x21B9 ) ( #x21D2 . #x21D2 )
           ( #x21D4 . #x21D4 ) ( #x21E7 . #x21E7 ) ( #x2200 . #x2200 )
           ( #x2202 . #x2203 ) ( #x2207 . #x2208 ) ( #x220B . #x220B )
           ( #x220F . #x220F ) ( #x2211 . #x2211 ) ( #x2215 . #x2215 )
           ( #x221A . #x221A ) ( #x221D . #x2220 ) ( #x2223 . #x2223 )
           ( #x2225 . #x2225 ) ( #x2227 . #x222C ) ( #x222E . #x222E )
           ( #x2234 . #x2237 ) ( #x223C . #x223D ) ( #x2248 . #x2248 )
           ( #x224C . #x224C ) ( #x2252 . #x2252 ) ( #x2260 . #x2261 )
           ( #x2264 . #x2267 ) ( #x226A . #x226B ) ( #x226E . #x226F )
           ( #x2282 . #x2283 ) ( #x2286 . #x2287 ) ( #x2295 . #x2295 )
           ( #x2299 . #x2299 ) ( #x22A5 . #x22A5 ) ( #x22BF . #x22BF )
           ( #x2312 . #x2312 ) ( #x2460 . #x24E9 ) ( #x24EB . #x254B )
           ( #x2550 . #x2573 ) ( #x2580 . #x258F ) ( #x2592 . #x2595 )
           ( #x25A0 . #x25A1 ) ( #x25A3 . #x25A9 ) ( #x25B2 . #x25B3 )
           ( #x25B6 . #x25B7 ) ( #x25BC . #x25BD ) ( #x25C0 . #x25C1 )
           ( #x25C6 . #x25C8 ) ( #x25CB . #x25CB ) ( #x25CE . #x25D1 )
           ( #x25E2 . #x25E5 ) ( #x25EF . #x25EF ) ( #x2605 . #x2606 )
           ( #x2609 . #x2609 ) ( #x260E . #x260F ) ( #x2614 . #x2615 )
           ( #x261C . #x261C ) ( #x261E . #x261E ) ( #x2640 . #x2640 )
           ( #x2642 . #x2642 ) ( #x2660 . #x2661 ) ( #x2663 . #x2665 )
           ( #x2667 . #x266A ) ( #x266C . #x266D ) ( #x266F . #x266F )
           ( #x273D . #x273D ) ( #x2776 . #x277F ) ( #xE000 . #xF8FF )
           ( #xFFFD . #xFFFD ) ( #xF0000 . #xFFFFD ) ( #x100000 . #x10FFFD))))

    ;; binary search in table of non-spacing characters
    (cond
     ((_bisearch ucs ambiguous)
      2)
     (else
      (wcwidth ucs)))))

(define* (wcwidth x #:key (cjk #f))
  "Compute the screen width of a character or string"
  (cond
   ((string? x)
    (apply + (map (lambda (c)
                    (if cjk (_mk-wcwidth-cjk (char->integer c))
                        (_mk-wcwidth (char->integer c))))
                  (string->list x))))
   ((char? x)
    (if cjk
        (_mk-wcwidth-cjk (char->integer x))
        (_mk-wcwidth (char->integer x))))
   ((integer? x)
    (if cjk
        (_mk-wcwidth-cjk x)
        (_mk-wcwidth x)))
   (else
    -1)))